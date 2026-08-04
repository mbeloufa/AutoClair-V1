begin;

do $precheck$
declare
  v_missing text[] := array[]::text[];
begin
  if to_regclass('public.vehicles') is null then
    v_missing := array_append(v_missing, 'public.vehicles');
  end if;

  if to_regclass('public.vehicle_maintenance_schedules') is null then
    v_missing := array_append(
      v_missing,
      'public.vehicle_maintenance_schedules'
    );
  end if;

  if to_regclass('public.vehicle_events') is null then
    v_missing := array_append(v_missing, 'public.vehicle_events');
  end if;

  if cardinality(v_missing) > 0 then
    raise exception
      'COMMERCIAL_OFFERS_PRECHECK_FAILED:%',
      array_to_string(v_missing, ',');
  end if;
end
$precheck$;

create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault with schema vault;

create schema if not exists private;

create or replace function private.autoclair_offer_normalize_words(
  p_value text
)
returns text
language sql
immutable
set search_path = ''
as $function$
  select trim(
    regexp_replace(
      lower(
        translate(
          coalesce(p_value, ''),
          'àáâäãåçèéêëìíîïñòóôöõùúûüýÿœæ',
          'aaaaaaceeeeiiiinooooouuuuyyoeae'
        )
      ),
      '[^a-z0-9]+',
      ' ',
      'g'
    )
  );
$function$;

create or replace function private.autoclair_offer_brand(
  p_value text
)
returns text
language sql
immutable
set search_path = ''
as $function$
  select case
    when private.autoclair_offer_normalize_words(p_value)
      in ('vw', 'volkswagen', 'volkswagen france')
      then 'volkswagen'
    when private.autoclair_offer_normalize_words(p_value)
      like 'renault%'
      then 'renault'
    when private.autoclair_offer_normalize_words(p_value)
      like 'peugeot%'
      then 'peugeot'
    when private.autoclair_offer_normalize_words(p_value)
      like 'citroen%'
      then 'citroen'
    when private.autoclair_offer_normalize_words(p_value)
      like 'dacia%'
      then 'dacia'
    else private.autoclair_offer_normalize_words(p_value)
  end;
$function$;

create or replace function private.autoclair_offer_fuel(
  p_value text
)
returns text
language sql
immutable
set search_path = ''
as $function$
  select case
    when private.autoclair_offer_normalize_words(p_value)
      ~ '(electrique|electric|ev|e tech electrique)'
      then 'electric'
    when private.autoclair_offer_normalize_words(p_value)
      ~ '(hybride|hybrid)'
      then 'hybrid'
    when private.autoclair_offer_normalize_words(p_value)
      ~ '(gpl|lpg)'
      then 'lpg'
    when private.autoclair_offer_normalize_words(p_value)
      ~ '(diesel|gazole)'
      then 'diesel'
    when private.autoclair_offer_normalize_words(p_value)
      ~ '(essence|petrol)'
      then 'petrol'
    else private.autoclair_offer_normalize_words(p_value)
  end;
$function$;

revoke all
  on function private.autoclair_offer_normalize_words(text)
  from public, anon, authenticated;

revoke all
  on function private.autoclair_offer_brand(text)
  from public, anon, authenticated;

revoke all
  on function private.autoclair_offer_fuel(text)
  from public, anon, authenticated;

create table if not exists public.commercial_offer_sources (
  id uuid primary key default gen_random_uuid(),
  source_key text not null unique,
  brand_code text not null,
  source_name text not null,
  source_url text not null,
  allowed_hostnames text[] not null default array[]::text[],
  status text not null default 'ACTIVE',
  robots_status text not null default 'UNKNOWN',
  last_http_status integer,
  last_checked_at timestamptz,
  last_success_at timestamptz,
  failure_count integer not null default 0,
  content_hash text,
  last_error_code text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint commercial_offer_sources_status_allowed
    check (status in ('ACTIVE', 'PAUSED', 'BLOCKED', 'ERROR')),
  constraint commercial_offer_sources_robots_allowed
    check (robots_status in ('UNKNOWN', 'ALLOWED', 'DISALLOWED', 'UNAVAILABLE'))
);

create table if not exists public.commercial_offers (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null
    references public.commercial_offer_sources(id) on delete cascade,
  offer_key text not null unique,
  title text not null,
  summary text not null,
  category text not null,
  benefit_kind text not null,
  benefit_label text not null,
  benefit_value numeric,
  price_amount numeric,
  original_price_amount numeric,
  currency text not null default 'EUR',
  starts_at date,
  ends_at date,
  status text not null default 'ACTIVE',
  official_url text not null,
  brands text[] not null default array[]::text[],
  model_patterns text[] not null default array[]::text[],
  excluded_model_patterns text[] not null default array[]::text[],
  fuel_types text[] not null default array[]::text[],
  excluded_fuel_types text[] not null default array[]::text[],
  year_min integer,
  year_max integer,
  age_min integer,
  age_max integer,
  mileage_min integer,
  mileage_max integer,
  schedule_keywords text[] not null default array[]::text[],
  conditions_summary text not null default '',
  eligibility_notes text not null default '',
  requires_existing_contract boolean not null default false,
  requires_network_participation boolean not null default false,
  requires_manual_eligibility boolean not null default false,
  validation_markers text[] not null default array[]::text[],
  verification_failure_count integer not null default 0,
  last_verification_error text,
  last_verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint commercial_offers_category_allowed
    check (
      category in (
        'MAINTENANCE',
        'TYRES',
        'BATTERY',
        'CLIMATE',
        'ACCESSORIES',
        'INSPECTION',
        'WINDSCREEN',
        'CONTRACT',
        'BODYWORK',
        'OTHER'
      )
    ),
  constraint commercial_offers_benefit_allowed
    check (
      benefit_kind in (
        'PERCENT',
        'FIXED_PRICE',
        'FROM_PRICE',
        'REIMBURSEMENT',
        'FREE_SERVICE',
        'INFO'
      )
    ),
  constraint commercial_offers_status_allowed
    check (
      status in (
        'ACTIVE',
        'EXPIRED',
        'REVIEW_REQUIRED',
        'PAUSED'
      )
    ),
  constraint commercial_offers_dates_valid
    check (
      starts_at is null or
      ends_at is null or
      starts_at <= ends_at
    ),
  constraint commercial_offers_price_nonnegative
    check (
      (price_amount is null or price_amount >= 0) and
      (
        original_price_amount is null or
        original_price_amount >= 0
      )
    )
);

