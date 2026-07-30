# MushroomScanner

Mobile app (React Native + Expo) that identifies wild mushrooms from a photo
and tells foragers whether they're safe to eat. English-first MVP.

## Status: Build step 1 - navigation shell

All screens exist as static mockups wired into navigation, backed by mock
data in `src/data/`. No backend, auth, database, or real identification
call yet - those are later build steps.

## Structure

```
App.tsx                  Navigation container root
src/navigation/           Root stack + bottom tab navigators, route types
src/screens/               One file per screen (see below)
src/components/            Shared UI: EdibilityBadge, ConfidenceBadge, Card, PrimaryButton
src/theme/                  Colors, typography, spacing (earth-tone editorial palette)
src/data/                    Mock species/scans/collections + poison-control numbers
src/types/                   Domain model types (Species, ScanResult, Collection)
src/utils/confidence.ts     Confidence-level + low-confidence safety threshold logic
```

### Screens

Onboarding (safety consent) -> Main (bottom tabs: Dashboard, Scan, My Finds,
Scan History, Learn) -> Result, Species Detail, Collection Detail, AI
Assistant (pushed on the root stack).

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
- Photo URLs in mock data are placeholder (`picsum.photos`), not real
  species photography.

## Next build steps

2. Species database schema + real, sourced seed data (~40-60 European
   species, depth on dangerous look-alikes).
3. Wire photo capture -> Claude vision identification call -> real result
   data (replacing the mock/fake delay in `ScanScreen`).
4. Confidence-threshold + look-alike warning logic against real model output.
5. Collections, scan history, dashboard against real persisted data.
6. AI assistant chat wired to a real per-species-scoped model call.
7. Visual polish pass, then final onboarding/consent copy.
