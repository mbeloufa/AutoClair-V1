begin;

create table if not exists public.technical_control_readiness_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  planned_date date not null,
  visit_context text not null check (
    visit_context in ('PERIODIC', 'COUNTER_VISIT', 'SALE', 'VOLUNTARY')
  ),
  readiness_score integer not null check (readiness_score between 0 and 100),
  readiness_level text not null check (
    readiness_level in ('READY', 'REVIEW', 'ACTION', 'BLOCKED')
  ),
  completeness_percent integer not null check (
    completeness_percent between 0 and 100
  ),
  blocking_count integer not null default 0 check (blocking_count between 0 and 20),
  vehicle_can_move_safely boolean not null default true,
  warning_light_on boolean not null default false,
  checks jsonb not null default '{}'::jsonb check (jsonb_typeof(checks) = 'object'),
  findings jsonb not null default '[]'::jsonb check (jsonb_typeof(findings) = 'array'),
  calculator_version text not null default 'technical-control-readiness-v1'
    check (char_length(calculator_version) between 1 and 60),
  created_at timestamptz not null default now()
);

create index if not exists technical_control_readiness_vehicle_created_idx
  on public.technical_control_readiness_checks (vehicle_id, created_at desc);
create index if not exists technical_control_readiness_user_created_idx
  on public.technical_control_readiness_checks (user_id, created_at desc);

alter table public.technical_control_readiness_checks enable row level security;

create policy technical_control_readiness_select_own
on public.technical_control_readiness_checks for select
to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

create policy technical_control_readiness_insert_own
on public.technical_control_readiness_checks for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

create policy technical_control_readiness_delete_own
on public.technical_control_readiness_checks for delete
to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

commit;
