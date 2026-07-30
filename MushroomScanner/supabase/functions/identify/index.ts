// MushroomScanner identify function (Supabase Edge Function, Deno runtime).
//
// v1 shortcut, not a certified mycology tool: instead of a trained
// computer-vision model, this calls the Claude API with a structured
// vision prompt and asks it to pick the closest match from our own
// species catalog (or admit it doesn't know). See MushroomScanner/README.md
// for the safety requirements this output feeds into (confidence
// threshold, forced "uncertain" state, etc.) - none of that logic lives
// here, it's enforced client-side in src/utils/confidence.ts.

import { speciesCatalog } from '../_shared/species.ts';

const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY');
const MODEL = Deno.env.get('CLAUDE_MODEL') ?? 'claude-sonnet-5';
const ANTHROPIC_VERSION = '2023-06-01';

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
  speciesId: string | null;
  confidencePercent: number;
  reasoning: string;
  notableFeatures: string[];
}

const catalogText = (speciesCatalog as Array<{ id: string; commonName: string; latinName: string }>)
  .map((s) => `${s.id}: ${s.commonName} (${s.latinName})`)
  .join('\n');

const systemPrompt = `You are assisting a mushroom foraging app called MushroomScanner. You are not a certified mycologist and your output is a decision-support suggestion only, never a certain identification - the app enforces its own safety rules on top of what you return.

Given one or more photos of a single wild mushroom specimen (a cap photo, and optionally gills/underside and stem base), identify the most likely species from this fixed catalog ONLY. Do not propose any species outside this list, and do not guess a catalog entry you are not reasonably confident about just to give an answer.

Catalog (id: common name (Latin name)):
${catalogText}

If the specimen does not clearly match any catalog entry, or the photos are too unclear/incomplete to say, return "speciesId": null rather than forcing a guess.

Respond with ONLY a single JSON object, no markdown fences, no other text, matching exactly this shape:
{
  "speciesId": string | null,
  "confidencePercent": number,
  "reasoning": string,
  "notableFeatures": string[]
}

confidencePercent must be your honest, calibrated confidence from 0-100 given only the photos provided - be conservative when fewer angles are available (e.g. cap only, no gills or stem base). reasoning should be 2-3 sentences citing the specific visual features you used. notableFeatures should be a short list of concrete observations (e.g. "gills free from stem", "no visible volva at base", "bruises blue when cut").`;

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
              { type: 'text', text: `Photos provided, in this order: ${angleSummary}. Identify this mushroom.` },
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

  const validIds = new Set((speciesCatalog as Array<{ id: string }>).map((s) => s.id));
  if (parsed.speciesId !== null && !validIds.has(parsed.speciesId)) {
    // The model hallucinated an id outside our catalog - treat as unknown
    // rather than passing through a species_id that would fail the
    // scans.species_id foreign key.
    parsed.speciesId = null;
    parsed.confidencePercent = Math.min(parsed.confidencePercent ?? 0, 40);
  }

  return jsonResponse(parsed);
});
