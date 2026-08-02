// MushroomScanner identify function (Supabase Edge Function, Deno runtime).
//
// v1 shortcut, not a certified mycology tool: instead of a trained
// computer-vision model, this calls the Claude API with a structured
// vision prompt and asks it to pick the closest match from our own
// species catalog (or admit it doesn't know). See MushroomScanner/README.md
// for the safety requirements this output feeds into (confidence
// threshold, forced "uncertain" state, etc.) - none of that logic lives
// here, it's enforced client-side in src/utils/confidence.ts.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { speciesCatalog } from '../_shared/species.ts';

const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY');
const MODEL = Deno.env.get('CLAUDE_MODEL') ?? 'claude-sonnet-5';
const ANTHROPIC_VERSION = '2023-06-01';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

type ScanAngle = 'cap' | 'gills' | 'stem_base';

interface IdentifyPhoto {
  angle: ScanAngle;
  mediaType: string;
  base64: string;
}

interface IdentifyRequestBody {
  photos: IdentifyPhoto[];
}

interface IdentifyResult {
  /** Ordered first in the response so the model observes before concluding. */
  notableFeatures: string[];
  reasoning: string;
  speciesId: string | null;
  confidencePercent: number;
}

interface CatalogEntry {
  id: string;
  commonName: string;
  latinName: string;
  edibilityStatus: string;
  habitat: string;
  season: string;
  confidenceNotes?: string;
  lookalikeSpeciesIds: readonly string[];
}

// The catalog sent to the model includes the diagnostic notes from our
// own seed data. Sending bare names (as v1 did) asks the model to
// identify from an index with the field guide torn out - the features
// that separate a Death Cap from a Field Mushroom are exactly what we
// were withholding.
const catalog = speciesCatalog as readonly CatalogEntry[];

const catalogText = catalog
  .map((s) => {
    const lines = [
      `### ${s.id}`,
      `Name: ${s.commonName} (${s.latinName})`,
      `Edibility: ${s.edibilityStatus}`,
      `Habitat: ${s.habitat}`,
      `Season: ${s.season}`,
    ];
    if (s.confidenceNotes) lines.push(`Distinguishing features: ${s.confidenceNotes}`);
    if (s.lookalikeSpeciesIds.length) {
      lines.push(`Commonly confused with: ${s.lookalikeSpeciesIds.join(', ')}`);
    }
    return lines.join('\n');
  })
  .join('\n\n');

const systemPrompt = `You are assisting a mushroom foraging app called MushroomScanner. You are not a certified mycologist and your output is a decision-support suggestion only, never a certain identification - the app enforces its own safety rules on top of what you return.

You are given one or more photos of a single wild mushroom specimen: a cap photo, and optionally the gills/underside and the stem base. Identify the most likely species from the fixed catalog below, ONLY. Never propose a species outside this list.

# How to work

Work in this order, and put your answer in the JSON fields in this same order:

1. FIRST, list what you can actually see in the photos - cap shape and colour, gill attachment and colour, stem features, and critically whether the stem base shows a volva (a sack-like cup, often partly buried), a ring, or bulb. If an angle wasn't provided, say what you cannot assess rather than assuming.
2. THEN reason from those observations toward a species, explicitly using the distinguishing features listed in the catalog. Say what your observations rule OUT as well as what they support.
3. ONLY THEN name the species and give a confidence.

Do not decide on a species first and justify it afterwards. The observations must drive the conclusion.

# Safety rules that override everything else

- A volva at the stem base is the single most important feature in this catalog. It is shared by the deadly Amanita species and absent from the edible Agaricus species they are confused with. If you see one, say so prominently. If the stem base was not photographed, you CANNOT rule out a deadly Amanita - reflect that by keeping confidence low.
- If the specimen could plausibly be a deadly species, prefer naming the deadly species over the edible look-alike. Being wrong about a Death Cap in the cautious direction costs the user a meal; being wrong in the other direction can kill them.
- If nothing in the catalog clearly matches, or the photos are too unclear or incomplete, return "speciesId": null. Do not force a guess to be helpful.
- Confidence must be honest and calibrated, not encouraging. Be conservative with fewer angles: a cap-only photo of a gilled mushroom should rarely exceed 70, because the diagnostic features are on the parts you cannot see.

# Catalog

${catalogText}

# Response format

Respond with ONLY a single JSON object, no markdown fences and no other text, with the keys in exactly this order:
{
  "notableFeatures": string[],
  "reasoning": string,
  "speciesId": string | null,
  "confidencePercent": number
}

notableFeatures: concrete observations only, things you can actually see (e.g. "sack-like volva at stem base", "gills free from stem, chocolate brown", "stem base not visible in any photo"). Include what is missing or unassessable, not just what is present.
reasoning: 2-4 sentences working from those observations to the conclusion, naming what they rule out.
speciesId: a catalog id, or null.
confidencePercent: 0-100, honest and calibrated.`;

