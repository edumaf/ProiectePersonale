#!/usr/bin/env node
// Generates db/seed/seed.sql from db/seed/species.json - keeps the app's
// TS data and the Postgres seed in sync from one source of truth.
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const dir = path.dirname(fileURLToPath(import.meta.url));
const species = JSON.parse(readFileSync(path.join(dir, 'species.json'), 'utf8'));

function sqlString(value) {
  if (value === undefined || value === null) return 'NULL';
  return `'${String(value).replace(/'/g, "''")}'`;
}

function sqlTextArray(values) {
  if (!values || values.length === 0) return "'{}'";
  return `ARRAY[${values.map(sqlString).join(', ')}]::text[]`;
}

const columns = [
  'id',
  'common_name',
  'latin_name',
  'edibility_status',
  'requires_cooking',
  'prep_instructions',
  'lookalike_species_ids',
  'toxicity_notes',
  'poisoning_history',
  'habitat',
  'season',
  'region',
  'photo_urls',
  'confidence_notes',
  'cooking_methods',
];

// Guard rail: cooking advice must never appear on a species the app
// classifies as toxic/deadly/inedible/unknown. The DB has a matching
// check constraint; this fails the build earlier and more loudly.
for (const s of species) {
  if (s.cookingMethods?.length && !['edible', 'edible_cooked'].includes(s.edibilityStatus)) {
    throw new Error(`${s.id} is "${s.edibilityStatus}" but has cookingMethods - refusing to generate.`);
  }
}

const rows = species.map((s) => {
  const values = [
    sqlString(s.id),
    sqlString(s.commonName),
    sqlString(s.latinName),
    sqlString(s.edibilityStatus),
    s.requiresCooking ? 'true' : 'false',
    sqlString(s.prepInstructions),
    sqlTextArray(s.lookalikeSpeciesIds),
    sqlString(s.toxicityNotes),
    sqlString(s.poisoningHistory),
    sqlString(s.habitat),
    sqlString(s.season),
    sqlString(s.region),
    sqlTextArray(s.photoUrls),
    sqlString(s.confidenceNotes),
    `${sqlString(JSON.stringify(s.cookingMethods ?? []))}::jsonb`,
  ];
  return `  (${values.join(', ')})`;
});

const sql = `-- Generated from db/seed/species.json by db/seed/generate-sql.mjs.
-- Do not edit by hand - edit species.json and regenerate instead.

insert into species (${columns.join(', ')})
values
${rows.join(',\n')}
on conflict (id) do update set
  common_name = excluded.common_name,
  latin_name = excluded.latin_name,
  edibility_status = excluded.edibility_status,
  requires_cooking = excluded.requires_cooking,
  prep_instructions = excluded.prep_instructions,
  lookalike_species_ids = excluded.lookalike_species_ids,
  toxicity_notes = excluded.toxicity_notes,
  poisoning_history = excluded.poisoning_history,
  habitat = excluded.habitat,
  season = excluded.season,
  region = excluded.region,
  photo_urls = excluded.photo_urls,
  confidence_notes = excluded.confidence_notes,
  cooking_methods = excluded.cooking_methods,
  updated_at = now();
`;

writeFileSync(path.join(dir, 'seed.sql'), sql);
console.log(`Wrote ${species.length} species to db/seed/seed.sql`);

// Fixed filename (not timestamped) so re-running this script updates the
// same migration in place instead of piling up duplicates.
const migrationPath = path.join(dir, '..', '..', 'supabase', 'migrations', '20260730120100_seed_species.sql');
writeFileSync(migrationPath, sql);
console.log(`Wrote ${species.length} species to supabase/migrations/20260730120100_seed_species.sql`);

// The identify edge function runs in its own Deno sandbox and can only
// import files within supabase/functions/, so it gets its own copy of the
// catalog rather than reaching across to db/seed/. A .ts module (rather
// than a JSON import assertion) keeps this portable across Deno versions.
const sharedSpeciesPath = path.join(dir, '..', '..', 'supabase', 'functions', '_shared', 'species.ts');
const sharedSpeciesContent = `// Generated from db/seed/species.json by db/seed/generate-sql.mjs.
// Do not edit by hand - edit species.json and regenerate instead.

export const speciesCatalog = ${JSON.stringify(species, null, 2)} as const;
`;
writeFileSync(sharedSpeciesPath, sharedSpeciesContent);
console.log('Wrote supabase/functions/_shared/species.ts');