create index if not exists commercial_offers_active_idx
  on public.commercial_offers(status, ends_at, last_verified_at);

create index if not exists commercial_offers_source_idx
  on public.commercial_offers(source_id, status);

create table if not exists public.vehicle_commercial_offer_preferences (
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  offer_id uuid not null references public.commercial_offers(id)
    on delete cascade,
  status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, vehicle_id, offer_id),
  constraint vehicle_commercial_offer_preferences_status_allowed
    check (status in ('SAVED', 'DISMISSED'))
);

create index if not exists vehicle_offer_preferences_vehicle_idx
  on public.vehicle_commercial_offer_preferences(
    vehicle_id,
    status,
    updated_at desc
  );

create table if not exists public.commercial_offer_candidates (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null
    references public.commercial_offer_sources(id) on delete cascade,
  candidate_hash text not null,
  excerpt text not null,
  detected_labels text[] not null default array[]::text[],
  status text not null default 'PENDING_REVIEW',
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  unique (source_id, candidate_hash),
  constraint commercial_offer_candidates_status_allowed
    check (
      status in ('PENDING_REVIEW', 'APPROVED', 'REJECTED', 'OBSOLETE')
    )
);

create table if not exists public.commercial_offer_sync_runs (
  id uuid primary key default gen_random_uuid(),
  status text not null,
  trigger_type text not null default 'SCHEDULED',
  source_count integer not null default 0,
  success_count integer not null default 0,
  failure_count integer not null default 0,
  verified_offer_count integer not null default 0,
  review_offer_count integer not null default 0,
  candidate_count integer not null default 0,
  error_summary text,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  constraint commercial_offer_sync_runs_status_allowed
    check (status in ('RUNNING', 'SUCCESS', 'PARTIAL', 'FAILED', 'SKIPPED'))
);

create index if not exists commercial_offer_sync_runs_time_idx
  on public.commercial_offer_sync_runs(started_at desc);

create table if not exists public.commercial_offer_sync_state (
  state_key text primary key,
  locked_until timestamptz,
  last_started_at timestamptz,
  last_finished_at timestamptz,
  updated_at timestamptz not null default now()
);

insert into public.commercial_offer_sync_state(state_key)
values ('GLOBAL')
on conflict (state_key) do nothing;

alter table public.commercial_offer_sources enable row level security;
alter table public.commercial_offers enable row level security;
alter table public.vehicle_commercial_offer_preferences enable row level security;
alter table public.commercial_offer_candidates enable row level security;
alter table public.commercial_offer_sync_runs enable row level security;
alter table public.commercial_offer_sync_state enable row level security;

revoke all on table public.commercial_offer_sources
  from public, anon, authenticated;
revoke all on table public.commercial_offers
  from public, anon, authenticated;
revoke all on table public.vehicle_commercial_offer_preferences
  from public, anon, authenticated;
revoke all on table public.commercial_offer_candidates
  from public, anon, authenticated;
revoke all on table public.commercial_offer_sync_runs
  from public, anon, authenticated;
revoke all on table public.commercial_offer_sync_state
  from public, anon, authenticated;

grant select, insert, update, delete
  on table public.commercial_offer_sources
  to service_role;
grant select, insert, update, delete
  on table public.commercial_offers
  to service_role;
grant select, insert, update, delete
  on table public.vehicle_commercial_offer_preferences
  to service_role;
grant select, insert, update, delete
  on table public.commercial_offer_candidates
  to service_role;
grant select, insert, update, delete
  on table public.commercial_offer_sync_runs
  to service_role;
grant select, insert, update, delete
  on table public.commercial_offer_sync_state
  to service_role;

drop policy if exists
  vehicle_offer_preferences_select_own
  on public.vehicle_commercial_offer_preferences;

create policy vehicle_offer_preferences_select_own
  on public.vehicle_commercial_offer_preferences
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

insert into public.commercial_offer_sources (
  source_key,
  brand_code,
  source_name,
  source_url,
  allowed_hostnames
)
values
  ('volkswagen_fr_after_sales','volkswagen','Volkswagen France','https://www.volkswagen.fr/fr/entretenir-ma-volkswagen/contrat-entretien-mensualisation.html',array['www.volkswagen.fr','volkswagen.fr']::text[]),
  ('renault_fr_care_service','renault','Renault Care Service','https://www.renault.fr/offres-renault-care-service.html',array['www.renault.fr','renault.fr']::text[]),
  ('peugeot_fr_after_sales','peugeot','Peugeot France','https://www.peugeot.fr/entretien-et-services/entretenir-mon-vehicule/offres-du-moment.html',array['www.peugeot.fr','peugeot.fr']::text[]),
  ('citroen_fr_after_sales','citroen','Citroën France','https://www.citroen.fr/entretenir/offres.html',array['www.citroen.fr','citroen.fr']::text[])
on conflict (source_key) do update set
  brand_code = excluded.brand_code,
  source_name = excluded.source_name,
  source_url = excluded.source_url,
  allowed_hostnames = excluded.allowed_hostnames,
  status = 'ACTIVE',
  robots_status = 'UNKNOWN',
  last_checked_at = now(),
  last_success_at = now(),
  failure_count = 0,
  last_error_code = null,
  updated_at = now();

update public.commercial_offer_sources
set
  status = 'ACTIVE',
  last_checked_at = coalesce(last_checked_at, now()),
  last_success_at = coalesce(last_success_at, now()),
  failure_count = 0,
  updated_at = now()
where source_key in (
  'volkswagen_fr_after_sales',
  'renault_fr_care_service',
  'peugeot_fr_after_sales',
  'citroen_fr_after_sales'
);

