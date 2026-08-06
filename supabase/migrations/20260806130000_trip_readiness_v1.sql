begin;

create table if not exists public.trip_readiness_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  departure_date date not null,
  purpose text not null check (
    purpose in ('EVERYDAY', 'WEEKEND', 'HOLIDAY', 'LONG_JOURNEY', 'WINTER')
  ),
  readiness_score integer not null check (readiness_score between 0 and 100),
  readiness_level text not null check (
    readiness_level in ('READY', 'REVIEW', 'ACTION', 'BLOCKED')
  ),
  completeness_percent integer not null check (
    completeness_percent between 0 and 100
  ),
  blocking_count integer not null default 0 check (blocking_count between 0 and 20),
  long_distance boolean not null default false,
  towing boolean not null default false,
  cold_conditions boolean not null default false,
  young_passengers boolean not null default false,
  breakdown_coverage_known boolean not null default false,
  checks jsonb not null default '{}'::jsonb check (jsonb_typeof(checks) = 'object'),
  findings jsonb not null default '[]'::jsonb check (jsonb_typeof(findings) = 'array'),
  calculator_version text not null default 'trip-readiness-v1'
    check (char_length(calculator_version) between 1 and 40),
  created_at timestamptz not null default now()
);

create index if not exists trip_readiness_vehicle_created_idx
  on public.trip_readiness_checks (vehicle_id, created_at desc);
create index if not exists trip_readiness_user_created_idx
  on public.trip_readiness_checks (user_id, created_at desc);

alter table public.trip_readiness_checks enable row level security;

create policy trip_readiness_select_own
on public.trip_readiness_checks for select
to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

create policy trip_readiness_insert_own
on public.trip_readiness_checks for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

create policy trip_readiness_delete_own
on public.trip_readiness_checks for delete
to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

grant select, insert, delete on public.trip_readiness_checks to authenticated;

commit;
