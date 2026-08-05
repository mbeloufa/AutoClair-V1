begin;

create table if not exists public.vehicle_charging_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  vehicle_id uuid not null
    references public.vehicles(id) on delete cascade,
  consumption_kwh_per_100km numeric(6,2) not null default 18
    check (
      consumption_kwh_per_100km > 0
      and consumption_kwh_per_100km <= 100
    ),
  usual_charge_kwh numeric(7,2) not null default 40
    check (usual_charge_kwh > 0 and usual_charge_kwh <= 300),
  reference_price_per_kwh numeric(7,4) not null default 0.45
    check (
      reference_price_per_kwh >= 0
      and reference_price_per_kwh <= 5
    ),
  max_charging_power_kw numeric(7,2) not null default 100
    check (
      max_charging_power_kw > 0
      and max_charging_power_kw <= 500
    ),
  battery_capacity_kwh numeric(7,2)
    check (
      battery_capacity_kwh is null
      or (
        battery_capacity_kwh > 0
        and battery_capacity_kwh <= 300
      )
    ),
  connector text not null default 'any'
    check (connector in ('any','type2','ccs','chademo','ef','other')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (vehicle_id)
);

alter table public.vehicle_charging_profiles enable row level security;

drop policy if exists vehicle_charging_profiles_owner_select
on public.vehicle_charging_profiles;
create policy vehicle_charging_profiles_owner_select
on public.vehicle_charging_profiles
for select to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_charging_profiles_owner_insert
on public.vehicle_charging_profiles;
create policy vehicle_charging_profiles_owner_insert
on public.vehicle_charging_profiles
for insert to authenticated
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_charging_profiles_owner_update
on public.vehicle_charging_profiles;
create policy vehicle_charging_profiles_owner_update
on public.vehicle_charging_profiles
for update to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
)
with check (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop policy if exists vehicle_charging_profiles_owner_delete
on public.vehicle_charging_profiles;
create policy vehicle_charging_profiles_owner_delete
on public.vehicle_charging_profiles
for delete to authenticated
using (
  user_id = auth.uid()
  and public.autoclair_user_owns_vehicle(vehicle_id)
);

drop trigger if exists vehicle_charging_profiles_set_updated_at
on public.vehicle_charging_profiles;
create trigger vehicle_charging_profiles_set_updated_at
before update on public.vehicle_charging_profiles
for each row execute function public.autoclair_set_updated_at();

grant select, insert, update, delete
on public.vehicle_charging_profiles to authenticated;

commit;