with seeded (
  source_key,
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
  validation_markers
) as (
  values
    ('volkswagen_fr_after_sales','vw_contract_remises_2019_2021','Remises entretien avec contrat Volkswagen','Promotions conseillées pour les Volkswagen immatriculées de 2019 à 2021 disposant d’un contrat d’entretien valide.','MAINTENANCE','PERCENT','-20 % sur une sélection de prestations',20,null,null,'EUR','2026-01-01'::date,'2026-12-31'::date,array['volkswagen']::text[],array[]::text[],array[]::text[],array[]::text[],array[]::text[],2019,2021,null,null,null,null,array['entretien','revision','vidange','filtre','frein']::text[],'Véhicule Volkswagen immatriculé de 2019 à 2021 et contrat d’entretien Volkswagen Bank en cours de validité.','Montant de la remise et participation du réparateur à confirmer.',true,true,true,array['immatricule de 2019 a 2021','contrat d entretien','31 decembre 2026']::text[]),
    ('volkswagen_fr_after_sales','vw_contract_remises_2011_2018','Remises entretien Volkswagen de plus de 7 ans','Promotions conseillées pour les Volkswagen immatriculées de 2011 à 2018 disposant d’un contrat d’entretien valide.','MAINTENANCE','PERCENT','-30 % sur une sélection de prestations',30,null,null,'EUR','2026-01-01'::date,'2026-12-31'::date,array['volkswagen']::text[],array[]::text[],array[]::text[],array[]::text[],array[]::text[],2011,2018,null,null,null,null,array['entretien','revision','vidange','filtre','frein']::text[],'Véhicule Volkswagen immatriculé de 2011 à 2018 et contrat d’entretien Volkswagen Bank en cours de validité.','Montant de la remise et participation du réparateur à confirmer.',true,true,true,array['immatricule de 2011 a 2018','contrat d entretien','31 decembre 2026']::text[]),
    ('volkswagen_fr_after_sales','vw_contract_24_months_2026','Contrat d’entretien Volkswagen 24 mois','Contrat couvrant une sélection d’opérations d’entretien pendant 24 mois, dans la limite de 40 000 km.','CONTRACT','INFO','Entretien couvert pendant 24 mois',null,null,null,'EUR','2026-01-01'::date,'2026-08-31'::date,array['volkswagen']::text[],array[]::text[],array[]::text[],array[]::text[],array[]::text[],null,null,null,12,null,220000,array['entretien','revision','vidange','filtre','bougie','liquide de frein']::text[],'Volkswagen de moins de 13 ans et de moins de 220 000 km. Contrat limité à 40 000 km parcourus après souscription.','Sous réserve d’acceptation du dossier par Volkswagen Bank et du réseau participant.',false,true,true,array['contrat d entretien de 24 mois','moins de 13 ans','moins de 220 000 km','31 aout 2026']::text[]),
    ('renault_fr_care_service','renault_forfait_avantage_2026','Forfait Avantage Renault','Réduction sur les opérations d’entretien et d’usure pour les Renault de plus de 4 ans.','MAINTENANCE','PERCENT','-15 % sur les forfaits éligibles',15,null,null,'EUR','2026-06-01'::date,'2026-12-31'::date,array['renault']::text[],array[]::text[],array[]::text[],array[]::text[],array[]::text[],null,null,5,null,null,null,array['entretien','revision','vidange','frein','distribution','echappement','essuie glace']::text[],'Particuliers propriétaires d’une Renault de plus de 4 ans, hors véhicules de plus de 3,5 t.','Forfait, pièces et disponibilité à confirmer auprès du réseau participant.',false,true,false,array['vehicule a plus de 4 ans','beneficiez de 15','01 06 au 31 12 26']::text[]),
    ('renault_fr_care_service','renault_revision_99','Entretien Renault pour véhicule de plus de 3 ans','Révision comprenant notamment 38 points de contrôle, vidange et filtre à huile.','MAINTENANCE','FROM_PRICE','À partir de 99 €',null,99,null,'EUR',null,null,array['renault']::text[],array[]::text[],array[]::text[],array[]::text[],array[]::text[],null,null,4,null,null,null,array['entretien','revision','vidange','filtre a huile']::text[],'Forfait destiné aux Renault de plus de 3 ans.','Prix final selon le modèle, la motorisation, les pièces et l’atelier.',false,true,true,array['vehicule a plus de 3 ans','a partir de 99','38 points de controle']::text[]),
    ('renault_fr_care_service','renault_renative_30','Pièces Renault renative','Gamme de pièces issues de l’économie circulaire proposée à un tarif annoncé inférieur aux pièces neuves équivalentes.','MAINTENANCE','PERCENT','Jusqu’à 30 % moins cher selon la pièce',30,null,null,'EUR',null,null,array['renault']::text[],array[]::text[],array[]::text[],array[]::text[],array[]::text[],null,null,null,null,null,null,array['reparation','remplacement','moteur','alternateur','demarreur','boite']::text[],'Disponibilité limitée aux références renative compatibles.','La compatibilité exacte de la référence doit être confirmée par l’atelier.',false,true,true,array['moteurs renative','30% moins chers','plus de 2000 references','economie circulaire']::text[]),
    ('renault_fr_care_service','renault_clio_v_safety_car','Bridage Safety Car Renault Clio V','Transformation réversible d’une Clio V compatible avec limitation à 110 km/h pour l’apprentissage.','MAINTENANCE','FIXED_PRICE','59 € par opération',null,59,null,'EUR',null,null,array['renault']::text[],array['clio v','clio 5']::text[],array[]::text[],array[]::text[],array[]::text[],null,null,null,null,null,null,array[]::text[],'Uniquement pour les Renault Clio V compatibles.','Compatibilité technique à confirmer avec Renault.',false,true,true,array['brider votre renault clio v','59€ par operation','operation est reversible','110 km h']::text[]),
    ('renault_fr_care_service','renault_bodywork_99','Forfaits carrosserie Renault','Forfaits carrosserie comprenant pièces, main-d’œuvre et peinture selon la taille et l’emplacement du dommage.','BODYWORK','FROM_PRICE','À partir de 99 €',null,99,null,'EUR',null,null,array['renault']::text[],array[]::text[],array[]::text[],array[]::text[],array[]::text[],null,null,null,null,null,null,array['carrosserie','rayure','choc','pare choc','peinture']::text[],'Tarif dépendant du dommage et de la possibilité de réparer la pièce.','Diagnostic et devis de l’atelier nécessaires.',false,true,true,array['forfaits carrosserie a partir de 99','pieces main d oeuvre peinture','taille et la localisation de l impact']::text[]),
    ('renault_fr_care_service','renault_windscreen_franchise_2026','Franchise pare-brise offerte Renault','Prise en charge annoncée de la franchise pour un remplacement de pare-brise couvert par l’assurance.','WINDSCREEN','FREE_SERVICE','Franchise bris de glace offerte',null,null,null,'EUR','2026-01-01'::date,'2026-12-31'::date,array['renault']::text[],array[]::text[],array[]::text[],array[]::text[],array[]::text[],null,null,null,null,null,null,array['pare brise','vitrage','bris de glace']::text[],'Remplacement de pare-brise avec prise en charge par l’assurance, selon les conditions de l’offre.','Garantie bris de glace, montant de franchise et participation du réseau à confirmer.',false,true,true,array['franchise offerte pour tout remplacement de pare brise','31 decembre 2026','bris de glace']::text[]),
    ('renault_fr_care_service','renault_contract_privileges_2026','Contrat entretien privilèges Renault','Mensualisation de l’entretien pour les véhicules âgés de 1 à 8 ans et ne dépassant pas 120 000 km à la souscription.','CONTRACT','FROM_PRICE','À partir de 1 € par jour',null,1,null,'EUR','2026-03-01'::date,'2026-12-31'::date,array['renault']::text[],array[]::text[],array[]::text[],array[]::text[],array[]::text[],null,null,1,8,null,120000,array['entretien','revision','vidange']::text[],'Véhicule de 1 à 8 ans et 120 000 km maximum à la souscription. Contrat jusqu’à 200 000 km maximum.','Tarif précis et acceptation du contrat à confirmer.',false,true,true,array['contrat entretien privileges','1€ par jour','entre 1 et 8 ans','120 000 km','31 decembre 2026']::text[]),
    ('renault_fr_care_service','renault_ct_pack_69_2026','Pack contrôle technique Renault Care Service','Pack incluant bilan préparatoire, contrôle technique, solution de mobilité et contre-visite offerte.','INSPECTION','FROM_PRICE','À partir de 69 €',null,69,null,'EUR','2026-01-01'::date,'2026-12-31'::date,array['*']::text[],array[]::text[],array[]::text[],array[]::text[],array['electric','hybrid','lpg']::text[],null,null,null,null,null,null,array['controle technique','contre visite']::text[],'Toutes marques, hors GPL, électrique, hybride et véhicules de plus de 3,5 t.','Centre, véhicule de remplacement et contre-visite soumis aux conditions locales.',false,true,true,array['pack controle technique a partir de 69','contre visite offerte','hors vehicules gpl electriques et hybrides','31 12 2026']::text[]),
    ('renault_fr_care_service','renault_ev_revision_125','Révision Renault E-Tech électrique','Révision avec 87 points de contrôle, diagnostic électronique et certification de l’état de santé de la batterie.','MAINTENANCE','FROM_PRICE','À partir de 125 €',null,125,null,'EUR',null,null,array['renault']::text[],array[]::text[],array[]::text[],array['electric']::text[],array[]::text[],null,null,null,null,null,null,array['entretien','revision','batterie','diagnostic']::text[],'Véhicules Renault électriques particuliers, hors véhicules de plus de 3,5 t.','Programme exact et prix final selon le véhicule.',false,true,true,array['revision e tech electrique a partir de 125','87 points de controle','etat de sante de votre batterie']::text[]),
    ('peugeot_fr_after_sales','peugeot_accessories_roof_bars_2026','Barres de toit Peugeot','Remise sur une sélection de barres de toit Peugeot, hors pose.','ACCESSORIES','PERCENT','-20 % sur une sélection de barres de toit',20,null,null,'EUR','2026-06-01'::date,'2026-08-31'::date,array['peugeot']::text[],array[]::text[],array[]::text[],array[]::text[],array[]::text[],null,null,null,null,null,null,array[]::text[],'Dans la limite des stocks disponibles, hors pose.','Référence compatible avec le modèle et stock à confirmer.',false,true,true,array['20% sur une selection d accessoires','barres de toit','31 aout 2026']::text[]),
    ('peugeot_fr_after_sales','peugeot_revision_assistance','Révision constructeur Peugeot','Révision constructeur avec un an d’assistance annoncé et possibilité de paiement jusqu’à quatre fois sans frais.','MAINTENANCE','INFO','1 an d’assistance offert',null,null,null,'EUR',null,null,array['peugeot']::text[],array[]::text[],array[]::text[],array[]::text[],array[]::text[],null,null,null,null,null,null,array['entretien','revision','vidange','filtre']::text[],'Révision réalisée dans le réseau Peugeot selon le programme du véhicule.','Prix, financement et conditions d’assistance à confirmer.',false,true,true,array['revision constructeur','1 an d assistance offert','4 fois sans frais']::text[]),
    ('peugeot_fr_after_sales','peugeot_ct_pack_99_2026','Pack contrôle technique Peugeot','Pré-contrôle, contrôle technique, contre-visite éventuelle et véhicule de remplacement.','INSPECTION','FIXED_PRICE','Pack à 99 €',null,99,null,'EUR','2026-01-01'::date,'2026-12-31'::date,array['peugeot']::text[],array[]::text[],array[]::text[],array[]::text[],array['electric','hybrid']::text[],null,null,null,null,null,null,array['controle technique','contre visite']::text[],'Hors motorisation électrique et hybride. Véhicule de remplacement limité selon les conditions.','À utiliser lorsque le contrôle technique approche et dans un réseau participant.',false,true,true,array['pack controle technique a 99','contre visite','31 decembre 2026','hors motorisation electrique et hybride']::text[]),
    ('citroen_fr_after_sales','citroen_climate_check_2026','Contrôle climatisation Citroën offert','Mesure de la température en sortie d’aérateurs pour contrôler le circuit de climatisation.','CLIMATE','FREE_SERVICE','Contrôle du circuit offert',null,null,null,'EUR','2026-05-02'::date,'2026-08-31'::date,array['citroen']::text[],array[]::text[],array[]::text[],array[]::text[],array[]::text[],null,null,null,null,null,null,array['climatisation','clim','filtre habitacle']::text[],'Contrôle sans obligation d’achat dans le réseau Citroën participant.','Ne remplace pas un diagnostic complet ni une recharge du circuit.',false,true,false,array['controle du circuit de climatisation offert','31 aout 2026','temperature en sortie d aerateurs']::text[]),
    ('citroen_fr_after_sales','citroen_roof_bars_2026','Barres de toit Citroën','Remise sur certaines références de barres de toit, hors pose.','ACCESSORIES','PERCENT','-20 % sur les barres de toit',20,null,null,'EUR','2026-06-01'::date,'2026-08-31'::date,array['citroen']::text[],array[]::text[],array[]::text[],array[]::text[],array[]::text[],null,null,null,null,null,null,array[]::text[],'Références concernées et stocks limités, hors pose.','Compatibilité exacte avec le modèle à confirmer.',false,true,true,array['20% sur les barres de toit','hors pose','31 08 2026']::text[]),
    ('citroen_fr_after_sales','citroen_safety_check_2026','Bilan sécurité Citroën offert','Contrôles visuels de sécurité réalisés dans le réseau participant.','MAINTENANCE','FREE_SERVICE','Bilan sécurité offert',null,null,null,'EUR','2026-01-01'::date,'2026-12-31'::date,array['citroen']::text[],array[]::text[],array[]::text[],array[]::text[],array[]::text[],null,null,null,null,null,null,array['entretien','revision','frein','pneu','securite']::text[],'Contrôles visuels ne remplaçant pas le contrôle technique obligatoire.','Liste des points contrôlés à confirmer auprès du point de vente.',false,true,false,array['bilan securite offert','31 decembre 2026','controles visuels']::text[]),
    ('citroen_fr_after_sales','citroen_ct_pack_99_2026','Pack contrôle technique Citroën','Pré-contrôle, passage au centre agréé, contre-visite et véhicule de remplacement.','INSPECTION','FIXED_PRICE','Pack à 99 €',null,99,null,'EUR','2026-01-01'::date,'2026-12-31'::date,array['citroen']::text[],array[]::text[],array[]::text[],array[]::text[],array['electric','hybrid']::text[],null,null,null,null,null,null,array['controle technique','contre visite']::text[],'Valable dans les deux mois précédant l’échéance obligatoire. Hors électrique et hybride.','Disponibilité du véhicule de remplacement et participation du réseau à confirmer.',false,true,true,array['pack a 99','contre visite offerte','31 decembre 2026','hors motorisation electrique et hybride']::text[])
)
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
  last_verified_at,
  updated_at
)
select
  s.id,
  seeded.offer_key::text,
  seeded.title::text,
  seeded.summary::text,
  seeded.category::text,
  seeded.benefit_kind::text,
  seeded.benefit_label::text,
  seeded.benefit_value::numeric,
  seeded.price_amount::numeric,
  seeded.original_price_amount::numeric,
  seeded.currency::text,
  seeded.starts_at::date,
  seeded.ends_at::date,
  case
    when seeded.ends_at::date is not null
      and seeded.ends_at::date < current_date
      then 'EXPIRED'
    else 'ACTIVE'
  end,
  s.source_url,
  seeded.brands::text[],
  seeded.model_patterns::text[],
  seeded.excluded_model_patterns::text[],
  seeded.fuel_types::text[],
  seeded.excluded_fuel_types::text[],
  seeded.year_min::integer,
  seeded.year_max::integer,
  seeded.age_min::integer,
  seeded.age_max::integer,
  seeded.mileage_min::integer,
  seeded.mileage_max::integer,
  seeded.schedule_keywords::text[],
  seeded.conditions_summary::text,
  seeded.eligibility_notes::text,
  seeded.requires_existing_contract::boolean,
  seeded.requires_network_participation::boolean,
  seeded.requires_manual_eligibility::boolean,
  seeded.validation_markers::text[],
  now(),
  now()
