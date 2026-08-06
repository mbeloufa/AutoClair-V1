begin;

alter table if exists public.commercial_offers
  add column if not exists is_featured boolean not null default false,
  add column if not exists match_level text not null default 'TO_CHECK',
  add column if not exists match_confidence numeric(5,4) not null default 0,
  add column if not exists is_brand_fallback boolean not null default false,
  add column if not exists last_verified_at timestamptz,
  add column if not exists v4_source_key text;

create index if not exists commercial_offers_v4_brand_fallback_idx
  on public.commercial_offers (is_brand_fallback, status, last_verified_at desc);
create index if not exists commercial_offers_v4_source_key_idx
  on public.commercial_offers (v4_source_key);

create table if not exists public.commercial_offer_v4_runs (
  id uuid primary key default gen_random_uuid(),
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null check (status in ('RUNNING','SUCCESS','FAILED')),
  mode text not null default 'scheduled',
  sources_total integer not null default 0,
  sources_processed integer not null default 0,
  pages_ok integer not null default 0,
  pages_failed integer not null default 0,
  candidates_found integer not null default 0,
  offers_published integer not null default 0,
  fallbacks_published integer not null default 0,
  brands_covered integer not null default 0,
  message text,
  details jsonb not null default '{}'::jsonb
);

create table if not exists public.commercial_offer_v4_source_health (
  source_key text primary key,
  official_url text not null,
  brand text not null,
  last_attempt_at timestamptz,
  last_success_at timestamptz,
  last_http_status integer,
  consecutive_failures integer not null default 0,
  last_error text,
  last_content_hash text,
  discovered_offer_count integer not null default 0,
  published_offer_count integer not null default 0,
  next_retry_at timestamptz,
  updated_at timestamptz not null default now()
);

create index if not exists commercial_offer_v4_source_due_idx
  on public.commercial_offer_v4_source_health (next_retry_at, last_success_at, consecutive_failures);
create index if not exists commercial_offer_v4_source_brand_idx
  on public.commercial_offer_v4_source_health (brand);

create table if not exists public.commercial_offer_v4_candidates (
  id uuid primary key default gen_random_uuid(),
  source_key text not null,
  official_url text not null,
  brand text not null,
  offer_key text not null,
  title text not null,
  summary text not null,
  category text not null,
  benefit_kind text not null,
  benefit_label text not null,
  benefit_value numeric,
  price_amount numeric,
  starts_at date,
  ends_at date,
  model_patterns text[] not null default '{}'::text[],
  excluded_model_patterns text[] not null default '{}'::text[],
  fuel_types text[] not null default '{}'::text[],
  excluded_fuel_types text[] not null default '{}'::text[],
  year_min integer,
  year_max integer,
  age_min integer,
  age_max integer,
  mileage_min integer,
  mileage_max integer,
  conditions_summary text not null,
  eligibility_notes text not null,
  requires_existing_contract boolean not null default false,
  requires_network_participation boolean not null default false,
  requires_manual_eligibility boolean not null default true,
  validation_markers text[] not null default '{}'::text[],
  confidence numeric(5,4) not null default 0,
  state text not null check (state in ('TO_CHECK','PUBLISHABLE','PUBLISHED','REJECTED')),
  raw_excerpt text,
  content_hash text not null,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  published_offer_id uuid references public.commercial_offers(id) on delete set null,
  unique (source_key, offer_key)
);

create index if not exists commercial_offer_v4_candidates_state_idx
  on public.commercial_offer_v4_candidates (state, confidence desc, last_seen_at desc);
create index if not exists commercial_offer_v4_candidates_brand_idx
  on public.commercial_offer_v4_candidates (brand, state);

alter table public.commercial_offer_v4_runs enable row level security;
alter table public.commercial_offer_v4_source_health enable row level security;
alter table public.commercial_offer_v4_candidates enable row level security;

