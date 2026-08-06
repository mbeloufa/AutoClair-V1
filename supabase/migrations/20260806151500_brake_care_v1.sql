create table if not exists public.brake_care_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  checked_at date not null,
  check_context text not null check (
    check_context in ('ROUTINE', 'BEFORE_TRIP', 'UNUSUAL_BRAKING', 'AFTER_IMPACT')
  ),
  vehicle_can_move_safely boolean not null,
  braking_anomaly boolean not null default false,
  steering_instability boolean not null default false,
  recent_impact boolean not null default false,
  checks jsonb not null default '{}'::jsonb,
  care_score integer not null check (care_score between 0 and 100),
  care_level text not null check (care_level in ('READY', 'REVIEW', 'ACTION', 'URGENT')),
  completeness_percent integer not null check (completeness_percent between 0 and 100),
  urgent_count integer not null default 0 check (urgent_count >= 0),
  findings jsonb not null default '[]'::jsonb,
  calculator_version text not null,
  created_at timestamptz not null default now()
);

create index if not exists brake_care_checks_vehicle_created_idx
  on public.brake_care_checks(vehicle_id, created_at desc);

alter table public.brake_care_checks enable row level security;

create policy "brake care select own"
  on public.brake_care_checks
  for select
  using (
    user_id = auth.uid()
    and public.autoclair_user_owns_vehicle(vehicle_id)
  );

create policy "brake care insert own"
  on public.brake_care_checks
  for insert
  with check (
    user_id = auth.uid()
    and public.autoclair_user_owns_vehicle(vehicle_id)
  );

create policy "brake care delete own"
  on public.brake_care_checks
  for delete
  using (
    user_id = auth.uid()
    and public.autoclair_user_owns_vehicle(vehicle_id)
  );