from seeded
join public.commercial_offer_sources s
  on s.source_key = seeded.source_key
on conflict (offer_key) do update set
  source_id = excluded.source_id,
  title = excluded.title,
  summary = excluded.summary,
  category = excluded.category,
  benefit_kind = excluded.benefit_kind,
  benefit_label = excluded.benefit_label,
  benefit_value = excluded.benefit_value,
  price_amount = excluded.price_amount,
  original_price_amount = excluded.original_price_amount,
  currency = excluded.currency,
  starts_at = excluded.starts_at,
  ends_at = excluded.ends_at,
  official_url = excluded.official_url,
  brands = excluded.brands,
  model_patterns = excluded.model_patterns,
  excluded_model_patterns = excluded.excluded_model_patterns,
  fuel_types = excluded.fuel_types,
  excluded_fuel_types = excluded.excluded_fuel_types,
  year_min = excluded.year_min,
  year_max = excluded.year_max,
  age_min = excluded.age_min,
  age_max = excluded.age_max,
  mileage_min = excluded.mileage_min,
  mileage_max = excluded.mileage_max,
  schedule_keywords = excluded.schedule_keywords,
  conditions_summary = excluded.conditions_summary,
  eligibility_notes = excluded.eligibility_notes,
  requires_existing_contract = excluded.requires_existing_contract,
  requires_network_participation =
    excluded.requires_network_participation,
  requires_manual_eligibility = excluded.requires_manual_eligibility,
  validation_markers = excluded.validation_markers,
  status = case
    when excluded.ends_at is not null
      and excluded.ends_at < current_date
      then 'EXPIRED'
    else public.commercial_offers.status
  end,
  updated_at = now();

