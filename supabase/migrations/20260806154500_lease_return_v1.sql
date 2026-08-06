create table if not exists public.lease_return_preparations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  prepared_at date not null,
  preparation_context text not null check (
    preparation_context in (
      'END_OF_CONTRACT',
      'EARLY_RETURN',
      'BEFORE_PRE_INSPECTION',
      'COMPARE_RETURN_OR_PURCHASE'
    )
  ),
  preparation_score integer not null check (preparation_score between 0 and 100),
  preparation_level text not null check (
    preparation_level in ('READY', 'REVIEW', 'ACTION', 'URGENT')
  ),
  completeness_percent integer not null check (completeness_percent between 0 and 100),
  urgent_count integer not null default 0 check (urgent_count >= 0),
  vehicle_can_move_safely boolean not null default true,
  contract_instructions_available boolean not null default false,
  all_keys_and_accessories_available boolean not null default false,
  warning_or_mechanical_concern boolean not null default false,
  checks jsonb not null default '{}'::jsonb check (jsonb_typeof(checks) = 'object'),
  findings jsonb not null default '[]'::jsonb check (jsonb_typeof(findings) = 'array'),
  calculator_version text not null default 'lease-return-v1',
  created_at timestamptz not null default now()
);

create index if not exists lease_return_preparations_user_vehicle_created_idx
  on public.lease_return_preparations(user_id, vehicle_id, created_at desc);

alter table public.lease_return_preparations enable row level security;

create policy "lease_return_preparations_select_own"
  on public.lease_return_preparations
  for select
  to authenticated
  using (
    user_id = auth.uid()
    and public.autoclair_user_owns_vehicle(vehicle_id)
  );

create policy "lease_return_preparations_insert_own"
  on public.lease_return_preparations
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and public.autoclair_user_owns_vehicle(vehicle_id)
  );

create policy "lease_return_preparations_delete_own"
  on public.lease_return_preparations
  for delete
  to authenticated
  using (
    user_id = auth.uid()
    and public.autoclair_user_owns_vehicle(vehicle_id)
  );
