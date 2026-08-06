begin;

create table if not exists public.vehicle_risk_profiles (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  current_mileage integer not null default 0 check (current_mileage between 0 and 2000000),
  annual_mileage integer not null default 12000 check (annual_mileage between 0 and 200000),
  vehicle_age_years integer not null default 5 check (vehicle_age_years between 0 and 80),
  months_since_service integer not null default 12 check (months_since_service between 0 and 240),
  km_since_service integer not null default 10000 check (km_since_service between 0 and 500000),
  short_trips_often boolean not null default false,
  intensive_use boolean not null default false,
  long_immobilization boolean not null default false,
  maintenance_planned boolean not null default false,
  dashboard_warning boolean not null default false,
  braking_concern boolean not null default false,
  tire_concern boolean not null default false,
  starting_concern boolean not null default false,
  engine_cooling_concern boolean not null default false,
  repeated_breakdowns_12m integer not null default 0 check (repeated_breakdowns_12m between 0 and 20),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, vehicle_id)
);

create table if not exists public.vehicle_risk_assessments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  risk_score integer not null check (risk_score between 0 and 100),
  risk_level text not null check (risk_level in ('LOW', 'WATCH', 'ELEVATED', 'PRIORITY')),
  data_confidence text not null check (data_confidence in ('LIMITED', 'MEDIUM', 'STRONG')),
  factors jsonb not null default '[]'::jsonb check (jsonb_typeof(factors) = 'array'),
  input_snapshot jsonb not null default '{}'::jsonb check (jsonb_typeof(input_snapshot) = 'object'),
  calculator_version text not null default 'risk-forecast-v1' check (char_length(calculator_version) between 1 and 40),
  created_at timestamptz not null default now()
);

create index if not exists vehicle_risk_assessments_vehicle_created_idx
  on public.vehicle_risk_assessments (vehicle_id, created_at desc);
create index if not exists vehicle_risk_assessments_user_created_idx
  on public.vehicle_risk_assessments (user_id, created_at desc);

create or replace function public.touch_vehicle_risk_profile_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists vehicle_risk_profiles_touch_updated_at
  on public.vehicle_risk_profiles;
create trigger vehicle_risk_profiles_touch_updated_at
before update on public.vehicle_risk_profiles
for each row execute function public.touch_vehicle_risk_profile_updated_at();

alter table public.vehicle_risk_profiles enable row level security;
alter table public.vehicle_risk_assessments enable row level security;

create policy vehicle_risk_profiles_select_own
on public.vehicle_risk_profiles for select
to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

create policy vehicle_risk_profiles_insert_own
on public.vehicle_risk_profiles for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

create policy vehicle_risk_profiles_update_own
on public.vehicle_risk_profiles for update
to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
)
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

create policy vehicle_risk_profiles_delete_own
on public.vehicle_risk_profiles for delete
to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

create policy vehicle_risk_assessments_select_own
on public.vehicle_risk_assessments for select
to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

create policy vehicle_risk_assessments_insert_own
on public.vehicle_risk_assessments for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

create policy vehicle_risk_assessments_delete_own
on public.vehicle_risk_assessments for delete
to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

grant select, insert, update, delete on public.vehicle_risk_profiles to authenticated;
grant select, insert, delete on public.vehicle_risk_assessments to authenticated;

commit;