revoke all on public.commercial_offer_v4_runs from anon, authenticated;
revoke all on public.commercial_offer_v4_source_health from anon, authenticated;
revoke all on public.commercial_offer_v4_candidates from anon, authenticated;
grant all on public.commercial_offer_v4_runs to service_role;
grant all on public.commercial_offer_v4_source_health to service_role;
grant all on public.commercial_offer_v4_candidates to service_role;

-- Offres officielles de démarrage : elles rendent immédiatement visible une offre
-- précise pour les marques concernées, sans attendre le premier crawl complet.
-- L'insertion reste idempotente et ne s'exécute que si la source existe déjà.
-- La colonne URL du catalogue historique est lue via to_jsonb afin de rester
-- compatible avec official_url, url, source_url, entry_url ou page_url.
insert into public.commercial_offers (
  source_id,
  offer_key,
  title,
  summary,
  category,
  benefit_kind,
  benefit_label,
  benefit_value,
  price_amount,
  original_price_amount,
  currency,
  starts_at,
  ends_at,
  status,
  official_url,
  brands,
  model_patterns,
  excluded_model_patterns,
  fuel_types,
  excluded_fuel_types,
  year_min,
  year_max,
  age_min,
  age_max,
  mileage_min,
  mileage_max,
  schedule_keywords,
  conditions_summary,
  eligibility_notes,
  requires_existing_contract,
  requires_network_participation,
  requires_manual_eligibility,
  validation_markers,
  is_featured,
  match_level,
  match_confidence,
  is_brand_fallback,
  last_verified_at,
  v4_source_key,
  updated_at
)
select
  s.id,
  'v4_audi_controle_technique_25_2026',
  'Contrôle Technique Audi à 25 €',
  'Contrôle technique proposé à 25 € dans le réseau Audi participant, sous réserve des conditions publiées par la marque.',
  'INSPECTION',
  'FIXED_PRICE',
  '25 €',
  null::numeric,
  25::numeric,
  null::numeric,
  'EUR',
  '2026-01-22'::date,
  '2026-12-31'::date,
  'ACTIVE',
  'https://www.audi.fr/fr/entretien-reparation/offres-apres-vente/',
  array['audi']::text[],
  '{}'::text[],
  '{}'::text[],
  '{}'::text[],
  '{}'::text[],
  null::integer,
  null::integer,
  null::integer,
  null::integer,
  null::integer,
  null::integer,
  array['controle technique','inspection']::text[],
  'Offre annoncée par Audi France du 22 janvier au 31 décembre 2026. Participation du réparateur et conditions détaillées à confirmer sur la page officielle.',
  'Compatible avec tous les modèles Audi lorsque le réparateur participe à l’opération. AutoClair ne réserve pas la prestation.',
  false,
  true,
  true,
  array['25 €','22 janvier 2026','31 décembre 2026','réseau Audi']::text[],
  true,
  'LIKELY',
  0.9200::numeric,
  false,
  now(),
  'curated:audi_fr_after_sales',
  now()
from public.commercial_offer_sources s
where (lower(s.source_key) = 'audi_fr_after_sales'
       or lower(coalesce(
         to_jsonb(s)->>'official_url',
         to_jsonb(s)->>'url',
         to_jsonb(s)->>'source_url',
         to_jsonb(s)->>'entry_url',
         to_jsonb(s)->>'page_url',
         ''
       )) like '%audi.fr%')
  and not exists (
    select 1 from public.commercial_offers o
    where o.offer_key = 'v4_audi_controle_technique_25_2026'
  )
limit 1;

