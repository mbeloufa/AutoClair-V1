-- ============================================================================
-- AUTOCLAIR - BILAN 360 BACKEND V1
-- Migration additive et idempotente.
--
-- Prerequis :
--   public.vehicles
--   public.vehicle_market_valuations
--   public.vehicle_value_forecasts
--   public.vehicle_analysis_reports
--   public.vehicle_sale_scenarios
--   public.vehicle_report_sources
--
-- Cette migration :
--   1. controle le schema existant ;
--   2. complete les tables de bilan ;
--   3. ajoute la securite RLS ;
--   4. ajoute le socle d'entitlements et de credits ;
--   5. cree les RPC de snapshot, lecture et acces payant ;
--   6. ne cree aucune cote artificielle.
-- ============================================================================

begin;

create extension if not exists pgcrypto;
create schema if not exists private;

-- --------------------------------------------------------------------------
-- 1. PRECONTROLE
-- --------------------------------------------------------------------------

do $precheck$
declare
    v_table text;
    v_required_tables constant text[] := array[
        'vehicles',
        'vehicle_market_valuations',
        'vehicle_value_forecasts',
        'vehicle_analysis_reports',
        'vehicle_sale_scenarios',
        'vehicle_report_sources'
    ];
begin
    foreach v_table in array v_required_tables
    loop
        if to_regclass(format('public.%I', v_table)) is null then
            raise exception
                'Table requise absente : public.%. Executez d''abord le SQL de creation de cette table.',
                v_table;
        end if;
    end loop;

    if not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'vehicles'
          and column_name = 'id'
    ) then
        raise exception 'La table public.vehicles ne contient pas la colonne id.';
    end if;

    if not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'vehicles'
          and column_name = 'user_id'
    ) then
        raise exception 'La table public.vehicles ne contient pas la colonne user_id.';
    end if;
end;
$precheck$;

-- --------------------------------------------------------------------------
-- 2. COMPLEMENTS DE SCHEMA
-- --------------------------------------------------------------------------

alter table public.vehicle_analysis_reports
    add column if not exists request_key text,
    add column if not exists access_mode text,
    add column if not exists source_snapshot_hash text,
    add column if not exists updated_at timestamptz not null default now();

create unique index if not exists vehicle_analysis_reports_request_key_uq
    on public.vehicle_analysis_reports(user_id, request_key)
    where request_key is not null;

create index if not exists vehicle_analysis_reports_vehicle_status_idx
    on public.vehicle_analysis_reports(vehicle_id, status, requested_at desc);

create index if not exists vehicle_market_valuations_vehicle_date_idx
    on public.vehicle_market_valuations(vehicle_id, valuation_date desc);

create index if not exists vehicle_value_forecasts_vehicle_date_idx
    on public.vehicle_value_forecasts(vehicle_id, forecast_date, horizon_months);

create unique index if not exists vehicle_value_forecasts_natural_uq
    on public.vehicle_value_forecasts(
        vehicle_id,
        forecast_date,
        horizon_months,
        scenario,
        method
    );

create index if not exists vehicle_sale_scenarios_report_idx
    on public.vehicle_sale_scenarios(report_id);

create index if not exists vehicle_report_sources_report_idx
    on public.vehicle_report_sources(report_id);

-- Entitlements d'abonnement. Ecriture reservee au serveur.
create table if not exists public.user_entitlements (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    entitlement_code text not null,
    status text not null default 'active'
        check (status in ('active', 'inactive', 'expired', 'refunded')),
    source text not null default 'manual',
    external_reference text,
    starts_at timestamptz not null default now(),
    expires_at timestamptz,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, entitlement_code, source, external_reference)
);

create index if not exists user_entitlements_active_idx
    on public.user_entitlements(user_id, entitlement_code, status, expires_at);