create or replace function public.get_vehicle_commercial_offers(
  p_vehicle_id uuid,
  p_limit integer default 60
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_vehicle record;
  v_offers jsonb;
  v_active_source_count integer;
  v_active_offer_count integer;
  v_last_sync timestamptz;
  v_limit integer := greatest(1, least(coalesce(p_limit, 60), 100));
begin
  if v_uid is null then
    raise exception 'COMMERCIAL_OFFERS_AUTH_REQUIRED';
  end if;

  select
    v.id,
    v.make,
    v.model,
    v.vehicle_year,
    v.fuel_type,
    v.mileage
  into v_vehicle
  from public.vehicles v
  where v.id = p_vehicle_id
    and v.user_id = v_uid;

  if not found then
    raise exception 'COMMERCIAL_OFFERS_VEHICLE_NOT_FOUND';
  end if;

  select count(*)::integer
  into v_active_source_count
  from public.commercial_offer_sources s
  where s.status in ('ACTIVE', 'ERROR')
    and s.last_success_at >= now() - interval '14 days';

  select count(*)::integer
  into v_active_offer_count
  from public.commercial_offers o
  join public.commercial_offer_sources s on s.id = o.source_id
  where o.status = 'ACTIVE'
    and (o.starts_at is null or o.starts_at <= current_date)
    and (o.ends_at is null or o.ends_at >= current_date)
    and o.last_verified_at >= now() - interval '14 days'
    and s.status in ('ACTIVE', 'ERROR')
    and s.last_success_at >= now() - interval '14 days';

  select max(r.finished_at)
  into v_last_sync
  from public.commercial_offer_sync_runs r
  where r.status in ('SUCCESS', 'PARTIAL');

  with base as (
    select
      o.*,
      s.source_name,
      s.last_success_at as source_last_success_at,
      pref.status as preference_status,
      private.autoclair_offer_brand(v_vehicle.make) as vehicle_brand,
      private.autoclair_offer_normalize_words(v_vehicle.model)
        as vehicle_model,
      private.autoclair_offer_fuel(v_vehicle.fuel_type)
        as vehicle_fuel,
      case
        when v_vehicle.vehicle_year is null then null
        else greatest(
          0,
          extract(year from current_date)::integer
            - v_vehicle.vehicle_year
            - 1
        )
      end as vehicle_age_min,
      case
        when v_vehicle.vehicle_year is null then null
        else greatest(
          0,
          extract(year from current_date)::integer
            - v_vehicle.vehicle_year
        )
      end as vehicle_age_max,
      (
        '*' = any(o.brands)
        or private.autoclair_offer_brand(v_vehicle.make) = any(o.brands)
      ) as brand_match,
      (
        cardinality(o.model_patterns) = 0
        or exists (
          select 1
          from unnest(o.model_patterns) pattern
          where private.autoclair_offer_normalize_words(v_vehicle.model)
            like '%' ||
              private.autoclair_offer_normalize_words(pattern) ||
              '%'
        )
      ) as model_match,
      (
        cardinality(o.excluded_model_patterns) > 0
        and exists (
          select 1
          from unnest(o.excluded_model_patterns) pattern
          where private.autoclair_offer_normalize_words(v_vehicle.model)
            like '%' ||
              private.autoclair_offer_normalize_words(pattern) ||
              '%'
        )
      ) as model_excluded,
      (
        v_vehicle.fuel_type is null
        or cardinality(o.fuel_types) = 0
        or private.autoclair_offer_fuel(v_vehicle.fuel_type)
          = any(o.fuel_types)
      ) as fuel_match,
      (
        v_vehicle.fuel_type is not null
        and cardinality(o.excluded_fuel_types) > 0
        and private.autoclair_offer_fuel(v_vehicle.fuel_type)
          = any(o.excluded_fuel_types)
      ) as fuel_excluded,
      (
        (o.year_min is not null or o.year_max is not null
          or o.age_min is not null or o.age_max is not null)
        and v_vehicle.vehicle_year is null
      ) as age_information_missing,
      (
        v_vehicle.vehicle_year is not null
        and (
          (
            o.age_min is not null
            and greatest(
              0,
              extract(year from current_date)::integer
                - v_vehicle.vehicle_year
                - 1
            ) < o.age_min
            and greatest(
              0,
              extract(year from current_date)::integer
                - v_vehicle.vehicle_year
            ) >= o.age_min
          )
          or
          (
            o.age_max is not null
            and greatest(
              0,
              extract(year from current_date)::integer
                - v_vehicle.vehicle_year
                - 1
            ) <= o.age_max
            and greatest(
              0,
              extract(year from current_date)::integer
                - v_vehicle.vehicle_year
            ) > o.age_max
          )
        )
      ) as age_boundary_uncertain,
      (
        (o.mileage_min is not null or o.mileage_max is not null)
        and v_vehicle.mileage is null
      ) as mileage_information_missing,
      (
        cardinality(o.fuel_types) > 0
        and v_vehicle.fuel_type is null
      ) as fuel_information_missing,
      exists (
        select 1
        from public.vehicle_maintenance_schedules ms
        cross join unnest(o.schedule_keywords) keyword
        where ms.vehicle_id = v_vehicle.id
          and ms.status = 'ACTIVE'
          and (
            ms.priority = 'HIGH'
            or ms.due_date <= current_date + 90
            or (
              ms.due_mileage is not null
              and v_vehicle.mileage is not null
              and ms.due_mileage <= v_vehicle.mileage + 5000
            )
          )
          and private.autoclair_offer_normalize_words(
            concat_ws(' ', ms.title, ms.reason)
          ) like '%' ||
            private.autoclair_offer_normalize_words(keyword) ||
            '%'
      ) as schedule_match,
      exists (
        select 1
        from public.vehicle_events ve
        cross join unnest(o.schedule_keywords) keyword
        where ve.vehicle_id = v_vehicle.id
          and ve.status = 'COMPLETED'
          and ve.occurred_at >= now() - interval '120 days'
          and private.autoclair_offer_normalize_words(
            concat_ws(' ', ve.title, ve.description)
          ) like '%' ||
            private.autoclair_offer_normalize_words(keyword) ||
            '%'
      ) as recent_matching_event
    from public.commercial_offers o
    join public.commercial_offer_sources s on s.id = o.source_id
    left join public.vehicle_commercial_offer_preferences pref
      on pref.user_id = v_uid
     and pref.vehicle_id = v_vehicle.id
     and pref.offer_id = o.id
    where o.status = 'ACTIVE'
      and (o.starts_at is null or o.starts_at <= current_date)
      and (o.ends_at is null or o.ends_at >= current_date)
      and o.last_verified_at >= now() - interval '14 days'
      and s.status in ('ACTIVE', 'ERROR')
      and s.last_success_at >= now() - interval '14 days'
      and coalesce(pref.status, '') <> 'DISMISSED'
  ),
  eligible as (
    select *
    from base
    where brand_match
      and model_match
      and not model_excluded
      and fuel_match
      and not fuel_excluded
      and (
        v_vehicle.vehicle_year is null
        or (year_min is null or v_vehicle.vehicle_year >= year_min)
      )
      and (
        v_vehicle.vehicle_year is null
        or (year_max is null or v_vehicle.vehicle_year <= year_max)
      )
      and (
        vehicle_age_max is null
        or age_min is null
        or vehicle_age_max >= age_min
      )
      and (
        vehicle_age_min is null
        or age_max is null
        or vehicle_age_min <= age_max
      )
      and (
        v_vehicle.mileage is null
        or (mileage_min is null or v_vehicle.mileage >= mileage_min)
      )
      and (
        v_vehicle.mileage is null
        or (mileage_max is null or v_vehicle.mileage <= mileage_max)
      )
  ),
  scored as (
    select
      eligible.*,
      greatest(
        0,
        least(
          100,
          48
          + case when '*' <> all(brands) then 10 else 0 end
          + case when cardinality(model_patterns) > 0 then 10 else 3 end
          + case
              when not age_information_missing
               and not age_boundary_uncertain
               and not mileage_information_missing
               and not fuel_information_missing
                then 8
              else 0
            end
          + case when schedule_match then 22 else 0 end
          + case when preference_status = 'SAVED' then 4 else 0 end
          + case
              when ends_at between current_date and current_date + 14
                then 3
              else 0
            end
          - case when recent_matching_event then 18 else 0 end
          - case when requires_manual_eligibility then 8 else 0 end
          - case when requires_existing_contract then 8 else 0 end
        )
      )::integer as relevance_score,
      (
        schedule_match
        and not recent_matching_event
      ) as relevant_now,
      (
        ends_at between current_date and current_date + 14
      ) as expires_soon,
      case
        when age_information_missing
          or age_boundary_uncertain
          or mileage_information_missing
          or fuel_information_missing
          or requires_manual_eligibility
          or requires_existing_contract
          then 'CHECK'
        when '*' = any(brands)
          or requires_network_participation
          then 'LIKELY'
        else 'COMPATIBLE'
      end as compatibility
    from eligible
  ),
  limited as (
    select *
    from scored
    order by
      relevant_now desc,
      (preference_status = 'SAVED') desc,
      relevance_score desc,
      ends_at asc nulls last,
      title asc
    limit v_limit
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', id,
        'offer_key', offer_key,
        'title', title,
        'summary', summary,
        'category', category,
        'benefit_kind', benefit_kind,
        'benefit_label', benefit_label,
        'benefit_value', benefit_value,
        'price_amount', price_amount,
        'original_price_amount', original_price_amount,
        'currency', currency,
        'starts_at', starts_at,
        'ends_at', ends_at,
        'source_name', source_name,
        'official_url', official_url,
        'conditions_summary', conditions_summary,
        'eligibility_notes', eligibility_notes,
        'compatibility', compatibility,
        'relevance_label', case
          when relevance_score >= 80 then 'Très pertinente'
          when relevance_score >= 65 then 'Pertinente'
          when relevance_score >= 50 then 'À considérer'
          else 'À vérifier'
        end,
        'relevance_score', relevance_score,
        'relevant_now', relevant_now,
        'expires_soon', expires_soon,
        'is_saved', preference_status = 'SAVED',
        'why', to_jsonb(
          array_remove(
            array[
              case
                when cardinality(model_patterns) > 0
                  then 'Le modèle du véhicule correspond à cette campagne'
                when '*' <> all(brands)
                  then 'La marque du véhicule correspond à cette campagne'
                else 'Cette offre est annoncée pour plusieurs marques'
              end,
              case
                when schedule_match
                  then 'Une échéance du carnet correspond à cette offre'
                else null
              end,
              case
                when recent_matching_event
                  then 'Une opération similaire a été enregistrée récemment'
                else null
              end,
              case
                when age_information_missing
                  then 'L’année du véhicule doit être renseignée ou confirmée'
                when age_boundary_uncertain
                  then 'La date exacte de première mise en circulation doit être confirmée'
                when year_min is not null
                  or year_max is not null
                  or age_min is not null
                  or age_max is not null
                  then 'La condition d’âge connue est respectée'
                else null
              end,
              case
                when mileage_information_missing
                  then 'Le kilométrage doit être renseigné ou confirmé'
                when mileage_min is not null
                  or mileage_max is not null
                  then 'La condition de kilométrage connue est respectée'
                else null
              end,
              case
                when requires_existing_contract
                  then 'Un contrat d’entretien valide doit être confirmé'
                when requires_network_participation
                  then 'La participation du réseau doit être confirmée'
                else null
              end
            ]::text[],
            null
          )
        ),
        'requires_manual_eligibility',
          requires_manual_eligibility,
        'requires_network_participation',
          requires_network_participation,
        'requires_existing_contract',
          requires_existing_contract,
        'last_verified_at', last_verified_at
      )
      order by
        relevant_now desc,
        (preference_status = 'SAVED') desc,
        relevance_score desc,
        ends_at asc nulls last,
        title asc
    ),
    '[]'::jsonb
  )
  into v_offers
  from limited;

  return jsonb_build_object(
    'vehicle_id', v_vehicle.id,
    'vehicle_name', trim(
      concat_ws(' ', v_vehicle.make, v_vehicle.model)
    ),
    'offers', v_offers,
    'active_source_count', v_active_source_count,
    'active_offer_count', v_active_offer_count,
    'last_successful_sync_at', v_last_sync,
    'generated_at', now()
  );
