begin;

create table if not exists public.vehicle_maintenance_planner_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  vehicle_id uuid not null
    references public.vehicles(id) on delete cascade,
  annual_mileage_km integer not null default 12000
    check (annual_mileage_km between 1000 and 100000),
  budget_buffer_percent numeric(5,2) not null default 10
    check (budget_buffer_percent between 0 and 50),
  reminder_days_before integer not null default 30
    check (reminder_days_before in (1, 3, 7, 14, 30)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (vehicle_id)
);

alter table public.vehicle_maintenance_planner_profiles
  enable row level security;

drop policy if exists maintenance_planner_owner_select
  on public.vehicle_maintenance_planner_profiles;
create policy maintenance_planner_owner_select
on public.vehicle_maintenance_planner_profiles
for select to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists maintenance_planner_owner_insert
  on public.vehicle_maintenance_planner_profiles;
create policy maintenance_planner_owner_insert
on public.vehicle_maintenance_planner_profiles
for insert to authenticated
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists maintenance_planner_owner_update
  on public.vehicle_maintenance_planner_profiles;
create policy maintenance_planner_owner_update
on public.vehicle_maintenance_planner_profiles
for update to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
)
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists maintenance_planner_owner_delete
  on public.vehicle_maintenance_planner_profiles;
create policy maintenance_planner_owner_delete
on public.vehicle_maintenance_planner_profiles
for delete to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop trigger if exists maintenance_planner_set_updated_at
  on public.vehicle_maintenance_planner_profiles;
create trigger maintenance_planner_set_updated_at
before update on public.vehicle_maintenance_planner_profiles
for each row execute function public.autoclair_set_updated_at();

grant select, insert, update, delete
on public.vehicle_maintenance_planner_profiles
to authenticated;

commit;
