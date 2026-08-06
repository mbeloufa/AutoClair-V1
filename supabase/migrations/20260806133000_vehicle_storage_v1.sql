begin;

create table if not exists public.vehicle_storage_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  planned_start_date date not null,
  planned_weeks integer not null check (planned_weeks between 1 and 104),
  scenario text not null check (
    scenario in ('SHORT_PAUSE', 'WINTER_STORAGE', 'LONG_STORAGE', 'RESTART')
  ),
  readiness_score integer not null check (readiness_score between 0 and 100),
  readiness_level text not null check (
    readiness_level in ('READY', 'REVIEW', 'ACTION', 'BLOCKED')
  ),
  completeness_percent integer not null check (
    completeness_percent between 0 and 100
  ),
  blocking_count integer not null default 0 check (blocking_count between 0 and 20),
  electric_or_hybrid boolean not null default false,
  outdoor_storage boolean not null default false,
  humid_environment boolean not null default false,
  checks jsonb not null default '{}'::jsonb check (jsonb_typeof(checks) = 'object'),
  findings jsonb not null default '[]'::jsonb check (jsonb_typeof(findings) = 'array'),
  calculator_version text not null default 'vehicle-storage-v1'
    check (char_length(calculator_version) between 1 and 40),
  created_at timestamptz not null default now()
);

create index if not exists vehicle_storage_vehicle_created_idx
  on public.vehicle_storage_checks (vehicle_id, created_at desc);
create index if not exists vehicle_storage_user_created_idx
  on public.vehicle_storage_checks (user_id, created_at desc);

alter table public.vehicle_storage_checks enable row level security;

create policy vehicle_storage_select_own
on public.vehicle_storage_checks for select
to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

create policy vehicle_storage_insert_own
on public.vehicle_storage_checks for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

create policy vehicle_storage_delete_own
on public.vehicle_storage_checks for delete
to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

commit;