end
$function$;

create or replace function public.set_vehicle_commercial_offer_preference(
  p_vehicle_id uuid,
  p_offer_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_status text := upper(coalesce(trim(p_status), ''));
begin
  if v_uid is null then
    raise exception 'COMMERCIAL_OFFERS_AUTH_REQUIRED';
  end if;

  if not exists (
    select 1
    from public.vehicles v
    where v.id = p_vehicle_id
      and v.user_id = v_uid
  ) then
    raise exception 'COMMERCIAL_OFFERS_VEHICLE_NOT_FOUND';
  end if;

  if not exists (
    select 1
    from public.commercial_offers o
    where o.id = p_offer_id
      and o.status = 'ACTIVE'
      and (o.starts_at is null or o.starts_at <= current_date)
      and (o.ends_at is null or o.ends_at >= current_date)
  ) then
    raise exception 'COMMERCIAL_OFFERS_OFFER_NOT_FOUND';
  end if;

  if v_status = 'NONE' then
    delete from public.vehicle_commercial_offer_preferences p
    where p.user_id = v_uid
      and p.vehicle_id = p_vehicle_id
      and p.offer_id = p_offer_id;
    return;
  end if;

  if v_status not in ('SAVED', 'DISMISSED') then
    raise exception 'COMMERCIAL_OFFERS_STATUS_INVALID';
  end if;

  insert into public.vehicle_commercial_offer_preferences (
    user_id,
    vehicle_id,
    offer_id,
    status,
    updated_at
  )
  values (
    v_uid,
    p_vehicle_id,
    p_offer_id,
    v_status,
    now()
  )
  on conflict (user_id, vehicle_id, offer_id) do update set
    status = excluded.status,
    updated_at = now();
end
$function$;

create or replace function public.reset_vehicle_offer_dismissals(
  p_vehicle_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_count integer;
begin
  if v_uid is null then
    raise exception 'COMMERCIAL_OFFERS_AUTH_REQUIRED';
  end if;

  if not exists (
    select 1
    from public.vehicles v
    where v.id = p_vehicle_id
      and v.user_id = v_uid
  ) then
    raise exception 'COMMERCIAL_OFFERS_VEHICLE_NOT_FOUND';
  end if;

  delete from public.vehicle_commercial_offer_preferences p
  where p.user_id = v_uid
    and p.vehicle_id = p_vehicle_id
    and p.status = 'DISMISSED';

  get diagnostics v_count = row_count;
  return v_count;
end
$function$;

create or replace function public.validate_commercial_offer_sync_secret(
  p_candidate text
)
returns boolean
language sql
security definer
set search_path = ''
as $function$
  select coalesce(
    extensions.digest(coalesce(p_candidate, ''), 'sha256') =
    extensions.digest(
      coalesce(
        (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'commercial_offers_sync_secret'
          order by created_at desc
          limit 1
        ),
        ''
      ),
      'sha256'
    ),
    false
  );
$function$;

create or replace function public.acquire_commercial_offer_sync_lock()
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_updated_count integer := 0;
begin
  update public.commercial_offer_sync_state s
  set
    locked_until = now() + interval '15 minutes',
    last_started_at = now(),
    updated_at = now()
  where s.state_key = 'GLOBAL'
    and (
      s.locked_until is null
      or s.locked_until < now()
    );

  get diagnostics v_updated_count = row_count;
  return v_updated_count > 0;
end
$function$;

create or replace function public.release_commercial_offer_sync_lock()
returns void
language sql
security definer
set search_path = ''
as $function$
  update public.commercial_offer_sync_state
  set
    locked_until = null,
    last_finished_at = now(),
    updated_at = now()
  where state_key = 'GLOBAL';
$function$;

revoke all
  on function public.get_vehicle_commercial_offers(uuid, integer)
  from public, anon;
revoke all
  on function public.set_vehicle_commercial_offer_preference(
    uuid,
    uuid,
    text
  )
  from public, anon;
revoke all
  on function public.reset_vehicle_offer_dismissals(uuid)
  from public, anon;
revoke all
  on function public.validate_commercial_offer_sync_secret(text)
  from public, anon, authenticated;
revoke all
  on function public.acquire_commercial_offer_sync_lock()
  from public, anon, authenticated;
revoke all
  on function public.release_commercial_offer_sync_lock()
  from public, anon, authenticated;

grant execute
  on function public.get_vehicle_commercial_offers(uuid, integer)
  to authenticated, service_role;
grant execute
  on function public.set_vehicle_commercial_offer_preference(
    uuid,
    uuid,
    text
  )
  to authenticated, service_role;
grant execute
  on function public.reset_vehicle_offer_dismissals(uuid)
  to authenticated, service_role;
grant execute
  on function public.validate_commercial_offer_sync_secret(text)
  to service_role;
grant execute
  on function public.acquire_commercial_offer_sync_lock()
  to service_role;
grant execute
  on function public.release_commercial_offer_sync_lock()
  to service_role;

comment on table public.commercial_offers is
  'Faits structurés issus de pages officielles. Aucun texte commercial '
  'intégral ni visuel propriétaire n’est conservé.';

comment on table public.commercial_offer_candidates is
  'Blocs nouvellement détectés, placés en quarantaine et jamais affichés '
  'avant validation d’une règle fiable.';

comment on function public.get_vehicle_commercial_offers(uuid, integer) is
  'Retourne uniquement les offres actives, fraîches et compatibles avec le '
  'véhicule de l’utilisateur, avec un score explicable.';

do $vault$
declare
  v_secret text;
begin
  if not exists (
    select 1
    from vault.secrets
    where name = 'commercial_offers_sync_secret'
  ) then
    v_secret := encode(extensions.gen_random_bytes(32), 'hex');

    perform vault.create_secret(
      v_secret,
      'commercial_offers_sync_secret',
      'Secret interne du cron AutoClair Offres utiles'
    );
  end if;

  if not exists (
    select 1
    from vault.secrets
    where name = 'autoclair_project_url'
  ) then
    perform vault.create_secret(
      'https://zkzocdtxebacxcrkrkzu.supabase.co',
      'autoclair_project_url',
      'URL du projet Supabase AutoClair'
    );
  end if;
end
$vault$;

do $cron_setup$
begin
  if exists (
    select 1
    from cron.job
    where jobname = 'autoclair-sync-commercial-offers'
  ) then
    perform cron.unschedule('autoclair-sync-commercial-offers');
  end if;
end
$cron_setup$;

select cron.schedule(
  'autoclair-sync-commercial-offers',
  '25 4 * * *',
  $cron$
  select net.http_post(
    url := (
      select decrypted_secret
      from vault.decrypted_secrets
      where name = 'autoclair_project_url'
      order by created_at desc
      limit 1
    ) || '/functions/v1/sync-commercial-offers',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-sync-secret', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'commercial_offers_sync_secret'
        order by created_at desc
        limit 1
      )
    ),
    body := jsonb_build_object(
      'trigger', 'scheduled',
      'force', false
    )
  );
  $cron$
);

select net.http_post(
  url := (
    select decrypted_secret
    from vault.decrypted_secrets
    where name = 'autoclair_project_url'
    order by created_at desc
    limit 1
  ) || '/functions/v1/sync-commercial-offers',
  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'x-sync-secret', (
      select decrypted_secret
      from vault.decrypted_secrets
      where name = 'commercial_offers_sync_secret'
      order by created_at desc
      limit 1
    )
  ),
  body := jsonb_build_object(
    'trigger', 'installation',
    'force', true
  )
);

commit;
