begin;

create table if not exists public.used_vehicle_purchase_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  seller_type text not null default 'PRIVATE_INDIVIDUAL'
    check (
      seller_type in (
        'PRIVATE_INDIVIDUAL',
        'AUTOMOTIVE_PROFESSIONAL'
      )
    ),
  make text check (make is null or char_length(make) <= 80),
  model text check (model is null or char_length(model) <= 80),
  vehicle_year integer check (vehicle_year between 1900 and 2100),
  mileage integer check (mileage between 0 and 3000000),
  asking_price_eur numeric(12,2) not null default 0
    check (asking_price_eur between 0 and 2000000),
  registration_cost_eur numeric(12,2) not null default 0
    check (registration_cost_eur between 0 and 100000),
  immediate_repairs_eur numeric(12,2) not null default 0
    check (immediate_repairs_eur between 0 and 500000),
  inspection_cost_eur numeric(12,2) not null default 0
    check (inspection_cost_eur between 0 and 100000),
  available_budget_eur numeric(12,2) not null default 0
    check (available_budget_eur between 0 and 2000000),
  seller_right_to_sell_verified boolean not null default false,
  registration_available boolean not null default false,
  vin_matches_registration boolean not null default false,
  csa_issued_at date,
  csa_clear boolean not null default false,
  histovec_reviewed boolean not null default false,
  technical_control_date date,
  technical_control_status text not null default 'UNKNOWN'
    check (
      technical_control_status in (
        'UNKNOWN',
        'FAVORABLE',
        'MAJOR_DEFECTS',
        'CRITICAL_DEFECTS',
        'NOT_REQUIRED'
      )
    ),
  mileage_history_coherent boolean not null default false,
  maintenance_evidence boolean not null default false,
  cold_start_observed boolean not null default false,
  warning_lights_clear boolean not null default false,
  test_drive_completed boolean not null default false,
  braking_steering_healthy boolean not null default false,
  leaks_or_smoke_detected boolean not null default false,
  body_structure_concern boolean not null default false,
  secure_payment_planned boolean not null default false,
  deposit_before_checks boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id)
);

create table if not exists public.used_vehicle_purchase_assessments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  seller_type text not null
    check (
      seller_type in (
        'PRIVATE_INDIVIDUAL',
        'AUTOMOTIVE_PROFESSIONAL'
      )
    ),
  make text check (make is null or char_length(make) <= 80),
  model text check (model is null or char_length(model) <= 80),
  vehicle_year integer check (vehicle_year between 1900 and 2100),
  mileage integer check (mileage between 0 and 3000000),
  readiness_score integer not null
    check (readiness_score between 0 and 100),
  decision_level text not null
    check (decision_level in ('READY', 'CAUTION', 'STOP')),
  blocking_count integer not null default 0
    check (blocking_count between 0 and 100),
  warning_count integer not null default 0
    check (warning_count between 0 and 100),
  asking_price_eur numeric(12,2) not null default 0
    check (asking_price_eur between 0 and 2000000),
  total_acquisition_cost_eur numeric(12,2) not null default 0
    check (total_acquisition_cost_eur between 0 and 3000000),
  remaining_budget_eur numeric(12,2) not null default 0
    check (remaining_budget_eur between -3000000 and 3000000),
  checklist jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists used_purchase_assessments_user_created_idx
on public.used_vehicle_purchase_assessments (user_id, created_at desc);

alter table public.used_vehicle_purchase_profiles
  enable row level security;
alter table public.used_vehicle_purchase_assessments
  enable row level security;

drop policy if exists used_purchase_profiles_owner_select
on public.used_vehicle_purchase_profiles;
create policy used_purchase_profiles_owner_select
on public.used_vehicle_purchase_profiles
for select to authenticated
using (user_id = auth.uid());

drop policy if exists used_purchase_profiles_owner_insert
on public.used_vehicle_purchase_profiles;
create policy used_purchase_profiles_owner_insert
on public.used_vehicle_purchase_profiles
for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists used_purchase_profiles_owner_update
on public.used_vehicle_purchase_profiles;
create policy used_purchase_profiles_owner_update
on public.used_vehicle_purchase_profiles
for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists used_purchase_profiles_owner_delete
on public.used_vehicle_purchase_profiles;
create policy used_purchase_profiles_owner_delete
on public.used_vehicle_purchase_profiles
for delete to authenticated
using (user_id = auth.uid());

drop policy if exists used_purchase_assessments_owner_select
on public.used_vehicle_purchase_assessments;
create policy used_purchase_assessments_owner_select
on public.used_vehicle_purchase_assessments
for select to authenticated
using (user_id = auth.uid());

drop policy if exists used_purchase_assessments_owner_insert
on public.used_vehicle_purchase_assessments;
create policy used_purchase_assessments_owner_insert
on public.used_vehicle_purchase_assessments
for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists used_purchase_assessments_owner_delete
on public.used_vehicle_purchase_assessments;
create policy used_purchase_assessments_owner_delete
on public.used_vehicle_purchase_assessments
for delete to authenticated
using (user_id = auth.uid());

drop trigger if exists used_purchase_profiles_set_updated_at
on public.used_vehicle_purchase_profiles;
create trigger used_purchase_profiles_set_updated_at
before update on public.used_vehicle_purchase_profiles
for each row execute function public.autoclair_set_updated_at();

grant select, insert, update, delete
on public.used_vehicle_purchase_profiles
to authenticated;

grant select, insert, delete
on public.used_vehicle_purchase_assessments
to authenticated;

commit;
