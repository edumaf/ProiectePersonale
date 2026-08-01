-- MushroomScanner database schema (PostgreSQL / Supabase).
--
-- Build step 2: species reference table + user scans/collections. Species
-- ids are stable text slugs (e.g. 'death-cap') rather than surrogate keys
-- so lookalike_species_ids can be written and read without a join, and so
-- the seed data in db/seed/ stays human-readable and diffable.

create type edibility_status as enum (
  'edible',
  'edible_cooked',
  'toxic',
  'deadly',
  'inedible',
  'unknown'
);

create table species (
  id text primary key,
  common_name text not null,
  latin_name text not null,
  edibility_status edibility_status not null,
  requires_cooking boolean not null default false,
  prep_instructions text,
  -- Slugs of other rows in this table, not a foreign key array (Postgres
  -- can't FK into an array element); validated by the seed generator instead.
  lookalike_species_ids text[] not null default '{}',
  toxicity_notes text,
  -- Qualitative by design - see MushroomScanner/README.md safety notes.
  -- Never store fabricated precise death tolls here.
  poisoning_history text,
  habitat text not null,
  season text not null,
  region text not null,
  photo_urls text[] not null default '{}',
  confidence_notes text,
  -- [{"method": "...", "detail": "..."}]; edible species only, see the
  -- check constraint. Distinct from prep_instructions, which holds the
  -- safety-critical requirements.
  cooking_methods jsonb not null default '[]',
  constraint species_cooking_methods_edible_only check (
    cooking_methods = '[]'::jsonb
    or edibility_status in ('edible', 'edible_cooked')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index species_edibility_status_idx on species (edibility_status);

create table collections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  name text not null,
  created_at timestamptz not null default now()
);

create index collections_user_id_idx on collections (user_id);

create table scans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  -- One entry per captured angle: [{"angle": "cap", "url": "..."}, ...].
  -- angle is one of 'cap' | 'gills' | 'stem_base', enforced app-side to
  -- keep this table free of another enum type for a small, evolving set.
  photos jsonb not null default '[]',
  species_id text references species (id),
  confidence_score numeric(5, 2) not null check (confidence_score >= 0 and confidence_score <= 100),
  "timestamp" timestamptz not null default now(),
  location_label text,
  collection_id uuid references collections (id) on delete set null,
  user_notes text
);

create index scans_user_id_idx on scans (user_id);
create index scans_collection_id_idx on scans (collection_id);
create index scans_species_id_idx on scans (species_id);