// Permissive CORS since this is called from Expo web builds in addition to
// native, and only ever exposes read access to the fixed species catalog.
const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, content-type, apikey, x-client-info',
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', ...corsHeaders },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  if (!ANTHROPIC_API_KEY) {
    return jsonResponse({ error: 'ANTHROPIC_API_KEY is not configured on this function' }, 500);
  }

  // Identify who's calling from their JWT - never trust a user id in the
  // request body, or anyone could spend someone else's quota.
  const authHeader = req.headers.get('Authorization') ?? '';
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const { data: userData, error: userError } = await admin.auth.getUser(authHeader.replace('Bearer ', ''));
  if (userError || !userData?.user) {
    return jsonResponse({ error: 'Not authenticated' }, 401);
  }

  let body: IdentifyRequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }

  if (!Array.isArray(body.photos) || body.photos.length === 0) {
    return jsonResponse({ error: 'At least one photo is required' }, 400);
  }
  if (body.photos.length > 5) {
    return jsonResponse({ error: 'Too many photos (max 5)' }, 400);
  }

  // Quota check happens before the (billable) model call, and consumes the
  // credit atomically so parallel requests can't slip past the free cap.
  const { data: creditRows, error: creditError } = await admin.rpc('consume_scan_credit', {
    p_user_id: userData.user.id,
  });
  if (creditError) {
    return jsonResponse({ error: 'Failed to check scan quota', detail: creditError.message }, 500);
  }
  const credit = Array.isArray(creditRows) ? creditRows[0] : creditRows;
  if (!credit?.allowed) {
    return jsonResponse(
      {
        error: 'scan_limit_reached',
        scansUsed: credit?.scans_used ?? null,
        scansLimit: credit?.scans_limit ?? null,
      },
      402
    );
  }

  const imageBlocks = body.photos.map((photo) => ({
    type: 'image',
    source: { type: 'base64', media_type: photo.mediaType, data: photo.base64 },
  }));
  const angleSummary = body.photos.map((photo) => photo.angle).join(', ');

  let anthropicResponse: Response;
  try {
    anthropicResponse = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': ANTHROPIC_API_KEY,
        'anthropic-version': ANTHROPIC_VERSION,
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 1024,
        system: systemPrompt,
        messages: [
          {
            role: 'user',
            content: [
              ...imageBlocks,
              {
                type: 'text',
                text: `Photos provided, in this order: ${angleSummary}.${
                  body.photos.some((p) => p.angle === 'stem_base')
                    ? ''
                    : ' NOTE: the stem base was NOT photographed, so a volva cannot be ruled out.'
                } Identify this mushroom.`,
              },
            ],
          },
        ],
      }),
    });
  } catch (err) {
    return jsonResponse({ error: 'Failed to reach the Claude API', detail: String(err) }, 502);
  }

  if (!anthropicResponse.ok) {
    const detail = await anthropicResponse.text();
    return jsonResponse({ error: 'Claude API request failed', detail }, 502);
  }

  const data = await anthropicResponse.json();
  const textBlock = (data.content ?? []).find((block: { type: string }) => block.type === 'text');
  if (!textBlock) {
    return jsonResponse({ error: 'Model returned no text content' }, 502);
  }

  let parsed: IdentifyResult;
  try {
    parsed = JSON.parse(textBlock.text);
  } catch {
    return jsonResponse({ error: 'Model response was not valid JSON', raw: textBlock.text }, 502);
  }

  // Never trust the model's output shape. Everything below is defensive:
  // a malformed field must degrade toward "we don't know", never toward a
  // confident-looking result the app would then act on.
  const validIds = new Set(catalog.map((s) => s.id));

  if (typeof parsed.speciesId !== 'string' && parsed.speciesId !== null) {
    parsed.speciesId = null;
  }

  if (parsed.speciesId !== null && !validIds.has(parsed.speciesId)) {
    // The model named something outside our catalog - treat as unknown
    // rather than passing through a species_id that would fail the
    // scans.species_id foreign key.
    parsed.speciesId = null;
  }

  // Coerce confidence into 0-100. A missing, NaN, or out-of-range value
  // becomes 0 (maximally uncertain) rather than being passed through,
  // where a stray 150 would sail past the app's threshold check.
  const rawConfidence = Number(parsed.confidencePercent);
  parsed.confidencePercent = Number.isFinite(rawConfidence)
    ? Math.max(0, Math.min(100, Math.round(rawConfidence)))
    : 0;

  // An unidentified specimen can never carry high confidence, whatever the
  // model reported - "I don't know, 90%" is incoherent and would show the
  // user a confident-looking badge on an empty result.
  if (parsed.speciesId === null) {
    parsed.confidencePercent = Math.min(parsed.confidencePercent, 40);
  }

  if (typeof parsed.reasoning !== 'string') parsed.reasoning = '';
  if (!Array.isArray(parsed.notableFeatures)) parsed.notableFeatures = [];
  parsed.notableFeatures = parsed.notableFeatures.filter((f): f is string => typeof f === 'string');

  return jsonResponse(parsed);
});
