create table if not exists public.body_safety_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  checked_at date not null,
  check_context text not null check (
    check_context in ('ROUTINE', 'BEFORE_TRIP', 'AFTER_IMPACT', 'BEFORE_CONTROL_OR_SALE')
  ),
  care_score integer not null check (care_score between 0 and 100),
  care_level text not null check (care_level in ('READY', 'REVIEW', 'ACTION', 'URGENT')),
  completeness_percent integer not null check (completeness_percent between 0 and 100),
  urgent_count integer not null default 0 check (urgent_count >= 0),
  vehicle_can_move_safely boolean not null default true,
  closure_concern boolean not null default false,
  restraint_concern boolean not null default false,
  recent_impact boolean not null default false,
  checks jsonb not null default '{}'::jsonb check (jsonb_typeof(checks) = 'object'),
  findings jsonb not null default '[]'::jsonb check (jsonb_typeof(findings) = 'array'),
  calculator_version text not null default 'body-safety-care-v1',
  created_at timestamptz not null default now()
);

create index if not exists body_safety_checks_user_vehicle_created_idx
  on public.body_safety_checks(user_id, vehicle_id, created_at desc);

alter table public.body_safety_checks enable row level security;

create policy "body_safety_checks_select_own"
  on public.body_safety_checks
  for select
  to authenticated
  using (
    user_id = auth.uid()
    and public.autoclair_user_owns_vehicle(vehicle_id)
  );

create policy "body_safety_checks_insert_own"
  on public.body_safety_checks
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and public.autoclair_user_owns_vehicle(vehicle_id)
  );

create policy "body_safety_checks_delete_own"
  on public.body_safety_checks
  for delete
  to authenticated
  using (
    user_id = auth.uid()
    and public.autoclair_user_owns_vehicle(vehicle_id)
  );
