begin;

create or replace function public.autoclair_set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.autoclair_user_owns_vehicle(
  p_vehicle_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.vehicles v
    where v.id = p_vehicle_id
      and v.user_id = auth.uid()
  );
$$;

revoke all on function public.autoclair_user_owns_vehicle(uuid) from public;
grant execute on function public.autoclair_user_owns_vehicle(uuid) to authenticated;

create table if not exists public.vehicle_financial_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  consumption_l_per_100km numeric(6,2) not null default 6.50
    check (consumption_l_per_100km > 0 and consumption_l_per_100km <= 40),
  usual_fill_liters numeric(6,2) not null default 40
    check (usual_fill_liters > 0 and usual_fill_liters <= 200),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (vehicle_id)
);

create table if not exists public.vehicle_cost_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  category text not null check (category in (
    'FUEL','CHARGING','MAINTENANCE','REPAIR','INSURANCE',
    'TECHNICAL_CONTROL','PARKING','TOLL','ACCESSORIES','OTHER'
  )),
  subcategory text not null check (char_length(trim(subcategory)) between 1 and 160),
  amount numeric(12,2) not null check (amount >= 0),
  currency text not null default 'EUR' check (currency = 'EUR'),
  event_date date not null,
  mileage_km integer check (mileage_km is null or mileage_km >= 0),
  source_type text not null default 'MANUAL',
  source_reference text,
  source_document_id uuid,
  source_event_id uuid,
  note text check (note is null or char_length(note) <= 1000),
  is_recurring boolean not null default false,
  recurrence_months integer check (
    recurrence_months is null or recurrence_months between 1 and 120
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.vehicle_usage_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  mileage_km integer not null check (mileage_km >= 0),
  snapshot_date date not null,
  source_type text not null default 'MANUAL',
  created_at timestamptz not null default now(),
  unique (vehicle_id, snapshot_date)
);

create table if not exists public.saving_opportunities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  feature_code text not null check (feature_code in (
    'FUEL_OPTIMIZER','QUOTE_COMPARISON','INSURANCE_REVIEW',
    'CHARGING_OPTIMIZER','OTHER'
  )),
  baseline_amount numeric(12,2) not null check (baseline_amount >= 0),
  proposed_amount numeric(12,2) not null check (proposed_amount >= 0),
  potential_saving numeric(12,2) not null check (potential_saving > 0),
  calculation_details jsonb not null default '{}'::jsonb,
  confidence_level text not null default 'MEDIUM'
    check (confidence_level in ('LOW','MEDIUM','HIGH')),
  status text not null default 'DETECTED'
    check (status in ('DETECTED','ACCEPTED','CONFIRMED','REJECTED','EXPIRED')),
  source_reference text,
  expires_at timestamptz,
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (abs((baseline_amount - proposed_amount) - potential_saving) <= 0.02),
  check (status <> 'CONFIRMED' or confirmed_at is not null)
);

