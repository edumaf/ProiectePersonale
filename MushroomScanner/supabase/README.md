# Supabase setup

The app runs in **demo mode** with no setup at all (mock data, fake
identification delay). Follow this to make it real.

## 1. Create a project

Create a project at supabase.com, then from the repo root:

```
cd MushroomScanner
npx supabase login
npx supabase link --project-ref <your-project-ref>
```

## 2. Apply the database schema

```
npx supabase db push
```

This runs both migrations in `supabase/migrations/`: the schema + RLS
policies + storage bucket (`20260730120000_init_schema.sql`), then the
45-species seed data (`20260730120100_seed_species.sql`). Both were
verified against a real Postgres 16 instance with RLS enforcement tested
(two simulated users, confirmed neither can read or write the other's
scans/collections/storage objects) - see the build history for details.

If you edit `db/seed/species.json`, regenerate the seed migration and the
edge function's copy of the catalog before pushing again:

```
node db/seed/generate-sql.mjs
npx supabase db push
```

## 3. Configure auth providers

In the Supabase dashboard under Authentication > Providers:
- **Email** is on by default (magic link, no password) - this is what
  `SignInScreen`'s "Send magic link" button uses.
- **Apple** and **Google** need their own developer-account setup (Apple
  Sign In capability + Services ID, Google OAuth client) before you can
  enable them here - the app's "Continue with Apple/Google" buttons call
  `supabase.auth.signInWithOAuth`, but will error until a provider is
  actually enabled.

Add `mushroomscanner://auth/callback` as a redirect URL under
Authentication > URL Configuration (this matches `app.json`'s `scheme`).

## 4. Deploy the identify edge function

```
npx supabase functions deploy identify
npx supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
```

`CLAUDE_MODEL` defaults to `claude-sonnet-5`; set it as a secret too if you
want a different model.

## 5. Configure the app

Copy `.env.example` to `.env` in `MushroomScanner/` and fill in your
project's URL and anon key (Project Settings > API), then restart
`npx expo start`.

## What's genuinely verified vs. not

- Schema, RLS policies, and the storage bucket policy: verified against a
  real (if stubbed-auth) Postgres instance in this environment.
- The `identify` edge function: written to Supabase's documented
  `_shared/` pattern and the Claude Messages API's documented vision
  request shape, but **not** executed against a live Anthropic key or a
  deployed Supabase project from this session - there was no way to do
  that without your credentials. Test it for real after step 4 above.
- Auth (email magic link + Apple/Google OAuth buttons): written to
  Supabase's documented Expo deep-link pattern, same caveat - untested
  against a live project.
