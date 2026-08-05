begin;

create table if not exists public.vehicle_breakdown_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  vehicle_id uuid not null
    references public.vehicles(id) on delete cascade,
  assistance_provider text
    check (assistance_provider is null or char_length(assistance_provider) <= 100),
  assistance_phone text
    check (assistance_phone is null or char_length(assistance_phone) <= 30),
  contract_reference text
    check (contract_reference is null or char_length(contract_reference) <= 80),
  assistance_zero_km boolean,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (vehicle_id)
);

create table if not exists public.vehicle_breakdown_cases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  vehicle_id uuid not null
    references public.vehicles(id) on delete cascade,
  occurred_at timestamptz not null default now(),
  location_type text not null
    check (location_type in ('MOTORWAY', 'ROAD', 'SAFE_PARKING')),
  action_level text not null
    check (
      action_level in (
        'EMERGENCY',
        'MOTORWAY_SAFETY',
        'STOP_AND_ASSISTANCE',
        'ASSISTANCE_RECOMMENDED',
        'GARAGE_SOON',
        'MONITOR'
      )
    ),
  symptom_codes text[] not null default '{}',
  safety_flags jsonb not null default '{}'::jsonb,
  summary text not null
    check (char_length(summary) between 1 and 5000),
  timeline_event_id uuid
    references public.vehicle_events(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists vehicle_breakdown_cases_vehicle_occurred_idx
on public.vehicle_breakdown_cases (vehicle_id, occurred_at desc);

alter table public.vehicle_breakdown_profiles enable row level security;
alter table public.vehicle_breakdown_cases enable row level security;

drop policy if exists vehicle_breakdown_profiles_owner_select
on public.vehicle_breakdown_profiles;
create policy vehicle_breakdown_profiles_owner_select
on public.vehicle_breakdown_profiles
for select to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_breakdown_profiles_owner_insert
on public.vehicle_breakdown_profiles;
create policy vehicle_breakdown_profiles_owner_insert
on public.vehicle_breakdown_profiles
for insert to authenticated
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_breakdown_profiles_owner_update
on public.vehicle_breakdown_profiles;
create policy vehicle_breakdown_profiles_owner_update
on public.vehicle_breakdown_profiles
for update to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
)
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_breakdown_profiles_owner_delete
on public.vehicle_breakdown_profiles;
create policy vehicle_breakdown_profiles_owner_delete
on public.vehicle_breakdown_profiles
for delete to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_breakdown_cases_owner_select
on public.vehicle_breakdown_cases;
create policy vehicle_breakdown_cases_owner_select
on public.vehicle_breakdown_cases
for select to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_breakdown_cases_owner_insert
on public.vehicle_breakdown_cases;
create policy vehicle_breakdown_cases_owner_insert
on public.vehicle_breakdown_cases
for insert to authenticated
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_breakdown_cases_owner_delete
on public.vehicle_breakdown_cases;
create policy vehicle_breakdown_cases_owner_delete
on public.vehicle_breakdown_cases
for delete to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop trigger if exists vehicle_breakdown_profiles_set_updated_at
on public.vehicle_breakdown_profiles;
create trigger vehicle_breakdown_profiles_set_updated_at
before update on public.vehicle_breakdown_profiles
for each row execute function public.autoclair_set_updated_at();

grant select, insert, update, delete
on public.vehicle_breakdown_profiles to authenticated;

grant select, insert, delete
on public.vehicle_breakdown_cases to authenticated;

commit;
