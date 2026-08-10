begin;

-- Preserve the complete useful result of a paid vehicle identification so the
-- app can reuse it without calling the provider again for every screen.
do $$
begin
  if to_regclass('public.vehicles') is null then
    raise exception 'public.vehicles is required before vehicle identification profiles';
  end if;
end
$$;

create table if not exists public.vehicle_identification_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id uuid references public.vehicles(id) on delete cascade,
  registration_number text not null,
  registration_key text not null,
  vin text,
  provider text not null default 'auto_ways_rapidapi',
  source_label text not null default 'API Plaque Immatriculation',
  retrieved_at timestamptz not null default now(),
  identity jsonb not null default '{}'::jsonb,
  technical jsonb not null default '{}'::jsonb,
  administrative jsonb not null default '{}'::jsonb,
  aftersales jsonb not null default '{}'::jsonb,
  media jsonb not null default '{}'::jsonb,
  provider_fields jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vehicle_identification_profiles_registration_key_check
    check (length(registration_key) between 5 and 12),
  constraint vehicle_identification_profiles_vin_check
    check (vin is null or length(vin) = 17),
  constraint vehicle_identification_profiles_identity_object_check
    check (jsonb_typeof(identity) = 'object'),
  constraint vehicle_identification_profiles_technical_object_check
    check (jsonb_typeof(technical) = 'object'),
  constraint vehicle_identification_profiles_administrative_object_check
    check (jsonb_typeof(administrative) = 'object'),
  constraint vehicle_identification_profiles_aftersales_object_check
    check (jsonb_typeof(aftersales) = 'object'),
  constraint vehicle_identification_profiles_media_object_check
    check (jsonb_typeof(media) = 'object'),
  constraint vehicle_identification_profiles_provider_fields_object_check
    check (jsonb_typeof(provider_fields) = 'object'),
  unique (user_id, registration_key, provider)
);

create index if not exists vehicle_identification_profiles_vehicle_id_idx
  on public.vehicle_identification_profiles(vehicle_id)
  where vehicle_id is not null;

create index if not exists vehicle_identification_profiles_user_retrieved_idx
  on public.vehicle_identification_profiles(user_id, retrieved_at desc);

alter table public.vehicle_identification_profiles enable row level security;

drop policy if exists vehicle_identification_profiles_select_own
  on public.vehicle_identification_profiles;
create policy vehicle_identification_profiles_select_own
on public.vehicle_identification_profiles
for select
to authenticated
using ((select auth.uid()) = user_id);

revoke all on table public.vehicle_identification_profiles from anon;
revoke insert, update, delete on table public.vehicle_identification_profiles from authenticated;
grant select on table public.vehicle_identification_profiles to authenticated;

create or replace function public.autoclair_link_vehicle_identification_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_registration_key text;
begin
  v_registration_key := upper(
    regexp_replace(coalesce(new.registration_number, ''), '[^A-Za-z0-9]', '', 'g')
  );

  if v_registration_key = '' then
    return new;
  end if;

  update public.vehicle_identification_profiles
  set vehicle_id = null,
      updated_at = now()
  where user_id = new.user_id
    and vehicle_id = new.id
    and registration_key <> v_registration_key;

  update public.vehicle_identification_profiles
  set vehicle_id = new.id,
      updated_at = now()
  where user_id = new.user_id
    and registration_key = v_registration_key
    and provider = 'auto_ways_rapidapi';

  return new;
end;
$$;

revoke all on function public.autoclair_link_vehicle_identification_profile()
  from public, anon, authenticated;

drop trigger if exists autoclair_link_vehicle_identification_profile_trigger
  on public.vehicles;
create trigger autoclair_link_vehicle_identification_profile_trigger
after insert or update of registration_number
on public.vehicles
for each row
execute function public.autoclair_link_vehicle_identification_profile();

commit;
