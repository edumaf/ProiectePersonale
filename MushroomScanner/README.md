# MushroomScanner

Mobile app (React Native + Expo) that identifies wild mushrooms from a photo
and tells foragers whether they're safe to eat. English-first MVP.

## Status: Build step 2 - species database + real seed data

Navigation shell and all screens are wired up (build step 1). The species
database schema now exists and is seeded with ~45 real, sourced European
foraging species. The app currently reads that seed data locally (bundled
via `db/seed/species.json`), since there's no backend/API yet - that's
build step 3.

## Structure

```
App.tsx                    Navigation container root
src/navigation/             Root stack + bottom tab navigators, route types
src/screens/                 One file per screen (see below)
src/components/              Shared UI: EdibilityBadge, ConfidenceBadge, Card, PrimaryButton
src/theme/                    Colors, typography, spacing (earth-tone editorial palette)
src/data/                      App-side data access: species.ts (reads db/seed/species.json),
                                mockScans.ts (still placeholder), poisonControl.ts
src/types/                     Domain model types (Species, ScanResult, Collection)
src/utils/confidence.ts       Confidence-level + low-confidence safety threshold logic
db/schema.sql                  Postgres schema: species / scans / collections
db/seed/species.json           Canonical ~45-species dataset (source of truth)
db/seed/generate-sql.mjs       Regenerates db/seed/seed.sql from species.json
db/seed/seed.sql                Generated INSERT statements - verified against a real
                                Postgres 16 instance (schema + seed both apply cleanly)
```

Regenerate the SQL seed after editing `species.json`:

```
node db/seed/generate-sql.mjs
```

### Screens

Onboarding (safety consent) -> Main (bottom tabs: Dashboard, Scan, My Finds,
Scan History, Learn) -> Result, Species Detail, Collection Detail, AI
Assistant (pushed on the root stack).

### Scan flow

The Scan screen captures multiple angles per specimen - cap (required),
gills/underside, and stem base (both recommended) - rather than a single
photo. Gill pattern and a hidden volva at the stem base are often the only
way to tell a safe species from a deadly Amanita look-alike, so the app
asks for them explicitly instead of accepting one photo like most
competing scanner apps do.

### Species data

`db/seed/species.json` covers ~45 European foraging species: prized
edibles (chanterelle, porcini, morel, hedgehog mushroom, etc.) each paired
with their real dangerous look-alikes (false chanterelle, Satan's bolete,
false morel, deadly dapperling, funeral bell, deadly webcap-adjacent
species, etc.), plus the deadly Amanitas (Death Cap, Destroying Angel).
Poisoning history is written qualitatively per the safety requirements -
no invented death tolls. The Result screen's look-alike section shows the
user's own photo side-by-side with each look-alike's reference photo for
direct visual comparison.

## Safety logic already in place

- `LOW_CONFIDENCE_THRESHOLD` in `src/utils/confidence.ts` (currently 85%,
  configurable) forces the Result screen into an "Unknown / Uncertain - do
  not consume" state regardless of the underlying guess.
- Edibility is always shown as a color+icon badge, never buried in text.
- Poison control contact is reachable from the Dashboard and every Result
  screen.

## Pre-launch TODOs (do not skip)

- **Terms of use / liability disclaimer must be reviewed by a lawyer**
  before public launch. Not started.
- Onboarding consent state is not yet persisted (always shows on launch);
  needs storage once auth lands.
- Poison-control numbers in `src/data/poisonControl.ts` cover a handful of
  countries and need a real locale-detection + expanded list.
- Photo URLs are still placeholder (`picsum.photos`), for both scans and
  species reference photos - need real, licensed species photography
  before launch.
- `src/data/mockScans.ts` (scans/collections) is still placeholder; scans
  move to the real `scans`/`collections` tables once auth + API exist.

## Next build steps

3. Backend/API + auth; wire photo capture -> Claude vision identification
   call -> real result data (replacing the mock/fake delay in `ScanScreen`),
   and move scans/collections off local mock data into Postgres.
4. Confidence-threshold + look-alike warning logic against real model output.
5. Collections, scan history, dashboard against real persisted data.
6. AI assistant chat wired to a real per-species-scoped model call.
7. Visual polish pass, then final onboarding/consent copy.