create table if not exists public.vehicle_compliance_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  item_type text not null check (item_type in (
    'TECHNICAL_CONTROL','INSURANCE','RECALL','MAINTENANCE',
    'DOCUMENT','ZFE','OTHER'
  )),
  title text not null check (char_length(trim(title)) between 1 and 180),
  message text check (message is null or char_length(message) <= 2000),
  status text not null default 'ACTIVE'
    check (status in ('ACTIVE','COMPLETED','DISMISSED')),
  priority text not null default 'MEDIUM'
    check (priority in ('LOW','MEDIUM','HIGH','CRITICAL')),
  source_type text not null default 'MANUAL',
  source_reference text,
  source_url text,
  confidence numeric(5,4) check (confidence is null or confidence between 0 and 1),
  due_date date,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.quote_comparisons (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  reference_document_id uuid not null,
  chosen_document_id uuid not null,
  reference_total numeric(12,2) not null check (reference_total >= 0),
  chosen_total numeric(12,2) not null check (chosen_total >= 0),
  saving_amount numeric(12,2) not null check (saving_amount > 0),
  comparison_json jsonb not null default '{}'::jsonb,
  status text not null default 'CONFIRMED'
    check (status in ('DRAFT','CONFIRMED','CANCELLED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (reference_document_id <> chosen_document_id),
  check (abs((reference_total - chosen_total) - saving_amount) <= 0.02)
);

create table if not exists public.insurance_contract_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  provider_name text not null check (char_length(trim(provider_name)) between 1 and 180),
  annual_premium numeric(12,2) not null check (annual_premium >= 0),
  deductible_amount numeric(12,2) check (
    deductible_amount is null or deductible_amount >= 0
  ),
  snapshot_date date not null,
  expiry_date date,
  assistance_zero_km boolean,
  replacement_vehicle boolean,
  contract_number_masked text check (
    contract_number_masked is null or char_length(contract_number_masked) <= 80
  ),
  document_id uuid,
  source_type text not null default 'MANUAL',
  guarantees jsonb not null default '[]'::jsonb
    check (jsonb_typeof(guarantees) = 'array'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  purpose_code text not null,
  granted boolean not null,
  policy_version text not null,
  granted_at timestamptz,
  revoked_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, purpose_code)
);

create unique index if not exists vehicle_cost_entries_source_unique
on public.vehicle_cost_entries(user_id, source_type, source_reference)
where source_reference is not null;

create unique index if not exists saving_opportunities_source_unique
on public.saving_opportunities(user_id, feature_code, source_reference)
where source_reference is not null;

create index if not exists vehicle_cost_entries_vehicle_date_idx
on public.vehicle_cost_entries(vehicle_id, event_date desc);

create index if not exists saving_opportunities_vehicle_status_idx
on public.saving_opportunities(vehicle_id, status, created_at desc);

create index if not exists vehicle_compliance_items_vehicle_due_idx
on public.vehicle_compliance_items(vehicle_id, status, due_date);

create index if not exists insurance_snapshots_vehicle_date_idx
on public.insurance_contract_snapshots(vehicle_id, snapshot_date desc);

alter table public.vehicle_financial_profiles enable row level security;
alter table public.vehicle_cost_entries enable row level security;
alter table public.vehicle_usage_snapshots enable row level security;
alter table public.saving_opportunities enable row level security;
alter table public.vehicle_compliance_items enable row level security;
alter table public.quote_comparisons enable row level security;
alter table public.insurance_contract_snapshots enable row level security;
alter table public.user_consents enable row level security;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'vehicle_financial_profiles',
    'vehicle_cost_entries',
    'vehicle_usage_snapshots',
    'saving_opportunities',
    'vehicle_compliance_items',
    'quote_comparisons',
    'insurance_contract_snapshots'
  ]
  loop
    execute format('drop policy if exists %I_owner_select on public.%I', table_name, table_name);
    execute format(
      'create policy %I_owner_select on public.%I for select to authenticated '
      'using (user_id = auth.uid() and public.autoclair_user_owns_vehicle(vehicle_id))',
      table_name,
      table_name
    );

    execute format('drop policy if exists %I_owner_insert on public.%I', table_name, table_name);
    execute format(
      'create policy %I_owner_insert on public.%I for insert to authenticated '
      'with check (user_id = auth.uid() and public.autoclair_user_owns_vehicle(vehicle_id))',
      table_name,
      table_name
    );

    execute format('drop policy if exists %I_owner_update on public.%I', table_name, table_name);
    execute format(
      'create policy %I_owner_update on public.%I for update to authenticated '
      'using (user_id = auth.uid() and public.autoclair_user_owns_vehicle(vehicle_id)) '
      'with check (user_id = auth.uid() and public.autoclair_user_owns_vehicle(vehicle_id))',
      table_name,
      table_name
    );

    execute format('drop policy if exists %I_owner_delete on public.%I', table_name, table_name);
    execute format(
      'create policy %I_owner_delete on public.%I for delete to authenticated '
      'using (user_id = auth.uid() and public.autoclair_user_owns_vehicle(vehicle_id))',
      table_name,
      table_name
    );
  end loop;
end;
$$;

drop policy if exists user_consents_owner_select on public.user_consents;
create policy user_consents_owner_select
on public.user_consents for select to authenticated
using (user_id = auth.uid());

drop policy if exists user_consents_owner_insert on public.user_consents;
create policy user_consents_owner_insert
on public.user_consents for insert to authenticated
with check (user_id = auth.uid());

drop policy if exists user_consents_owner_update on public.user_consents;
create policy user_consents_owner_update
on public.user_consents for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists user_consents_owner_delete on public.user_consents;
create policy user_consents_owner_delete
on public.user_consents for delete to authenticated
using (user_id = auth.uid());

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'vehicle_financial_profiles',
    'vehicle_cost_entries',
    'saving_opportunities',
    'vehicle_compliance_items',
    'quote_comparisons',
    'insurance_contract_snapshots',
    'user_consents'
  ]
  loop
    execute format(
      'drop trigger if exists %I_set_updated_at on public.%I',
      table_name,
      table_name
    );
    execute format(
      'create trigger %I_set_updated_at before update on public.%I '
      'for each row execute function public.autoclair_set_updated_at()',
      table_name,
      table_name
    );
  end loop;
end;
$$;

grant select, insert, update, delete on public.vehicle_financial_profiles to authenticated;
grant select, insert, update, delete on public.vehicle_cost_entries to authenticated;
grant select, insert, update, delete on public.vehicle_usage_snapshots to authenticated;
grant select, insert, update, delete on public.saving_opportunities to authenticated;
grant select, insert, update, delete on public.vehicle_compliance_items to authenticated;
grant select, insert, update, delete on public.quote_comparisons to authenticated;
grant select, insert, update, delete on public.insurance_contract_snapshots to authenticated;
grant select, insert, update, delete on public.user_consents to authenticated;

commit;
