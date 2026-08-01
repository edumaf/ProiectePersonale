-- Culinary preparation methods, Pro-gated in the app.
--
-- Separate from prep_instructions, which carries safety-critical
-- requirements ("must be boiled 15 min, discard water"). This column is
-- technique/flavour advice and never overrides that. Only populated for
-- species with edibility_status in ('edible', 'edible_cooked') - the
-- check constraint below makes that a database-level guarantee rather
-- than a convention the seed script has to remember.

alter table species add column cooking_methods jsonb not null default '[]';

alter table species add constraint species_cooking_methods_edible_only
  check (
    cooking_methods = '[]'::jsonb
    or edibility_status in ('edible', 'edible_cooked')
  );
