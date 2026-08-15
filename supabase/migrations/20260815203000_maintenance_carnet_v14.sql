alter table public.vehicle_maintenance_planner_profiles
  add column if not exists reminders_enabled boolean not null default false;

create table if not exists public.vehicle_maintenance_reminder_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  reminder_key text not null,
  enabled boolean not null default true,
  frequency_months integer,
  preferred_month smallint,
  lead_days smallint[] not null default array[14,0]::smallint[],
  last_completed_at date,
  last_completed_mileage integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vehicle_maintenance_reminder_preferences_key_length
    check (char_length(reminder_key) between 3 and 120),
  constraint vehicle_maintenance_reminder_preferences_frequency
    check (frequency_months is null or frequency_months between 1 and 60),
  constraint vehicle_maintenance_reminder_preferences_month
    check (preferred_month is null or preferred_month between 1 and 12),
  constraint vehicle_maintenance_reminder_preferences_lead_days
    check (
      cardinality(lead_days) between 1 and 3
      and lead_days <@ array[0,1,3,7,14,30,60]::smallint[]
    ),
  constraint vehicle_maintenance_reminder_preferences_last_mileage
    check (last_completed_mileage is null or last_completed_mileage >= 0),
  constraint vehicle_maintenance_reminder_preferences_unique
    unique (user_id, vehicle_id, reminder_key)
);

create index if not exists vehicle_maintenance_reminder_preferences_vehicle_idx
  on public.vehicle_maintenance_reminder_preferences(user_id, vehicle_id);

alter table public.vehicle_maintenance_reminder_preferences enable row level security;

drop policy if exists maintenance_reminder_preferences_owner_select
  on public.vehicle_maintenance_reminder_preferences;
create policy maintenance_reminder_preferences_owner_select
  on public.vehicle_maintenance_reminder_preferences
  for select to authenticated
  using (
    user_id = auth.uid()
    and public.autoclair_user_owns_vehicle(vehicle_id)
  );

drop policy if exists maintenance_reminder_preferences_owner_insert
  on public.vehicle_maintenance_reminder_preferences;
create policy maintenance_reminder_preferences_owner_insert
  on public.vehicle_maintenance_reminder_preferences
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and public.autoclair_user_owns_vehicle(vehicle_id)
  );

drop policy if exists maintenance_reminder_preferences_owner_update
  on public.vehicle_maintenance_reminder_preferences;
create policy maintenance_reminder_preferences_owner_update
  on public.vehicle_maintenance_reminder_preferences
  for update to authenticated
  using (
    user_id = auth.uid()
    and public.autoclair_user_owns_vehicle(vehicle_id)
  )
  with check (
    user_id = auth.uid()
    and public.autoclair_user_owns_vehicle(vehicle_id)
  );

drop policy if exists maintenance_reminder_preferences_owner_delete
  on public.vehicle_maintenance_reminder_preferences;
create policy maintenance_reminder_preferences_owner_delete
  on public.vehicle_maintenance_reminder_preferences
  for delete to authenticated
  using (
    user_id = auth.uid()
    and public.autoclair_user_owns_vehicle(vehicle_id)
  );

revoke all on table public.vehicle_maintenance_reminder_preferences
  from public, anon;
grant select, insert, update, delete
  on table public.vehicle_maintenance_reminder_preferences
  to authenticated;

comment on table public.vehicle_maintenance_reminder_preferences is
  'Préférences durables des rappels du Carnet d’entretien AutoClair V14.';
comment on column public.vehicle_maintenance_planner_profiles.reminders_enabled is
  'Interrupteur général des rappels d’entretien, synchronisé par véhicule.';
