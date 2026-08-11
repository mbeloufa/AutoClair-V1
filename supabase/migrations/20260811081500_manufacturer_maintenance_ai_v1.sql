begin;

create table if not exists public.manufacturer_maintenance_plans (
  id uuid primary key default gen_random_uuid(),
  vehicle_signature text not null unique,
  make text not null,
  model text not null,
  vehicle_year integer,
  fuel_type text,
  identity jsonb not null default '{}'::jsonb,
  source_quality text not null,
  plan_json jsonb not null default '{}'::jsonb,
  sources jsonb not null default '[]'::jsonb,
  model_id text,
  researched_at timestamptz not null default now(),
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint manufacturer_maintenance_plans_quality_check
    check (source_quality in ('OFFICIAL_EXACT','OFFICIAL_GENERAL','UNAVAILABLE'))
);

alter table public.manufacturer_maintenance_plans enable row level security;
revoke all on table public.manufacturer_maintenance_plans from public, anon, authenticated;
grant select, insert, update, delete on table public.manufacturer_maintenance_plans to service_role;

alter table public.vehicle_maintenance_schedules
  add column if not exists source_key text,
  add column if not exists source_url text,
  add column if not exists source_label text,
  add column if not exists confidence text,
  add column if not exists source_quality text,
  add column if not exists calculation_basis text,
  add column if not exists manufacturer_plan_id uuid
    references public.manufacturer_maintenance_plans(id) on delete set null;

create unique index if not exists vehicle_maintenance_schedules_source_key_uidx
  on public.vehicle_maintenance_schedules(vehicle_id, source_key);

create index if not exists manufacturer_maintenance_plans_expires_idx
  on public.manufacturer_maintenance_plans(expires_at);

commit;