insert into public.commercial_offers (
  source_id,
  offer_key,
  title,
  summary,
  category,
  benefit_kind,
  benefit_label,
  benefit_value,
  price_amount,
  original_price_amount,
  currency,
  starts_at,
  ends_at,
  status,
  official_url,
  brands,
  model_patterns,
  excluded_model_patterns,
  fuel_types,
  excluded_fuel_types,
  year_min,
  year_max,
  age_min,
  age_max,
  mileage_min,
  mileage_max,
  schedule_keywords,
  conditions_summary,
  eligibility_notes,
  requires_existing_contract,
  requires_network_participation,
  requires_manual_eligibility,
  validation_markers,
  is_featured,
  match_level,
  match_confidence,
  is_brand_fallback,
  last_verified_at,
  v4_source_key,
  updated_at
)
select
  s.id,
  'v4_renault_entretien_99_2026',
  'Entretien Renault de plus de 3 ans à partir de 99 €',
  'Forfait d’entretien Renault à partir de 99 € pour les véhicules de plus de trois ans, selon les conditions publiées par la marque.',
  'MAINTENANCE',
  'FIXED_PRICE',
  'À partir de 99 €',
  null::numeric,
  99::numeric,
  null::numeric,
  'EUR',
  '2026-01-01'::date,
  '2026-12-31'::date,
  'ACTIVE',
  'https://www.renault.fr/offres-renault-care-service.html',
  array['renault']::text[],
  '{}'::text[],
  '{}'::text[],
  '{}'::text[],
  array['electric']::text[],
  null::integer,
  null::integer,
  3::integer,
  null::integer,
  null::integer,
  null::integer,
  array['entretien','revision','vidange']::text[],
  'Offre annoncée jusqu’au 31 décembre 2026 pour certains véhicules Renault de plus de trois ans. Exclusions, capacité d’huile et participation du réseau à confirmer.',
  'L’âge du véhicule est vérifié automatiquement. Les autres conditions techniques restent à confirmer auprès du réparateur.',
  false,
  true,
  true,
  array['99 €','plus de 3 ans','31 décembre 2026','réseau Renault']::text[],
  true,
  'LIKELY',
  0.9000::numeric,
  false,
  now(),
  'curated:renault_fr_after_sales',
  now()
from public.commercial_offer_sources s
where (lower(s.source_key) = 'renault_fr_after_sales'
       or lower(coalesce(
         to_jsonb(s)->>'official_url',
         to_jsonb(s)->>'url',
         to_jsonb(s)->>'source_url',
         to_jsonb(s)->>'entry_url',
         to_jsonb(s)->>'page_url',
         ''
       )) like '%renault.fr%')
  and not exists (
    select 1 from public.commercial_offers o
    where o.offer_key = 'v4_renault_entretien_99_2026'
  )
limit 1;

create or replace function public.commercial_offer_v4_status()
returns jsonb
language sql
security definer
set search_path = ''
as $function$
  select jsonb_build_object(
    'last_run', (select to_jsonb(r) from public.commercial_offer_v4_runs r order by r.started_at desc limit 1),
    'sources_known', (select count(*) from public.commercial_offer_v4_source_health),
    'sources_healthy', (select count(*) from public.commercial_offer_v4_source_health where last_success_at is not null and consecutive_failures = 0),
    'sources_failing', (select count(*) from public.commercial_offer_v4_source_health where consecutive_failures > 0),
    'brands_covered', (select count(distinct brand) from public.commercial_offer_v4_source_health),
    'published_candidates', (select count(*) from public.commercial_offer_v4_candidates where state = 'PUBLISHED'),
    'fallback_offers', (select count(*) from public.commercial_offers where is_brand_fallback and status = 'ACTIVE'),
    'active_offers', (select count(*) from public.commercial_offers where status = 'ACTIVE')
  );
$function$;

grant execute on function public.commercial_offer_v4_status() to authenticated;

