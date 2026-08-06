begin;

create table if not exists public.vehicle_accident_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  vehicle_id uuid not null
    references public.vehicles(id) on delete cascade,
  insurer_name text
    check (insurer_name is null or char_length(insurer_name) <= 100),
  claim_phone text
    check (claim_phone is null or char_length(claim_phone) <= 32),
  assistance_phone text
    check (assistance_phone is null or char_length(assistance_phone) <= 32),
  contract_reference text
    check (
      contract_reference is null or char_length(contract_reference) <= 100
    ),
  memo_vehicle_insured_available boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, vehicle_id)
);

create table if not exists public.vehicle_accident_cases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  vehicle_id uuid not null
    references public.vehicles(id) on delete cascade,
  occurred_at date not null,
  location_type text not null
    check (location_type in ('MOTORWAY', 'ROAD', 'URBAN', 'PARKING')),
  injured boolean not null default false,
  immediate_danger boolean not null default false,
  vehicle_count integer not null
    check (vehicle_count between 1 and 10),
  foreign_vehicle boolean not null default false,
  material_damage_only boolean not null default true,
  other_party_refused boolean not null default false,
  emergency_called boolean not null default false,
  police_attended boolean not null default false,
  witnesses_present boolean not null default false,
  photos_taken boolean not null default false,
  sketch_prepared boolean not null default false,
  report_signed boolean not null default false,
  insurer_notified boolean not null default false,
  memo_available boolean not null default false,
  action_level text not null
    check (
      action_level in (
        'EMERGENCY',
        'PAPER_REPORT',
        'ELECTRONIC_REPORT',
        'INSURER_DECLARATION'
      )
    ),
  readiness_score integer not null
    check (readiness_score between 0 and 100),
  econstat_eligible boolean not null default false,
  paper_report_required boolean not null default false,
  declaration_due_date date not null,
  checklist jsonb not null default '[]'::jsonb,
  timeline_event_id uuid,
  created_at timestamptz not null default now()
);

create index if not exists vehicle_accident_cases_user_vehicle_date_idx
on public.vehicle_accident_cases (user_id, vehicle_id, occurred_at desc);

alter table public.vehicle_accident_profiles
  enable row level security;
alter table public.vehicle_accident_cases
  enable row level security;

drop policy if exists vehicle_accident_profiles_owner_select
on public.vehicle_accident_profiles;
create policy vehicle_accident_profiles_owner_select
on public.vehicle_accident_profiles
for select to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_accident_profiles_owner_insert
on public.vehicle_accident_profiles;
create policy vehicle_accident_profiles_owner_insert
on public.vehicle_accident_profiles
for insert to authenticated
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_accident_profiles_owner_update
on public.vehicle_accident_profiles;
create policy vehicle_accident_profiles_owner_update
on public.vehicle_accident_profiles
for update to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
)
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_accident_profiles_owner_delete
on public.vehicle_accident_profiles;
create policy vehicle_accident_profiles_owner_delete
on public.vehicle_accident_profiles
for delete to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_accident_cases_owner_select
on public.vehicle_accident_cases;
create policy vehicle_accident_cases_owner_select
on public.vehicle_accident_cases
for select to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_accident_cases_owner_insert
on public.vehicle_accident_cases;
create policy vehicle_accident_cases_owner_insert
on public.vehicle_accident_cases
for insert to authenticated
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_accident_cases_owner_delete
on public.vehicle_accident_cases;
create policy vehicle_accident_cases_owner_delete
on public.vehicle_accident_cases
for delete to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop trigger if exists vehicle_accident_profiles_set_updated_at
on public.vehicle_accident_profiles;
create trigger vehicle_accident_profiles_set_updated_at
before update on public.vehicle_accident_profiles
for each row execute function public.autoclair_set_updated_at();

grant select, insert, update, delete
on public.vehicle_accident_profiles
to authenticated;

grant select, insert, delete
on public.vehicle_accident_cases
to authenticated;

commit;
