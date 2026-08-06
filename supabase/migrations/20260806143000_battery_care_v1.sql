create table if not exists public.battery_care_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  checked_at date not null,
  check_context text not null check (
    check_context in ('ROUTINE', 'BEFORE_TRIP', 'AFTER_LONG_PARKING', 'AFTER_DIFFICULT_START')
  ),
  vehicle_can_move_safely boolean not null,
  difficult_start boolean not null default false,
  recent_discharge boolean not null default false,
  parked_more_than_14_days boolean not null default false,
  checks jsonb not null default '{}'::jsonb,
  care_score integer not null check (care_score between 0 and 100),
  care_level text not null check (care_level in ('READY', 'REVIEW', 'ACTION', 'URGENT')),
  completeness_percent integer not null check (completeness_percent between 0 and 100),
  urgent_count integer not null default 0 check (urgent_count >= 0),
  findings jsonb not null default '[]'::jsonb,
  calculator_version text not null,
  created_at timestamptz not null default now()
);

create index if not exists battery_care_checks_vehicle_created_idx
  on public.battery_care_checks(vehicle_id, created_at desc);

alter table public.battery_care_checks enable row level security;

create policy "battery care select own"
  on public.battery_care_checks
  for select
  using (
    user_id = auth.uid()
    and public.autoclair_user_owns_vehicle(vehicle_id)
  );

create policy "battery care insert own"
  on public.battery_care_checks
  for insert
  with check (
    user_id = auth.uid()
    and public.autoclair_user_owns_vehicle(vehicle_id)
  );

create policy "battery care delete own"
  on public.battery_care_checks
  for delete
  using (
    user_id = auth.uid()
    and public.autoclair_user_owns_vehicle(vehicle_id)
  );
