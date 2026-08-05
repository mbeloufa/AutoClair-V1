begin;

create table if not exists public.vehicle_eco_driving_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  vehicle_id uuid not null
    references public.vehicles(id) on delete cascade,
  energy_type text not null default 'fuel'
    check (energy_type in ('fuel','electric')),
  consumption_per_100km numeric(7,2) not null default 6.5
    check (
      consumption_per_100km > 0
      and consumption_per_100km <= 100
    ),
  energy_price numeric(7,3) not null default 1.85
    check (energy_price >= 0 and energy_price <= 10),
  potential_gain_percent numeric(5,2) not null default 5
    check (
      potential_gain_percent >= 0
      and potential_gain_percent <= 15
    ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (vehicle_id)
);

create table if not exists public.eco_driving_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  vehicle_id uuid not null
    references public.vehicles(id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  duration_seconds integer not null
    check (duration_seconds >= 0 and duration_seconds <= 86400),
  moving_seconds integer not null default 0
    check (moving_seconds >= 0 and moving_seconds <= 86400),
  idle_seconds integer not null default 0
    check (idle_seconds >= 0 and idle_seconds <= 86400),
  distance_km numeric(9,3) not null default 0
    check (distance_km >= 0 and distance_km <= 2000),
  average_speed_kph numeric(7,2) not null default 0
    check (average_speed_kph >= 0 and average_speed_kph <= 300),
  harsh_acceleration_count integer not null default 0
    check (harsh_acceleration_count >= 0),
  harsh_braking_count integer not null default 0
    check (harsh_braking_count >= 0),
  accepted_sample_count integer not null default 0
    check (accepted_sample_count >= 0),
  discarded_sample_count integer not null default 0
    check (discarded_sample_count >= 0),
  score integer not null default 100
    check (score >= 0 and score <= 100),
  baseline_energy_cost numeric(10,2) not null default 0
    check (baseline_energy_cost >= 0),
  potential_saving numeric(10,2) not null default 0
    check (
      potential_saving >= 0
      and potential_saving <= baseline_energy_cost
    ),
  created_at timestamptz not null default now(),
  check (ended_at >= started_at),
  check (moving_seconds + idle_seconds <= duration_seconds + 60)
);

create index if not exists eco_driving_sessions_vehicle_started_idx
on public.eco_driving_sessions (vehicle_id, started_at desc);

alter table public.vehicle_eco_driving_profiles enable row level security;
alter table public.eco_driving_sessions enable row level security;

drop policy if exists vehicle_eco_driving_profiles_owner_select
on public.vehicle_eco_driving_profiles;
create policy vehicle_eco_driving_profiles_owner_select
on public.vehicle_eco_driving_profiles
for select to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_eco_driving_profiles_owner_insert
on public.vehicle_eco_driving_profiles;
create policy vehicle_eco_driving_profiles_owner_insert
on public.vehicle_eco_driving_profiles
for insert to authenticated
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_eco_driving_profiles_owner_update
on public.vehicle_eco_driving_profiles;
create policy vehicle_eco_driving_profiles_owner_update
on public.vehicle_eco_driving_profiles
for update to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
)
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_eco_driving_profiles_owner_delete
on public.vehicle_eco_driving_profiles;
create policy vehicle_eco_driving_profiles_owner_delete
on public.vehicle_eco_driving_profiles
for delete to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists eco_driving_sessions_owner_select
on public.eco_driving_sessions;
create policy eco_driving_sessions_owner_select
on public.eco_driving_sessions
for select to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists eco_driving_sessions_owner_insert
on public.eco_driving_sessions;
create policy eco_driving_sessions_owner_insert
on public.eco_driving_sessions
for insert to authenticated
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists eco_driving_sessions_owner_delete
on public.eco_driving_sessions;
create policy eco_driving_sessions_owner_delete
on public.eco_driving_sessions
for delete to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop trigger if exists vehicle_eco_driving_profiles_set_updated_at
on public.vehicle_eco_driving_profiles;
create trigger vehicle_eco_driving_profiles_set_updated_at
before update on public.vehicle_eco_driving_profiles
for each row execute function public.autoclair_set_updated_at();

grant select, insert, update, delete
on public.vehicle_eco_driving_profiles to authenticated;

grant select, insert, delete
on public.eco_driving_sessions to authenticated;

commit;
