begin;

create table if not exists public.vehicle_sale_preparation_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  vehicle_id uuid not null
    references public.vehicles(id) on delete cascade,
  buyer_type text not null default 'PRIVATE_INDIVIDUAL'
    check (
      buyer_type in (
        'PRIVATE_INDIVIDUAL',
        'AUTOMOTIVE_PROFESSIONAL'
      )
    ),
  asking_price_eur numeric(12,2) not null default 0
    check (asking_price_eur between 0 and 1000000),
  minimum_price_eur numeric(12,2) not null default 0
    check (
      minimum_price_eur between 0 and 1000000
      and minimum_price_eur <= asking_price_eur
    ),
  preparation_cost_eur numeric(12,2) not null default 0
    check (preparation_cost_eur between 0 and 100000),
  owns_vehicle boolean not null default true,
  registration_available boolean not null default false,
  coholders_ready boolean not null default true,
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
  csa_issued_at date,
  histovec_shared boolean not null default false,
  invoices_available boolean not null default false,
  spare_key_count integer not null default 1
    check (spare_key_count between 0 and 10),
  cession_method text not null default 'UNDECIDED'
    check (
      cession_method in (
        'UNDECIDED',
        'SIMPLIMMAT',
        'FRANCE_TITRES'
      )
    ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (vehicle_id)
);

create table if not exists public.vehicle_sale_readiness_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  vehicle_id uuid not null
    references public.vehicles(id) on delete cascade,
  readiness_score integer not null
    check (readiness_score between 0 and 100),
  blocking_count integer not null default 0
    check (blocking_count between 0 and 100),
  warning_count integer not null default 0
    check (warning_count between 0 and 100),
  asking_price_eur numeric(12,2) not null default 0
    check (asking_price_eur between 0 and 1000000),
  minimum_price_eur numeric(12,2) not null default 0
    check (minimum_price_eur between 0 and 1000000),
  preparation_cost_eur numeric(12,2) not null default 0
    check (preparation_cost_eur between 0 and 100000),
  expected_net_at_asking_eur numeric(12,2) not null default 0
    check (expected_net_at_asking_eur between 0 and 1000000),
  expected_net_at_minimum_eur numeric(12,2) not null default 0
    check (expected_net_at_minimum_eur between 0 and 1000000),
  checklist jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists vehicle_sale_snapshots_vehicle_created_idx
on public.vehicle_sale_readiness_snapshots (vehicle_id, created_at desc);

alter table public.vehicle_sale_preparation_profiles
  enable row level security;
alter table public.vehicle_sale_readiness_snapshots
  enable row level security;

drop policy if exists sale_preparation_profiles_owner_select
on public.vehicle_sale_preparation_profiles;
create policy sale_preparation_profiles_owner_select
on public.vehicle_sale_preparation_profiles
for select to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists sale_preparation_profiles_owner_insert
on public.vehicle_sale_preparation_profiles;
create policy sale_preparation_profiles_owner_insert
on public.vehicle_sale_preparation_profiles
for insert to authenticated
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists sale_preparation_profiles_owner_update
on public.vehicle_sale_preparation_profiles;
create policy sale_preparation_profiles_owner_update
on public.vehicle_sale_preparation_profiles
for update to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
)
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists sale_preparation_profiles_owner_delete
on public.vehicle_sale_preparation_profiles;
create policy sale_preparation_profiles_owner_delete
on public.vehicle_sale_preparation_profiles
for delete to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists sale_readiness_snapshots_owner_select
on public.vehicle_sale_readiness_snapshots;
create policy sale_readiness_snapshots_owner_select
on public.vehicle_sale_readiness_snapshots
for select to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists sale_readiness_snapshots_owner_insert
on public.vehicle_sale_readiness_snapshots;
create policy sale_readiness_snapshots_owner_insert
on public.vehicle_sale_readiness_snapshots
for insert to authenticated
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists sale_readiness_snapshots_owner_delete
on public.vehicle_sale_readiness_snapshots;
create policy sale_readiness_snapshots_owner_delete
on public.vehicle_sale_readiness_snapshots
for delete to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop trigger if exists sale_preparation_profiles_set_updated_at
on public.vehicle_sale_preparation_profiles;
create trigger sale_preparation_profiles_set_updated_at
before update on public.vehicle_sale_preparation_profiles
for each row execute function public.autoclair_set_updated_at();

grant select, insert, update, delete
on public.vehicle_sale_preparation_profiles
to authenticated;

grant select, insert, delete
on public.vehicle_sale_readiness_snapshots
to authenticated;

commit;
