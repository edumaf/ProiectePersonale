// MushroomScanner ask-species function (Supabase Edge Function, Deno runtime).
//
// Text-only Claude chat scoped to a single species - the contextual
// assistant reachable from a species detail page. Not a general chatbot:
// the system prompt pins it to one species' reference data and refuses to
// wander, and it carries the same "not a certified mycologist, don't treat
// this as certain, cross-check before eating anything" posture as the rest
// of the app.

import { speciesCatalog } from '../_shared/species.ts';

const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY');
const MODEL = Deno.env.get('CLAUDE_MODEL') ?? 'claude-sonnet-5';
const ANTHROPIC_VERSION = '2023-06-01';

interface ChatMessage {
  role: 'user' | 'assistant';
  text: string;
}

interface AskSpeciesRequestBody {
  speciesId: string;
  messages: ChatMessage[];
}

type SpeciesRecord = (typeof speciesCatalog)[number];

function findSpecies(id: string): SpeciesRecord | undefined {
  return (speciesCatalog as readonly SpeciesRecord[]).find((s) => s.id === id);
}

function lookalikeSummary(species: SpeciesRecord): string {
  if (!species.lookalikeSpeciesIds.length) return 'None on record.';
  return species.lookalikeSpeciesIds
    .map((id) => {
      const look = findSpecies(id);
      return look ? `${look.commonName} (${look.latinName}, ${look.edibilityStatus})` : id;
    })
    .join('; ');
}

function buildSystemPrompt(species: SpeciesRecord): string {
  return `You are the in-app assistant for a single mushroom species page in the MushroomScanner app: ${species.commonName} (${species.latinName}). Answer only questions about this specific species - identification, habitat, season, region, preparation/cooking, toxicity, poisoning history, and its look-alikes. If the user asks something unrelated to this species (general chit-chat, other species, anything outside foraging this mushroom), politely redirect them back to this species.

You are not a certified mycologist and this is a decision-support aid only. Never assert an identification is certain. When the conversation touches on eating or preparing the specimen, remind the user to cross-check with an experienced forager or their local mycological society before consuming anything found in the wild, and never encourage eating an unconfirmed specimen - this applies even for species listed as edible here, since the user's photo may not be a correct match.

Reference data for this species (treat as ground truth, do not contradict it):
- Common name: ${species.commonName}
- Latin name: ${species.latinName}
- Edibility status: ${species.edibilityStatus}
- Requires cooking: ${species.requiresCooking}
- Prep instructions: ${species.prepInstructions ?? 'None on record.'}
- Toxicity notes: ${species.toxicityNotes ?? 'None on record.'}
- Poisoning history: ${species.poisoningHistory ?? 'None on record.'}
- Habitat: ${species.habitat}
- Season: ${species.season}
- Region: ${species.region}
- Look-alikes: ${lookalikeSummary(species)}
- Confidence/ID notes: ${species.confidenceNotes ?? 'None on record.'}

Keep answers conversational and concise - 2-4 sentences unless the question genuinely needs more detail.`;
}

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

  let body: AskSpeciesRequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }

  if (!body.speciesId) {
    return jsonResponse({ error: 'speciesId is required' }, 400);
  }
  const species = findSpecies(body.speciesId);
  if (!species) {
    return jsonResponse({ error: `Unknown speciesId: ${body.speciesId}` }, 404);
  }
  if (!Array.isArray(body.messages) || body.messages.length === 0) {
    return jsonResponse({ error: 'At least one message is required' }, 400);
  }
  if (body.messages.length > 40) {
    return jsonResponse({ error: 'Conversation too long (max 40 messages)' }, 400);
  }

  const messages = body.messages.map((m) => ({
    role: m.role,
    content: [{ type: 'text', text: m.text }],
  }));

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
        max_tokens: 512,
        system: buildSystemPrompt(species),
        messages,
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

  return jsonResponse({ reply: textBlock.text });
});
