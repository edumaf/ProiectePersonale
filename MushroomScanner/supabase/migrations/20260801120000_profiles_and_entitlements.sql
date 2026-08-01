-- Subscription tiers and the free-tier scan quota.
--
-- The quota is enforced server-side (consume_scan_credit, called by the
-- identify edge function with the service role) rather than client-side,
-- so a modified client can't grant itself unlimited scans. Likewise,
-- users can read their own profile but have no write policy on it at all
-- - only the service role can change a tier, so nobody can self-upgrade.

create type subscription_tier as enum ('free', 'pro');

create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  tier subscription_tier not null default 'free',
  -- Rolling monthly window for the free-tier scan allowance.
  scan_period_start timestamptz not null default date_trunc('month', now()),
  scans_this_period integer not null default 0,
  -- Null for free users, and for pro subscriptions with no known expiry.
  pro_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table profiles enable row level security;

-- Read-only to the owner. Deliberately no insert/update/delete policies:
-- writes go through the service role (edge functions) exclusively.
create policy "profiles owner read"
  on profiles for select
  using (auth.uid() = id);

-- Give every new auth user a profile row so the app never has to
-- special-case a missing one.
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id) on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- Free-tier scans allowed per calendar month.
create or replace function free_scan_limit()
returns integer
language sql
immutable
as $$ select 5; $$;

-- Atomically checks the caller's quota and, if they're allowed, consumes
-- one scan. Returns what the client needs to render a paywall on refusal.
-- SECURITY DEFINER + row lock so concurrent scans can't race past the cap.
create or replace function consume_scan_credit(p_user_id uuid)
returns table (allowed boolean, effective_tier subscription_tier, scans_used integer, scans_limit integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile profiles;
  v_limit integer := free_scan_limit();
  v_period timestamptz := date_trunc('month', now());
  v_is_pro boolean;
begin
  select * into v_profile from profiles where id = p_user_id for update;

  if not found then
    insert into profiles (id) values (p_user_id)
      on conflict (id) do update set updated_at = now()
      returning * into v_profile;
  end if;

  -- Roll the window over on the first scan of a new month.
  if v_profile.scan_period_start < v_period then
    update profiles
      set scan_period_start = v_period, scans_this_period = 0, updated_at = now()
      where id = p_user_id
      returning * into v_profile;
  end if;

  -- An expired pro subscription quietly falls back to free-tier limits.
  v_is_pro := v_profile.tier = 'pro'
    and (v_profile.pro_expires_at is null or v_profile.pro_expires_at > now());

  if not v_is_pro and v_profile.scans_this_period >= v_limit then
    return query select false, 'free'::subscription_tier, v_profile.scans_this_period, v_limit;
    return;
  end if;

  update profiles
    set scans_this_period = scans_this_period + 1, updated_at = now()
    where id = p_user_id
    returning * into v_profile;

  return query select
    true,
    case when v_is_pro then 'pro'::subscription_tier else 'free'::subscription_tier end,
    v_profile.scans_this_period,
    case when v_is_pro then null::integer else v_limit end;
end;
$$;

-- Free users get a limited number of saved collections; pro is unlimited.
create or replace function free_collection_limit()
returns integer
language sql
immutable
as $$ select 1; $$;

create or replace function enforce_collection_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tier subscription_tier;
  v_expires timestamptz;
  v_count integer;
begin
  select tier, pro_expires_at into v_tier, v_expires from profiles where id = new.user_id;

  if v_tier = 'pro' and (v_expires is null or v_expires > now()) then
    return new;
  end if;

  select count(*) into v_count from collections where user_id = new.user_id;
  if v_count >= free_collection_limit() then
    raise exception 'collection_limit_reached'
      using hint = 'Upgrade to Pro for unlimited collections.';
  end if;

  return new;
end;
$$;

create trigger collections_enforce_limit
  before insert on collections
  for each row execute function enforce_collection_limit();
