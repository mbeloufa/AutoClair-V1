create table if not exists public.tire_care_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  checked_at date not null,
  check_context text not null check (check_context in ('ROUTINE', 'BEFORE_TRIP', 'SEASONAL_CHANGE', 'AFTER_IMPACT')),
  vehicle_can_move_safely boolean not null default true,
  vibration_or_pulling boolean not null default false,
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

alter table public.tire_care_checks enable row level security;

create index if not exists tire_care_checks_vehicle_created_idx
  on public.tire_care_checks(vehicle_id, created_at desc);

create policy "Users can read their tire checks"
  on public.tire_care_checks
  for select
  to authenticated
  using (
    user_id = auth.uid()
    and public.autoclair_user_owns_vehicle(vehicle_id)
  );

create policy "Users can create their tire checks"
  on public.tire_care_checks
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and public.autoclair_user_owns_vehicle(vehicle_id)
  );

create policy "Users can delete their tire checks"
  on public.tire_care_checks
  for delete
  to authenticated
  using (
    user_id = auth.uid()
    and public.autoclair_user_owns_vehicle(vehicle_id)
  );
