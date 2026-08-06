begin;

create table if not exists public.vehicle_theft_profiles (
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
  tracker_available boolean not null default false,
  theft_coverage_known boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, vehicle_id)
);

create table if not exists public.vehicle_theft_cases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  vehicle_id uuid not null
    references public.vehicles(id) on delete cascade,
  occurred_at date not null,
  incident_type text not null
    check (
      incident_type in (
        'VEHICLE_THEFT',
        'ATTEMPTED_THEFT',
        'BREAK_IN',
        'VANDALISM',
        'PLATE_THEFT'
      )
    ),
  context_type text not null
    check (context_type in ('HOME', 'PUBLIC_ROAD', 'PARKING', 'OTHER')),
  incident_in_progress boolean not null default false,
  author_known boolean not null default false,
  vehicle_missing boolean not null default false,
  impound_checked boolean not null default false,
  police_reported boolean not null default false,
  complaint_receipt_available boolean not null default false,
  insurer_notified boolean not null default false,
  registration_document_stolen boolean not null default false,
  insurance_documents_stolen boolean not null default false,
  driving_licence_stolen boolean not null default false,
  keys_available_count integer not null default 0
    check (keys_available_count between 0 and 4),
  photos_taken boolean not null default false,
  invoices_available boolean not null default false,
  tracker_declared_to_police boolean not null default false,
  vehicle_found boolean not null default false,
  action_level text not null
    check (
      action_level in (
        'EMERGENCY',
        'CHECK_IMPOUND',
        'POLICE_REPORT',
        'INSURER_DECLARATION',
        'FOLLOW_UP'
      )
    ),
  readiness_score integer not null
    check (readiness_score between 0 and 100),
  online_complaint_eligible boolean not null default false,
  declaration_due_date date not null,
  checklist jsonb not null default '[]'::jsonb,
  timeline_event_id uuid,
  created_at timestamptz not null default now()
);

create index if not exists vehicle_theft_cases_user_vehicle_date_idx
on public.vehicle_theft_cases (user_id, vehicle_id, occurred_at desc);

alter table public.vehicle_theft_profiles
  enable row level security;
alter table public.vehicle_theft_cases
  enable row level security;

drop policy if exists vehicle_theft_profiles_owner_select
on public.vehicle_theft_profiles;
create policy vehicle_theft_profiles_owner_select
on public.vehicle_theft_profiles
for select to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_theft_profiles_owner_insert
on public.vehicle_theft_profiles;
create policy vehicle_theft_profiles_owner_insert
on public.vehicle_theft_profiles
for insert to authenticated
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_theft_profiles_owner_update
on public.vehicle_theft_profiles;
create policy vehicle_theft_profiles_owner_update
on public.vehicle_theft_profiles
for update to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
)
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_theft_profiles_owner_delete
on public.vehicle_theft_profiles;
create policy vehicle_theft_profiles_owner_delete
on public.vehicle_theft_profiles
for delete to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_theft_cases_owner_select
on public.vehicle_theft_cases;
create policy vehicle_theft_cases_owner_select
on public.vehicle_theft_cases
for select to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_theft_cases_owner_insert
on public.vehicle_theft_cases;
create policy vehicle_theft_cases_owner_insert
on public.vehicle_theft_cases
for insert to authenticated
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_theft_cases_owner_delete
on public.vehicle_theft_cases;
create policy vehicle_theft_cases_owner_delete
on public.vehicle_theft_cases
for delete to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop trigger if exists vehicle_theft_profiles_set_updated_at
on public.vehicle_theft_profiles;
create trigger vehicle_theft_profiles_set_updated_at
before update on public.vehicle_theft_profiles
for each row execute function public.autoclair_set_updated_at();

grant select, insert, update, delete
on public.vehicle_theft_profiles
to authenticated;

grant select, insert, delete
on public.vehicle_theft_cases
to authenticated;

commit;
