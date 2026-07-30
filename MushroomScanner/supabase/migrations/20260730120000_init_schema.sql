-- MushroomScanner initial schema, for deployment via Supabase.
--
-- This mirrors db/schema.sql (the generic, Supabase-independent version
-- used for local Postgres testing) but adds the auth.users foreign keys
-- and enables Row Level Security, both of which only make sense once a
-- real Supabase Auth instance is attached.

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
  lookalike_species_ids text[] not null default '{}',
  toxicity_notes text,
  poisoning_history text,
  habitat text not null,
  season text not null,
  region text not null,
  photo_urls text[] not null default '{}',
  confidence_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index species_edibility_status_idx on species (edibility_status);

create table collections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

create index collections_user_id_idx on collections (user_id);

create table scans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
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

-- Row Level Security -------------------------------------------------------

alter table species enable row level security;
alter table collections enable row level security;
alter table scans enable row level security;

-- Species is public reference data: anyone (including anon/unauthenticated
-- clients) can read it, but only migrations/seed scripts can write it.
create policy "species readable by everyone"
  on species for select
  using (true);

create policy "collections owner read"
  on collections for select
  using (auth.uid() = user_id);

create policy "collections owner insert"
  on collections for insert
  with check (auth.uid() = user_id);

create policy "collections owner update"
  on collections for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "collections owner delete"
  on collections for delete
  using (auth.uid() = user_id);

create policy "scans owner read"
  on scans for select
  using (auth.uid() = user_id);

create policy "scans owner insert"
  on scans for insert
  with check (auth.uid() = user_id);

create policy "scans owner update"
  on scans for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "scans owner delete"
  on scans for delete
  using (auth.uid() = user_id);

-- Storage --------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('scan-photos', 'scan-photos', true)
on conflict (id) do nothing;

-- Uploaded paths are namespaced "<user_id>/<scan-local-id>/<angle>.jpg" so
-- ownership can be checked from the first path segment.
create policy "scan photos owner insert"
  on storage.objects for insert
  with check (
    bucket_id = 'scan-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "scan photos owner delete"
  on storage.objects for delete
  using (
    bucket_id = 'scan-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "scan photos public read"
  on storage.objects for select
  using (bucket_id = 'scan-photos');
