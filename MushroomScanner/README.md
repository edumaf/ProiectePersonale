# MushroomScanner

Mobile app (React Native + Expo) that identifies wild mushrooms from a photo
and tells foragers whether they're safe to eat. English-first MVP.

**Pinned to Expo SDK 54**, not the latest, on purpose: as of writing, the
public Expo Go app on the iOS App Store is stuck on SDK 54 pending Apple's
review of newer versions, so a project on a newer SDK can't be opened in
plain Expo Go on iPhone at all. Don't bump `expo` past `~54.0.0` (or run a
blanket `expo install --fix` against a newer SDK) without checking
https://expo.dev/go first - it'll silently lock out anyone testing via the
App Store build of Expo Go.

## Status: Build steps 1-3 + 6 - shell, species data, backend, AI assistant

Navigation shell (step 1) and the species database + seed data (step 2) are
done. Step 3 added a real Supabase backend: schema + RLS, auth (email magic
link + Apple/Google OAuth buttons), Storage for scan photos, and an edge
function that calls the Claude API for identification. Step 6 (AI
assistant) is also done, out of build order, since it needed no live
credentials to write - see below. **The app runs with zero setup in demo
mode** (mock data, fake identification delay, canned assistant reply) and
automatically switches to the real backend once you configure it - see
`supabase/README.md`.

## Structure

```
App.tsx                    Navigation container root, wraps everything in AuthProvider
src/navigation/             Root stack + bottom tab navigators, route types
src/screens/                 One file per screen (see below)
src/components/              Shared UI: EdibilityBadge, ConfidenceBadge, Card, PrimaryButton
src/theme/                    Colors, typography, spacing (earth-tone editorial palette)
src/lib/                       config.ts (env/demo-mode detection), supabase.ts (client),
                                auth.tsx (AuthProvider/useAuth), scans.ts (upload/identify/
                                insert/fetch for scans + collections), assistant.ts (ask-species call)
src/hooks/                     useAppData (scans+collections, real or demo), useScan (single scan)
src/data/                      species.ts (reads db/seed/species.json), mockScans.ts (demo-mode
                                fallback data), poisonControl.ts
src/types/                     Domain model types (Species, ScanResult, Collection)
src/utils/confidence.ts       Confidence-level + low-confidence safety threshold logic
db/schema.sql                  Generic Postgres schema (species/scans/collections), for local
                                reference/testing without Supabase's auth/storage schemas
db/seed/species.json           Canonical ~45-species dataset (source of truth)
db/seed/generate-sql.mjs       Regenerates db/seed/seed.sql, supabase/migrations seed, and
                                supabase/functions/_shared/species.ts from species.json
supabase/migrations/           Deployable schema + RLS + storage bucket, and seed data
supabase/functions/identify/   Edge function: Claude vision call constrained to our species catalog
supabase/functions/ask-species/ Edge function: text-only Claude chat scoped to one species
supabase/README.md             Step-by-step setup + what's verified vs. not
```

Regenerate the generated SQL/catalog files after editing `species.json`:

```
node db/seed/generate-sql.mjs
```

### Screens

Onboarding (safety consent) -> SignIn (only when Supabase is configured and
there's no session) -> Main (bottom tabs: Dashboard, Scan, My Finds, Scan
History, Learn) -> Result, Species Detail, Collection Detail, AI Assistant
(pushed on the root stack).

### Scan flow

The Scan screen captures multiple angles per specimen - cap (required),
gills/underside, and stem base (both recommended) - rather than a single
photo. Gill pattern and a hidden volva at the stem base are often the only
way to tell a safe species from a deadly Amanita look-alike, so the app
asks for them explicitly instead of accepting one photo like most
competing scanner apps do.

When signed in, "Identify" uploads the photos to Supabase Storage, calls
the `identify` edge function (Claude vision, prompted with our species
catalog only - it either matches a known id or returns `null`, never an
invented species), and inserts a real `scans` row. In demo mode it falls
back to a fixed mock result after a short delay.

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

### AI assistant

Reachable from the Result screen and every Species Detail page. It's a
chat scoped to one species, not a general chatbot: the `ask-species` edge
function's system prompt pins it to that species' reference data (habitat,
prep, toxicity, look-alikes) and instructs it to redirect off-topic
questions and never encourage eating an unconfirmed specimen. Falls back
to a one-line "connect Supabase to talk to the real assistant" message in
demo mode.

## Safety logic already in place

- `LOW_CONFIDENCE_THRESHOLD` in `src/utils/confidence.ts` (currently 85%,
  configurable) forces the Result screen into an "Unknown / Uncertain - do
  not consume" state regardless of the underlying guess.
- The `identify` edge function's system prompt constrains the model to our
  fixed species catalog and instructs it to return `null` rather than
  force a guess; any id outside the catalog is discarded server-side too.
- Edibility is always shown as a color+icon badge, never buried in text.
- Poison control contact is reachable from the Dashboard and every Result
  screen.
- Row Level Security ensures a user can only ever read/write their own
  scans, collections, and uploaded photos - verified against a real
  Postgres instance with two simulated users (see `supabase/README.md`).

## Demo mode vs. real backend

The app works two ways depending on whether `EXPO_PUBLIC_SUPABASE_URL` /
`EXPO_PUBLIC_SUPABASE_ANON_KEY` are set (see `.env.example`):

- **Not set (default)**: Onboarding goes straight to Main, no sign-in.
  Dashboard/History/My Finds show a small fixed set of mock scans and
  collections (labeled "Demo mode"). Scan's "Identify" always returns the
  same mock chanterelle result. The AI Assistant replies with a fixed
  "connect Supabase" message.
- **Set, and Supabase is provisioned** (`supabase/README.md`): Onboarding
  routes to SignIn if there's no session. Once signed in, everything reads
  and writes real data, Scan calls the real Claude vision identify
  function, and the AI Assistant has a real conversation.

## Pre-launch TODOs (do not skip)

- **Terms of use / liability disclaimer must be reviewed by a lawyer**
  before public launch. Not started.
- Onboarding consent state is not yet persisted (always shows on launch).
- Apple/Google sign-in buttons call `supabase.auth.signInWithOAuth`, but
  need real provider credentials configured in the Supabase dashboard
  (Apple Services ID, Google OAuth client) before they'll work - see
  `supabase/README.md` step 3.
- Poison-control numbers in `src/data/poisonControl.ts` cover a handful of
  countries and need a real locale-detection + expanded list.
- Photo URLs are still placeholder (`picsum.photos`) for species reference
  photos - need real, licensed species photography before launch.
- The `identify`/`ask-species` edge functions and the auth flow were
  written to Supabase's documented patterns but **not exercised against a
  live Supabase project or Anthropic key** - there was no way to do that
  without real credentials. Test all three for real after following
  `supabase/README.md`.

## Next build steps

4. Validate the confidence-threshold/look-alike logic against real model
   output once the identify function is live (is 85% the right cutoff in
   practice?).
5. Polish Dashboard/My Finds/History against real usage - pull-to-refresh,
   pagination, empty states.
7. Visual polish pass, then final onboarding/consent copy.