create or replace function public.match_commercial_offers_v4(
  p_brand text,
  p_model text default null,
  p_year integer default null,
  p_fuel text default null,
  p_mileage integer default null
)
returns table (
  offer_id uuid,
  match_level text,
  match_score integer,
  matched_rules text[],
  unknown_rules text[]
)
language sql
stable
security definer
set search_path = ''
as $function$
  with normalized as (
    select
      case translate(lower(trim(coalesce(p_brand,''))), 'àáâäãåçéèêëíìîïñóòôöõúùûüýÿ', 'aaaaaaceeeeiiiinooooouuuuyy')
        when 'vw' then 'volkswagen'
        when 'citroen' then 'citroen'
        when 'mercedes' then 'mercedes-benz'
        else translate(lower(trim(coalesce(p_brand,''))), 'àáâäãåçéèêëíìîïñóòôöõúùûüýÿ', 'aaaaaaceeeeiiiinooooouuuuyy')
      end as brand,
      translate(lower(coalesce(p_model,'')), 'àáâäãåçéèêëíìîïñóòôöõúùûüýÿ', 'aaaaaaceeeeiiiinooooouuuuyy') as model,
      translate(lower(coalesce(p_fuel,'')), 'àáâäãåçéèêëíìîïñóòôöõúùûüýÿ', 'aaaaaaceeeeiiiinooooouuuuyy') as fuel
  ), candidates as (
    select o.*,
      case when exists (
        select 1 from unnest(coalesce(o.brands, '{}'::text[])) b, normalized n
        where translate(lower(b), 'àáâäãåçéèêëíìîïñóòôöõúùûüýÿ', 'aaaaaaceeeeiiiinooooouuuuyy') = n.brand
      ) then 40 else -1000 end as brand_score,
      case
        when p_model is not null and exists (
          select 1 from unnest(coalesce(o.excluded_model_patterns, '{}'::text[])) m, normalized n
          where n.model like '%' || translate(lower(m), 'àáâäãåçéèêëíìîïñóòôöõúùûüýÿ', 'aaaaaaceeeeiiiinooooouuuuyy') || '%'
        ) then -1000
        when coalesce(cardinality(o.model_patterns), 0) = 0 then 15
        when nullif(trim(coalesce(p_model,'')), '') is null then 0
        when exists (
          select 1 from unnest(coalesce(o.model_patterns, '{}'::text[])) m, normalized n
          where n.model like '%' || translate(lower(m), 'àáâäãåçéèêëíìîïñóòôöõúùûüýÿ', 'aaaaaaceeeeiiiinooooouuuuyy') || '%'
        ) then 20
        else -100
      end as model_score,
      case
        when o.year_min is null and o.year_max is null then 0
        when p_year is null then 0
        when (o.year_min is null or p_year >= o.year_min) and (o.year_max is null or p_year <= o.year_max) then 10
        else -100
      end as year_score,
      case
        when o.age_min is null and o.age_max is null then 0
        when p_year is null then 0
        when (o.age_min is null or extract(year from current_date)::integer - p_year >= o.age_min)
         and (o.age_max is null or extract(year from current_date)::integer - p_year <= o.age_max) then 10
        else -100
      end as age_score,
      case
        when nullif(trim(coalesce(p_fuel,'')), '') is not null and exists (
          select 1 from unnest(coalesce(o.excluded_fuel_types, '{}'::text[])) f, normalized n
          where translate(lower(f), 'àáâäãåçéèêëíìîïñóòôöõúùûüýÿ', 'aaaaaaceeeeiiiinooooouuuuyy') = n.fuel
        ) then -1000
        when coalesce(cardinality(o.fuel_types), 0) = 0 then 0
        when nullif(trim(coalesce(p_fuel,'')), '') is null then 0
        when exists (
          select 1 from unnest(coalesce(o.fuel_types, '{}'::text[])) f, normalized n
          where translate(lower(f), 'àáâäãåçéèêëíìîïñóòôöõúùûüýÿ', 'aaaaaaceeeeiiiinooooouuuuyy') = n.fuel
        ) then 10
        else -100
      end as fuel_score,
      case
        when o.mileage_min is null and o.mileage_max is null then 0
        when p_mileage is null then 0
        when (o.mileage_min is null or p_mileage >= o.mileage_min)
         and (o.mileage_max is null or p_mileage <= o.mileage_max) then 10
        else -100
      end as mileage_score
    from public.commercial_offers o
    where o.status = 'ACTIVE'
      and (o.starts_at is null or o.starts_at <= current_date)
      and (o.ends_at is null or o.ends_at >= current_date)
  ), eligible as (
    select c.*,
      c.brand_score + c.model_score + c.year_score + c.age_score + c.fuel_score + c.mileage_score as total_score
    from candidates c
    where c.brand_score > -100
      and c.model_score > -100
      and c.year_score > -100
      and c.age_score > -100
      and c.fuel_score > -100
      and c.mileage_score > -100
  ), ranked as (
    select
      c.id as offer_id,
      case
        when c.is_brand_fallback then 'TO_CHECK'
        when c.requires_manual_eligibility or c.requires_network_participation or c.requires_existing_contract then
          case when c.total_score >= 55 then 'LIKELY' else 'TO_CHECK' end
        when c.total_score >= 75 then 'CONFIRMED'
        when c.total_score >= 55 then 'LIKELY'
        else 'TO_CHECK'
      end::text as resolved_match_level,
      greatest(0, c.total_score)::integer as resolved_match_score,
      array_remove(array[
        case when c.brand_score > 0 then 'Marque compatible' end,
        case when c.model_score = 20 then 'Modèle explicitement compatible' when c.model_score = 15 then 'Tous les modèles de la marque' end,
        case when c.year_score > 0 then 'Année compatible' end,
        case when c.age_score > 0 then 'Âge du véhicule compatible' end,
        case when c.fuel_score > 0 then 'Motorisation compatible' end,
        case when c.mileage_score > 0 then 'Kilométrage compatible' end
      ], null)::text[] as resolved_matched_rules,
      array_remove(array[
        case when nullif(trim(coalesce(p_model,'')), '') is null and coalesce(cardinality(c.model_patterns), 0) > 0 then 'Modèle à confirmer' end,
        case when p_year is null and (c.year_min is not null or c.year_max is not null) then 'Année à confirmer' end,
        case when p_year is null and (c.age_min is not null or c.age_max is not null) then 'Âge du véhicule à confirmer' end,
        case when nullif(trim(coalesce(p_fuel,'')), '') is null and coalesce(cardinality(c.fuel_types), 0) > 0 then 'Motorisation à confirmer' end,
        case when p_mileage is null and (c.mileage_min is not null or c.mileage_max is not null) then 'Kilométrage à confirmer' end,
        case when c.requires_network_participation then 'Participation du réseau à confirmer' end,
        case when c.requires_existing_contract then 'Contrat existant à confirmer' end,
        case when c.requires_manual_eligibility then 'Conditions détaillées à confirmer' end
      ], null)::text[] as resolved_unknown_rules,
      c.is_brand_fallback as sort_brand_fallback,
      c.is_featured as sort_featured,
      c.updated_at as sort_updated_at
    from eligible c
  )
  select
    r.offer_id,
    r.resolved_match_level,
    r.resolved_match_score,
    r.resolved_matched_rules,
    r.resolved_unknown_rules
  from ranked r
  order by
    r.sort_brand_fallback asc,
    r.resolved_match_score desc,
    r.sort_featured desc,
    r.sort_updated_at desc;
$function$;

grant execute on function public.match_commercial_offers_v4(text,text,integer,text,integer) to authenticated;

-- Planification tolérante : si pg_cron/pg_net sont disponibles, V4 s'exécute toutes les 15 minutes.
do $block$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron')
     and exists (select 1 from pg_extension where extname = 'pg_net') then
    perform cron.unschedule(jobid)
      from cron.job
      where jobname = 'autoclair-commercial-offers-v4';
    perform cron.schedule(
      'autoclair-commercial-offers-v4',
      '*/15 * * * *',
      $job$select net.http_post(
        url := 'https://zkzocdtxebacxcrkrkzu.supabase.co/functions/v1/sync-commercial-offers-v4',
        headers := '{"Content-Type":"application/json"}'::jsonb,
        body := '{"mode":"scheduled","limit":6}'::jsonb,
        timeout_milliseconds := 55000
      );$job$
    );
  end if;
end;
$block$;

commit;