-- Grand livre de credits. Le solde est la somme des delta.
create table if not exists public.vehicle_report_credit_events (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    report_id uuid references public.vehicle_analysis_reports(id) on delete set null,
    delta integer not null check (delta <> 0),
    event_type text not null
        check (event_type in (
            'grant',
            'consume',
            'release',
            'refund',
            'adjustment'
        )),
    source text not null default 'system',
    external_reference text unique,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create index if not exists vehicle_report_credit_events_user_idx
    on public.vehicle_report_credit_events(user_id, created_at desc);

-- --------------------------------------------------------------------------
-- 3. TRIGGERS DE PROPRIETE ET DE DATE
-- --------------------------------------------------------------------------

create or replace function private.force_vehicle_owner_user_id()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_owner uuid;
begin
    select v.user_id
    into v_owner
    from public.vehicles v
    where v.id = new.vehicle_id;

    if v_owner is null then
        raise exception 'Vehicule introuvable : %', new.vehicle_id;
    end if;

    new.user_id := v_owner;
    return new;
end;
$function$;

create or replace function private.force_report_owner_user_id()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_owner uuid;
begin
    select r.user_id
    into v_owner
    from public.vehicle_analysis_reports r
    where r.id = new.report_id;

    if v_owner is null then
        raise exception 'Rapport introuvable : %', new.report_id;
    end if;

    new.user_id := v_owner;
    return new;
end;
$function$;

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
    new.updated_at := now();
    return new;
end;
$function$;

drop trigger if exists trg_market_valuation_owner
on public.vehicle_market_valuations;
create trigger trg_market_valuation_owner
before insert or update of vehicle_id
on public.vehicle_market_valuations
for each row execute function private.force_vehicle_owner_user_id();

drop trigger if exists trg_value_forecast_owner
on public.vehicle_value_forecasts;
create trigger trg_value_forecast_owner
before insert or update of vehicle_id
on public.vehicle_value_forecasts
for each row execute function private.force_vehicle_owner_user_id();

drop trigger if exists trg_analysis_report_owner
on public.vehicle_analysis_reports;
create trigger trg_analysis_report_owner
before insert or update of vehicle_id
on public.vehicle_analysis_reports
for each row execute function private.force_vehicle_owner_user_id();

drop trigger if exists trg_sale_scenario_owner
on public.vehicle_sale_scenarios;
create trigger trg_sale_scenario_owner
before insert or update of report_id
on public.vehicle_sale_scenarios
for each row execute function private.force_report_owner_user_id();

drop trigger if exists trg_report_source_owner
on public.vehicle_report_sources;
create trigger trg_report_source_owner
before insert or update of report_id
on public.vehicle_report_sources
for each row execute function private.force_report_owner_user_id();

drop trigger if exists trg_analysis_reports_updated_at
on public.vehicle_analysis_reports;
create trigger trg_analysis_reports_updated_at
before update on public.vehicle_analysis_reports
for each row execute function private.set_updated_at();

drop trigger if exists trg_user_entitlements_updated_at
on public.user_entitlements;
create trigger trg_user_entitlements_updated_at
before update on public.user_entitlements
for each row execute function private.set_updated_at();

-- --------------------------------------------------------------------------
-- 4. RLS ET PRIVILEGES
-- --------------------------------------------------------------------------

alter table public.vehicle_market_valuations enable row level security;
alter table public.vehicle_value_forecasts enable row level security;
alter table public.vehicle_analysis_reports enable row level security;
alter table public.vehicle_sale_scenarios enable row level security;
alter table public.vehicle_report_sources enable row level security;
alter table public.user_entitlements enable row level security;
alter table public.vehicle_report_credit_events enable row level security;

drop policy if exists "read_own_vehicle_market_valuations"
on public.vehicle_market_valuations;
create policy "read_own_vehicle_market_valuations"
on public.vehicle_market_valuations
for select to authenticated
using (auth.uid() = user_id);

drop policy if exists "read_own_vehicle_value_forecasts"
on public.vehicle_value_forecasts;
create policy "read_own_vehicle_value_forecasts"
on public.vehicle_value_forecasts
for select to authenticated
using (auth.uid() = user_id);

drop policy if exists "read_own_vehicle_analysis_reports"
on public.vehicle_analysis_reports;
create policy "read_own_vehicle_analysis_reports"
on public.vehicle_analysis_reports
for select to authenticated
using (auth.uid() = user_id);

drop policy if exists "read_own_vehicle_sale_scenarios"
on public.vehicle_sale_scenarios;
create policy "read_own_vehicle_sale_scenarios"
on public.vehicle_sale_scenarios
for select to authenticated
using (auth.uid() = user_id);

drop policy if exists "read_own_vehicle_report_sources"
on public.vehicle_report_sources;
create policy "read_own_vehicle_report_sources"
on public.vehicle_report_sources
for select to authenticated
using (auth.uid() = user_id);

drop policy if exists "read_own_user_entitlements"
on public.user_entitlements;
create policy "read_own_user_entitlements"
on public.user_entitlements
for select to authenticated
using (auth.uid() = user_id);

drop policy if exists "read_own_vehicle_report_credit_events"
on public.vehicle_report_credit_events;
create policy "read_own_vehicle_report_credit_events"
on public.vehicle_report_credit_events
for select to authenticated
using (auth.uid() = user_id);

revoke all on table
    public.vehicle_market_valuations,
    public.vehicle_value_forecasts,
    public.vehicle_analysis_reports,
    public.vehicle_sale_scenarios,
    public.vehicle_report_sources,
    public.user_entitlements,
    public.vehicle_report_credit_events
from anon, authenticated;

grant select on table
    public.vehicle_market_valuations,
    public.vehicle_value_forecasts,
    public.vehicle_analysis_reports,
    public.vehicle_sale_scenarios,
    public.vehicle_report_sources,
    public.user_entitlements,
    public.vehicle_report_credit_events
to authenticated;

grant all on table
    public.vehicle_market_valuations,
    public.vehicle_value_forecasts,
    public.vehicle_analysis_reports,
    public.vehicle_sale_scenarios,
    public.vehicle_report_sources,
    public.user_entitlements,
    public.vehicle_report_credit_events
to service_role;

-- --------------------------------------------------------------------------
-- 5. COLLECTE SECURISEE DU DOSSIER VEHICULE
-- --------------------------------------------------------------------------

create or replace function private.collect_vehicle_rows(
    p_table_name text,
    p_vehicle_id uuid,
    p_limit integer default 250
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_allowed constant text[] := array[
        'vehicle_events',
        'vehicle_odometer_readings',
        'vehicle_expenses',
        'vehicle_maintenance_schedules',
        'vehicle_document_suggestions',
        'vehicle_recall_matches',
        'vehicle_risk_matches',
        'vehicle_warranties',
        'vehicle_advice',
        'vehicle_photos',
        'vehicle_condition_photos',
        'documents',
        'vehicle_market_valuations',
        'vehicle_value_forecasts'
    ];
    v_order_candidates constant text[] := array[
        'completed_at',
        'event_date',
        'recorded_at',
        'valuation_date',
        'forecast_date',
        'due_date',
        'document_date',
        'created_at',
        'updated_at'
    ];
    v_order_column text;
    v_order_sql text := '';
    v_sql text;
    v_result jsonb;
begin
    if not (p_table_name = any(v_allowed)) then
        raise exception 'Table non autorisee pour le snapshot : %', p_table_name;
    end if;

    if to_regclass(format('public.%I', p_table_name)) is null then
        return '[]'::jsonb;
    end if;

    if not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = p_table_name
          and column_name = 'vehicle_id'
    ) then
        return '[]'::jsonb;
    end if;

    select c.column_name
    into v_order_column
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = p_table_name
      and c.column_name = any(v_order_candidates)
    order by array_position(v_order_candidates, c.column_name)
    limit 1;

    if v_order_column is not null then
        v_order_sql := format(' order by %I desc nulls last ', v_order_column);
    end if;

    v_sql := format(
        $sql$
        select coalesce(
            jsonb_agg(
                jsonb_strip_nulls(
                    to_jsonb(q)
                    - 'user_id'
                    - 'raw_payload'
                    - 'input_snapshot'
                    - 'result_json'
                    - 'payment_reference'
                    - 'storage_path'
                    - 'file_path'
                    - 'file_url'
                    - 'signed_url'
                    - 'original_file_name'
                    - 'extracted_text'
                    - 'ocr_text'
                    - 'analysis_result'
                )
            ),
            '[]'::jsonb
        )
        from (
            select *
            from public.%I
            where vehicle_id = $1
            %s
            limit $2
        ) q
        $sql$,
        p_table_name,
        v_order_sql
    );

    execute v_sql
    using p_vehicle_id, greatest(1, least(coalesce(p_limit, 250), 500))
    into v_result;

    return coalesce(v_result, '[]'::jsonb);
end;
$function$;

create or replace function private.try_vehicle_rpc(
    p_function_name text,
    p_vehicle_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_allowed constant text[] := array[
        'get_vehicle_dashboard',
        'get_sale_package_data',
        'calculate_sale_timing_context'
    ];
    v_result jsonb;
begin
    if not (p_function_name = any(v_allowed)) then
        raise exception 'RPC non autorisee : %', p_function_name;
    end if;

    if to_regprocedure(format('public.%I(uuid)', p_function_name)) is null then
        return null;
    end if;

    begin
        execute format(
            'select coalesce(jsonb_agg(to_jsonb(r)), ''[]''::jsonb) from public.%I($1) r',
            p_function_name
        )
        using p_vehicle_id
        into v_result;

        return v_result;
    exception
        when others then
            return jsonb_build_object(
                'unavailable',
                true,
                'reason',
                'RPC presente mais non exploitable dans ce snapshot'
            );
    end;
end;
$function$;

create or replace function public.build_vehicle_analysis_snapshot(
    p_vehicle_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_user_id uuid := auth.uid();
    v_vehicle jsonb;
    v_datasets jsonb := '{}'::jsonb;
    v_derived jsonb := '{}'::jsonb;
    v_table text;
    v_rpc text;
    v_tables constant text[] := array[
        'vehicle_events',
        'vehicle_odometer_readings',
        'vehicle_expenses',
        'vehicle_maintenance_schedules',
        'vehicle_document_suggestions',
        'vehicle_recall_matches',
        'vehicle_risk_matches',
        'vehicle_warranties',
        'vehicle_advice',
        'vehicle_photos',
        'vehicle_condition_photos',
        'documents',
        'vehicle_market_valuations',
        'vehicle_value_forecasts'
    ];
    v_rpcs constant text[] := array[
        'get_vehicle_dashboard',
        'get_sale_package_data',
        'calculate_sale_timing_context'
    ];
begin
    if v_user_id is null then
        raise exception 'AUTHENTICATION_REQUIRED';
    end if;

    select jsonb_strip_nulls(
        to_jsonb(v)
        - 'user_id'
        - 'vin'
        - 'license_plate'
        - 'licence_plate'
        - 'registration_number'
        - 'registration'
        - 'created_by'
    )
    into v_vehicle
    from public.vehicles v
    where v.id = p_vehicle_id
      and v.user_id = v_user_id;

    if v_vehicle is null then
        raise exception 'VEHICLE_NOT_FOUND_OR_FORBIDDEN';
    end if;

    foreach v_table in array v_tables
    loop
        v_datasets := v_datasets || jsonb_build_object(
            v_table,
            private.collect_vehicle_rows(v_table, p_vehicle_id, 250)
        );
    end loop;

    foreach v_rpc in array v_rpcs
    loop
        v_derived := v_derived || jsonb_build_object(
            v_rpc,
            private.try_vehicle_rpc(v_rpc, p_vehicle_id)
        );
    end loop;

    return jsonb_build_object(
        'snapshot_version', 'vehicle-360-snapshot-1.0.0',
        'generated_at', now(),
        'vehicle_id', p_vehicle_id,
        'vehicle', v_vehicle,
        'datasets', v_datasets,
        'derived', v_derived,
        'source_policy', jsonb_build_object(
            'raw_documents_sent_to_ai', false,
            'raw_provider_payload_sent_to_ai', false,
            'direct_identifiers_removed', true
        )
    );
end;
$function$;

-- --------------------------------------------------------------------------
-- 6. LECTURE DES RAPPORTS ET DE LA COURBE
-- --------------------------------------------------------------------------

create or replace function public.get_vehicle_analysis_report(
    p_report_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_user_id uuid := auth.uid();
    v_report jsonb;
    v_scenarios jsonb;
    v_sources jsonb;
begin
    if v_user_id is null then
        raise exception 'AUTHENTICATION_REQUIRED';
    end if;

    select jsonb_strip_nulls(
        to_jsonb(r)
        - 'user_id'
        - 'input_snapshot'
        - 'payment_reference'
    )
    into v_report
    from public.vehicle_analysis_reports r
    where r.id = p_report_id
      and r.user_id = v_user_id;

    if v_report is null then
        return null;
    end if;

    select coalesce(
        jsonb_agg(to_jsonb(s) - 'user_id' order by s.scenario_code),
        '[]'::jsonb
    )
    into v_scenarios
    from public.vehicle_sale_scenarios s
    where s.report_id = p_report_id
      and s.user_id = v_user_id;

    select coalesce(
        jsonb_agg(to_jsonb(s) - 'user_id' order by s.source_type, s.source_label),
        '[]'::jsonb
    )
    into v_sources
    from public.vehicle_report_sources s
    where s.report_id = p_report_id
      and s.user_id = v_user_id;

    return jsonb_build_object(
        'report', v_report,
        'scenarios', v_scenarios,
        'sources', v_sources
    );
end;
$function$;

create or replace function public.get_latest_vehicle_analysis_report(
    p_vehicle_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_user_id uuid := auth.uid();
    v_report_id uuid;
begin
    if v_user_id is null then
        raise exception 'AUTHENTICATION_REQUIRED';
    end if;

    if not exists (
        select 1
        from public.vehicles v
        where v.id = p_vehicle_id
          and v.user_id = v_user_id
    ) then
        raise exception 'VEHICLE_NOT_FOUND_OR_FORBIDDEN';
    end if;

    select r.id
    into v_report_id
    from public.vehicle_analysis_reports r
    where r.vehicle_id = p_vehicle_id
      and r.user_id = v_user_id
      and r.status = 'completed'
    order by r.completed_at desc nulls last, r.requested_at desc
    limit 1;

    if v_report_id is null then
        return null;
    end if;

    return public.get_vehicle_analysis_report(v_report_id);
end;
$function$;

create or replace function public.get_vehicle_value_history(
    p_vehicle_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_user_id uuid := auth.uid();
    v_valuations jsonb;
    v_forecasts jsonb;
begin
    if v_user_id is null then
        raise exception 'AUTHENTICATION_REQUIRED';
    end if;

    if not exists (
        select 1
        from public.vehicles v
        where v.id = p_vehicle_id
          and v.user_id = v_user_id
    ) then
        raise exception 'VEHICLE_NOT_FOUND_OR_FORBIDDEN';
    end if;

    select coalesce(
        jsonb_agg(
            jsonb_strip_nulls(
                to_jsonb(v)
                - 'user_id'
                - 'raw_payload'
            )
            order by v.valuation_date asc, v.valuation_type
        ),
        '[]'::jsonb
    )
    into v_valuations
    from public.vehicle_market_valuations v
    where v.vehicle_id = p_vehicle_id
      and v.user_id = v_user_id;

    select coalesce(
        jsonb_agg(
            to_jsonb(f) - 'user_id'
            order by f.forecast_date asc, f.horizon_months, f.scenario
        ),
        '[]'::jsonb
    )
    into v_forecasts
    from public.vehicle_value_forecasts f
    where f.vehicle_id = p_vehicle_id
      and f.user_id = v_user_id;

    return jsonb_build_object(
        'vehicle_id', p_vehicle_id,
        'valuations', v_valuations,
        'forecasts', v_forecasts
    );
end;
$function$;

-- --------------------------------------------------------------------------
-- 7. ACCES PREMIUM ET CREDITS
-- --------------------------------------------------------------------------

create or replace function private.vehicle_report_credit_balance(
    p_user_id uuid
)
returns integer
language sql
stable
security definer
set search_path = ''
as $function$
    select coalesce(sum(e.delta), 0)::integer
    from public.vehicle_report_credit_events e
    where e.user_id = p_user_id;
$function$;

create or replace function private.has_active_vehicle_360_entitlement(
    p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
    select exists (
        select 1
        from public.user_entitlements e
        where e.user_id = p_user_id
          and e.entitlement_code = 'vehicle_360'
          and e.status = 'active'
          and e.starts_at <= now()
          and (e.expires_at is null or e.expires_at > now())
    );
$function$;

create or replace function public.get_vehicle_report_access()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $function$
    select case
        when auth.uid() is null then
            jsonb_build_object('authenticated', false)
        else
            jsonb_build_object(
                'authenticated', true,
                'entitled', private.has_active_vehicle_360_entitlement(auth.uid()),
                'credit_balance', private.vehicle_report_credit_balance(auth.uid())
            )
    end;
$function$;

create or replace function private.reserve_vehicle_report_access(
    p_user_id uuid,
    p_report_id uuid,
    p_billing_mode text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_mode text := lower(coalesce(trim(p_billing_mode), 'blocked'));
    v_balance integer;
    v_reference text := 'report:' || p_report_id::text || ':consume';
begin
    perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));

    if v_mode = 'pilot' then
        return jsonb_build_object(
            'granted', true,
            'access_type', 'pilot',
            'credit_consumed', false
        );
    end if;

    if v_mode = 'blocked' then
        return jsonb_build_object(
            'granted', false,
            'reason', 'PAYWALL_REQUIRED'
        );
    end if;

    if v_mode <> 'credits' then
        return jsonb_build_object(
            'granted', false,
            'reason', 'INVALID_BILLING_MODE'
        );
    end if;

    if private.has_active_vehicle_360_entitlement(p_user_id) then
        return jsonb_build_object(
            'granted', true,
            'access_type', 'subscription',
            'credit_consumed', false
        );
    end if;

    if exists (
        select 1
        from public.vehicle_report_credit_events e
        where e.external_reference = v_reference
          and e.user_id = p_user_id
    ) then
        return jsonb_build_object(
            'granted', true,
            'access_type', 'credit',
            'credit_consumed', true,
            'idempotent', true
        );
    end if;

    v_balance := private.vehicle_report_credit_balance(p_user_id);

    if v_balance < 1 then
        return jsonb_build_object(
            'granted', false,
            'reason', 'NO_REPORT_CREDIT',
            'credit_balance', v_balance
        );
    end if;

    insert into public.vehicle_report_credit_events (
        user_id,
        report_id,
        delta,
        event_type,
        source,
        external_reference,
        metadata
    )
    values (
        p_user_id,
        p_report_id,
        -1,
        'consume',
        'vehicle_360',
        v_reference,
        jsonb_build_object('billing_mode', v_mode)
    );

    return jsonb_build_object(
        'granted', true,
        'access_type', 'credit',
        'credit_consumed', true,
        'credit_balance_after', v_balance - 1
    );
end;
$function$;

create or replace function private.release_vehicle_report_access(
    p_user_id uuid,
    p_report_id uuid,
    p_reason text default 'generation_failed'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_consume_reference text := 'report:' || p_report_id::text || ':consume';
    v_release_reference text := 'report:' || p_report_id::text || ':release';
begin
    perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));

    if not exists (
        select 1
        from public.vehicle_report_credit_events e
        where e.user_id = p_user_id
          and e.external_reference = v_consume_reference
          and e.delta = -1
    ) then
        return jsonb_build_object('released', false, 'reason', 'NO_CONSUMED_CREDIT');
    end if;

    if exists (
        select 1
        from public.vehicle_report_credit_events e
        where e.user_id = p_user_id
          and e.external_reference = v_release_reference
    ) then
        return jsonb_build_object('released', true, 'idempotent', true);
    end if;

    insert into public.vehicle_report_credit_events (
        user_id,
        report_id,
        delta,
        event_type,
        source,
        external_reference,
        metadata
    )
    values (
        p_user_id,
        p_report_id,
        1,
        'release',
        'vehicle_360',
        v_release_reference,
        jsonb_build_object('reason', coalesce(p_reason, 'generation_failed'))
    );

    return jsonb_build_object('released', true, 'idempotent', false);
end;
$function$;

create or replace function private.grant_vehicle_report_credits(
    p_user_id uuid,
    p_quantity integer,
    p_external_reference text,
    p_source text default 'billing',
    p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
begin
    if p_quantity is null or p_quantity <= 0 then
        raise exception 'La quantite de credits doit etre strictement positive.';
    end if;

    insert into public.vehicle_report_credit_events (
        user_id,
        delta,
        event_type,
        source,
        external_reference,
        metadata
    )
    values (
        p_user_id,
        p_quantity,
        'grant',
        coalesce(nullif(trim(p_source), ''), 'billing'),
        p_external_reference,
        coalesce(p_metadata, '{}'::jsonb)
    )
    on conflict (external_reference) do nothing;

    return jsonb_build_object(
        'success', true,
        'credit_balance', private.vehicle_report_credit_balance(p_user_id)
    );
end;
$function$;

create or replace function private.upsert_vehicle_360_entitlement(
    p_user_id uuid,
    p_status text,
    p_source text,
    p_external_reference text,
    p_starts_at timestamptz default now(),
    p_expires_at timestamptz default null,
    p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_id uuid;
begin
    insert into public.user_entitlements (
        user_id,
        entitlement_code,
        status,
        source,
        external_reference,
        starts_at,
        expires_at,
        metadata
    )
    values (
        p_user_id,
        'vehicle_360',
        p_status,
        p_source,
        p_external_reference,
        coalesce(p_starts_at, now()),
        p_expires_at,
        coalesce(p_metadata, '{}'::jsonb)
    )
    on conflict (user_id, entitlement_code, source, external_reference)
    do update set
        status = excluded.status,
        starts_at = excluded.starts_at,
        expires_at = excluded.expires_at,
        metadata = excluded.metadata,
        updated_at = now()
    returning id into v_id;

    return jsonb_build_object('success', true, 'entitlement_id', v_id);
end;
$function$;


-- --------------------------------------------------------------------------
-- 8. WRAPPERS RPC SERVEUR EXPOSES A POSTGREST
-- --------------------------------------------------------------------------
-- Le schema private n'est pas expose par l'API Supabase. Ces wrappers publics
-- sont donc necessaires aux Edge Functions. Leur execution reste reservee au
-- role service_role.

create or replace function public.reserve_vehicle_report_access(
    p_user_id uuid,
    p_report_id uuid,
    p_billing_mode text
)
returns jsonb
language sql
security definer
set search_path = ''
as $function$
    select private.reserve_vehicle_report_access(
        p_user_id,
        p_report_id,
        p_billing_mode
    );
$function$;

create or replace function public.release_vehicle_report_access(
    p_user_id uuid,
    p_report_id uuid,
    p_reason text default 'generation_failed'
)
returns jsonb
language sql
security definer
set search_path = ''
as $function$
    select private.release_vehicle_report_access(
        p_user_id,
        p_report_id,
        p_reason
    );
$function$;

create or replace function public.grant_vehicle_report_credits(
    p_user_id uuid,
    p_quantity integer,
    p_external_reference text,
    p_source text default 'billing',
    p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language sql
security definer
set search_path = ''
as $function$
    select private.grant_vehicle_report_credits(
        p_user_id,
        p_quantity,
        p_external_reference,
        p_source,
        p_metadata
    );
$function$;

create or replace function public.upsert_vehicle_360_entitlement(
    p_user_id uuid,
    p_status text,
    p_source text,
    p_external_reference text,
    p_starts_at timestamptz default now(),
    p_expires_at timestamptz default null,
    p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language sql
security definer
set search_path = ''
as $function$
    select private.upsert_vehicle_360_entitlement(
        p_user_id,
        p_status,
        p_source,
        p_external_reference,
        p_starts_at,
        p_expires_at,
        p_metadata
    );
$function$;

-- --------------------------------------------------------------------------
-- 9. PRIVILEGES DES FONCTIONS
-- --------------------------------------------------------------------------

revoke all on function private.force_vehicle_owner_user_id() from public;
revoke all on function private.force_report_owner_user_id() from public;
revoke all on function private.collect_vehicle_rows(text, uuid, integer) from public;
revoke all on function private.try_vehicle_rpc(text, uuid) from public;
revoke all on function private.vehicle_report_credit_balance(uuid) from public;
revoke all on function private.has_active_vehicle_360_entitlement(uuid) from public;
revoke all on function private.reserve_vehicle_report_access(uuid, uuid, text) from public;
revoke all on function private.release_vehicle_report_access(uuid, uuid, text) from public;
revoke all on function private.grant_vehicle_report_credits(uuid, integer, text, text, jsonb) from public;
revoke all on function private.upsert_vehicle_360_entitlement(uuid, text, text, text, timestamptz, timestamptz, jsonb) from public;

grant execute on function public.build_vehicle_analysis_snapshot(uuid)
to authenticated;

grant execute on function public.get_vehicle_analysis_report(uuid)
to authenticated;

grant execute on function public.get_latest_vehicle_analysis_report(uuid)
to authenticated;

grant execute on function public.get_vehicle_value_history(uuid)
to authenticated;

grant execute on function public.get_vehicle_report_access()
to authenticated;

revoke all on function public.reserve_vehicle_report_access(uuid, uuid, text)
from public, anon, authenticated;

revoke all on function public.release_vehicle_report_access(uuid, uuid, text)
from public, anon, authenticated;

revoke all on function public.grant_vehicle_report_credits(uuid, integer, text, text, jsonb)
from public, anon, authenticated;

revoke all on function public.upsert_vehicle_360_entitlement(uuid, text, text, text, timestamptz, timestamptz, jsonb)
from public, anon, authenticated;

grant execute on function public.reserve_vehicle_report_access(uuid, uuid, text)
to service_role;

grant execute on function public.release_vehicle_report_access(uuid, uuid, text)
to service_role;

grant execute on function public.grant_vehicle_report_credits(uuid, integer, text, text, jsonb)
to service_role;

grant execute on function public.upsert_vehicle_360_entitlement(uuid, text, text, text, timestamptz, timestamptz, jsonb)
to service_role;

commit;
