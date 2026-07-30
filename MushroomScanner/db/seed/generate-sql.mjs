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
];

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
  updated_at = now();
`;

writeFileSync(path.join(dir, 'seed.sql'), sql);
console.log(`Wrote ${species.length} species to db/seed/seed.sql`);
