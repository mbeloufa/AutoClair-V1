begin;

create table if not exists public.workshop_visit_preparations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  planned_date date not null,
  visit_reason text not null check (
    visit_reason in (
      'ROUTINE_MAINTENANCE', 'WARNING_LIGHT', 'NOISE_OR_VIBRATION',
      'LEAK_OR_ODOR', 'BRAKING_OR_STEERING', 'ELECTRICAL_OR_CLIMATE',
      'BODYWORK', 'RECALL_OR_CAMPAIGN'
    )
  ),
  preparation_score integer not null check (preparation_score between 0 and 100),
  preparation_level text not null check (
    preparation_level in ('READY', 'REVIEW', 'ACTION', 'URGENT')
  ),
  completeness_percent integer not null check (
    completeness_percent between 0 and 100
  ),
  urgent_count integer not null default 0 check (urgent_count between 0 and 20),
  vehicle_can_move_safely boolean not null default true,
  warning_light_on boolean not null default false,
  checks jsonb not null default '{}'::jsonb check (jsonb_typeof(checks) = 'object'),
  findings jsonb not null default '[]'::jsonb check (jsonb_typeof(findings) = 'array'),
  calculator_version text not null default 'workshop-visit-preparation-v1'
    check (char_length(calculator_version) between 1 and 60),
  created_at timestamptz not null default now()
);

create index if not exists workshop_visit_vehicle_created_idx
  on public.workshop_visit_preparations (vehicle_id, created_at desc);
create index if not exists workshop_visit_user_created_idx
  on public.workshop_visit_preparations (user_id, created_at desc);

alter table public.workshop_visit_preparations enable row level security;

create policy workshop_visit_select_own
on public.workshop_visit_preparations for select
to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

create policy workshop_visit_insert_own
on public.workshop_visit_preparations for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

create policy workshop_visit_delete_own
on public.workshop_visit_preparations for delete
to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

commit;
