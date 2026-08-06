begin;

create table if not exists public.vehicle_inspections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  purpose text not null check (
    purpose in ('ROUTINE', 'PURCHASE', 'SALE', 'RETURN_LEASE')
  ),
  condition_score integer not null check (condition_score between 0 and 100),
  condition_level text not null check (
    condition_level in ('REASSURING', 'MONITOR', 'ACTION', 'PRIORITY')
  ),
  completeness_percent integer not null check (
    completeness_percent between 0 and 100
  ),
  immediate_action boolean not null default false,
  road_test_completed boolean not null default false,
  photos_available boolean not null default false,
  professional_check_planned boolean not null default false,
  checks jsonb not null default '{}'::jsonb check (jsonb_typeof(checks) = 'object'),
  findings jsonb not null default '[]'::jsonb check (jsonb_typeof(findings) = 'array'),
  calculator_version text not null default 'vehicle-inspection-v1'
    check (char_length(calculator_version) between 1 and 40),
  created_at timestamptz not null default now()
);

create index if not exists vehicle_inspections_vehicle_created_idx
  on public.vehicle_inspections (vehicle_id, created_at desc);
create index if not exists vehicle_inspections_user_created_idx
  on public.vehicle_inspections (user_id, created_at desc);

alter table public.vehicle_inspections enable row level security;

create policy vehicle_inspections_select_own
on public.vehicle_inspections for select
to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

create policy vehicle_inspections_insert_own
on public.vehicle_inspections for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

create policy vehicle_inspections_delete_own
on public.vehicle_inspections for delete
to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

grant select, insert, delete on public.vehicle_inspections to authenticated;

commit;
