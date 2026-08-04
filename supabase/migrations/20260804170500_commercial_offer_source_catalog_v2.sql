begin;

do $precheck$
declare
  v_missing text[] := array[]::text[];
begin
  if to_regclass('public.commercial_offer_sources') is null then
    v_missing := array_append(
      v_missing,
      'public.commercial_offer_sources'
    );
  end if;

  if to_regclass('public.commercial_offers') is null then
    v_missing := array_append(
      v_missing,
      'public.commercial_offers'
    );
  end if;

  if to_regclass('public.commercial_offer_candidates') is null then
    v_missing := array_append(
      v_missing,
      'public.commercial_offer_candidates'
    );
  end if;

  if to_regclass('public.commercial_offer_sync_runs') is null then
    v_missing := array_append(
      v_missing,
      'public.commercial_offer_sync_runs'
    );
  end if;

  if to_regprocedure(
    'public.validate_commercial_offer_sync_secret(text)'
  ) is null then
    v_missing := array_append(
      v_missing,
      'public.validate_commercial_offer_sync_secret'
    );
  end if;

  if cardinality(v_missing) > 0 then
    raise exception
      'COMMERCIAL_SOURCE_CATALOG_PRECHECK_FAILED:%',
      array_to_string(v_missing, ',');
  end if;
end
$precheck$;

alter table public.commercial_offer_sources
  add column if not exists operator_name text,
  add column if not exists source_category text
    not null default 'OTHER',
  add column if not exists source_purpose text
    not null default 'CURRENT_VEHICLE',
  add column if not exists endpoint_type text
    not null default 'HOME_OR_CATALOG',
  add column if not exists trust_tier text
    not null default 'PRIMARY',
  add column if not exists monitoring_mode text
    not null default 'HTML_RULES',
  add column if not exists publication_policy text
    not null default 'VALIDATED_RULES_ONLY',
  add column if not exists search_enabled boolean
    not null default false,
  add column if not exists search_priority integer
    not null default 50,
  add column if not exists check_frequency_hours integer
    not null default 72,
  add column if not exists next_check_at timestamptz,
  add column if not exists territory_code text
    not null default 'FR',
  add column if not exists report_reference text,
  add column if not exists report_line integer,
  add column if not exists report_section text;

update public.commercial_offer_sources
set operator_name = source_name
where operator_name is null;

alter table public.commercial_offer_sources
  alter column operator_name set not null;

do $constraints$
begin
  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'commercial_offer_sources_category_allowed'
      and conrelid = 'public.commercial_offer_sources'::regclass
  ) then
    alter table public.commercial_offer_sources
      add constraint commercial_offer_sources_category_allowed
      check (
        source_category in (
          'OFFICIAL_MANUFACTURER',
          'OFFICIAL_USED',
          'OFFICIAL_SERVICE_FINANCE',
          'DEALER_GROUP',
          'VEHICLE_MARKETPLACE',
          'VEHICLE_COMPARATOR',
          'COMMUNITY_DEALS',
          'AFTER_SALES_NETWORK',
          'GARAGE_COMPARATOR',
          'PARTS_TYRES',
          'ASSISTANCE_INSURANCE',
          'GENERAL_MARKETPLACE',
          'INSTITUTIONAL_REFERENCE',
          'OTHER'
        )
      );
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'commercial_offer_sources_purpose_allowed'
      and conrelid = 'public.commercial_offer_sources'::regclass
  ) then
    alter table public.commercial_offer_sources
      add constraint commercial_offer_sources_purpose_allowed
      check (
        source_purpose in (
          'CURRENT_VEHICLE',
          'VEHICLE_PURCHASE',
          'FINANCE_INSURANCE',
          'REFERENCE_ONLY',
          'DISCOVERY_ONLY',
          'OTHER'
        )
      );
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'commercial_offer_sources_endpoint_allowed'
      and conrelid = 'public.commercial_offer_sources'::regclass
  ) then
    alter table public.commercial_offer_sources
      add constraint commercial_offer_sources_endpoint_allowed
      check (
        endpoint_type in (
          'HOME_OR_CATALOG',
          'OFFERS',
          'AFTER_SALES',
          'FINANCE',
          'NEW_STOCK',
          'USED_OR_STOCK',
          'REFERENCE'
        )
      );
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'commercial_offer_sources_trust_allowed'
      and conrelid = 'public.commercial_offer_sources'::regclass
  ) then
    alter table public.commercial_offer_sources
      add constraint commercial_offer_sources_trust_allowed
      check (
        trust_tier in (
          'PRIMARY',
          'PROFESSIONAL',
          'COMMUNITY_OR_MARKETPLACE'
        )
      );
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'commercial_offer_sources_monitoring_allowed'
      and conrelid = 'public.commercial_offer_sources'::regclass
  ) then
    alter table public.commercial_offer_sources
      add constraint commercial_offer_sources_monitoring_allowed
      check (
        monitoring_mode in (
          'HTML_RULES',
          'HTML_DISCOVERY',
          'LINK_DISCOVERY_ONLY',
          'ADAPTER_REQUIRED',
          'REFERENCE_ONLY',
          'DISABLED_BY_POLICY'
        )
      );
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'commercial_offer_sources_publication_allowed'
      and conrelid = 'public.commercial_offer_sources'::regclass
  ) then
    alter table public.commercial_offer_sources
      add constraint commercial_offer_sources_publication_allowed
      check (
        publication_policy in (
          'VALIDATED_RULES_ONLY',
          'QUARANTINE_ONLY',
          'REFERENCE_ONLY'
        )
      );
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'commercial_offer_sources_schedule_valid'
      and conrelid = 'public.commercial_offer_sources'::regclass
  ) then
    alter table public.commercial_offer_sources
      add constraint commercial_offer_sources_schedule_valid
      check (
        search_priority between 1 and 100
        and check_frequency_hours between 6 and 720
      );
  end if;
end
$constraints$;

create index if not exists commercial_offer_sources_due_idx
  on public.commercial_offer_sources(
    search_enabled,
    next_check_at,
    search_priority
  )
  where search_enabled = true;

alter table public.commercial_offer_sync_runs
  add column if not exists discovered_url_count integer
    not null default 0;

create table if not exists public.commercial_offer_discovered_urls (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null
    references public.commercial_offer_sources(id) on delete cascade,
  url_hash text not null,
  discovered_url text not null,
  link_title text not null default '',
  discovery_score integer not null default 0,
  status text not null default 'PENDING_REVIEW',
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  unique (source_id, url_hash),
  constraint commercial_offer_discovered_urls_score_valid
    check (discovery_score between 0 and 100),
  constraint commercial_offer_discovered_urls_status_allowed
    check (
      status in (
        'PENDING_REVIEW',
        'APPROVED',
        'REJECTED',
        'OBSOLETE'
      )
    )
);

create index if not exists commercial_offer_discovered_urls_status_idx
  on public.commercial_offer_discovered_urls(
    status,
    discovery_score desc,
    last_seen_at desc
  );

alter table public.commercial_offer_discovered_urls
  enable row level security;

revoke all
  on table public.commercial_offer_discovered_urls
  from public, anon, authenticated;

grant select, insert, update, delete
  on table public.commercial_offer_discovered_urls
  to service_role;

update public.commercial_offer_sources
set
  operator_name = case source_key
    when 'volkswagen_fr_after_sales' then 'Volkswagen France'
    when 'renault_fr_care_service' then 'Renault Care Service'
    when 'peugeot_fr_after_sales' then 'Peugeot France'
    when 'citroen_fr_after_sales' then 'Citroën France'
    else operator_name
  end,
  source_category = 'OFFICIAL_SERVICE_FINANCE',
  source_purpose = 'CURRENT_VEHICLE',
  endpoint_type = 'AFTER_SALES',
  trust_tier = 'PRIMARY',
  monitoring_mode = 'HTML_RULES',
  publication_policy = 'VALIDATED_RULES_ONLY',
  search_enabled = true,
  search_priority = 1,
  check_frequency_hours = 24,
  next_check_at = coalesce(next_check_at, now()),
  territory_code = 'FR'
where source_key in (
  'volkswagen_fr_after_sales',
  'renault_fr_care_service',
  'peugeot_fr_after_sales',
  'citroen_fr_after_sales'
);

with source_catalog (
  source_key,
  brand_code,
  source_name,
  operator_name,
  source_url,
  allowed_hostnames,
  source_category,
  source_purpose,
  endpoint_type,
  trust_tier,
  monitoring_mode,
  publication_policy,
  search_enabled,
  search_priority,
  check_frequency_hours,
  territory_code,
  report_reference,
  report_line,
  report_section
) as (
  values
    ('report_renault_france_e1c4e792fa','renault_france','Renault France','Renault France','https://www.renault.fr/',array['renault.fr','www.renault.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',44,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_renault_france_07b5513ed6','renault_france','Renault France — offres','Renault France','https://www.renault.fr/offres-vehicules.html',array['renault.fr','www.renault.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','OFFERS','PRIMARY','HTML_DISCOVERY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',44,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_renault_france_249810a469','renault_france','Renault France — stock','Renault France','https://www.renault.fr/achat-vehicules-neufs.html',array['renault.fr','www.renault.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','NEW_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',44,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_dacia_france_4e4ccf7035','dacia_france','Dacia France','Dacia France','https://www.dacia.fr/',array['dacia.fr','www.dacia.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',45,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_dacia_france_5794a18e26','dacia_france','Dacia France — offres','Dacia France','https://www.dacia.fr/offres/offres-du-moment.html',array['dacia.fr','www.dacia.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','OFFERS','PRIMARY','HTML_DISCOVERY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',45,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_dacia_france_6d9849c548','dacia_france','Dacia France — stock','Dacia France','https://www.dacia.fr/achat-vehicules-neufs.html',array['dacia.fr','www.dacia.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','NEW_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',45,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_peugeot_france_25ca38973e','peugeot_france','Peugeot France','Peugeot France','https://www.peugeot.fr/',array['peugeot.fr','www.peugeot.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',46,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_peugeot_france_326a60729d','peugeot_france','Peugeot France — offres','Peugeot France','https://www.peugeot.fr/offres.html',array['peugeot.fr','www.peugeot.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','OFFERS','PRIMARY','HTML_DISCOVERY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',46,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_peugeot_france_6bd4cae0bf','peugeot_france','Peugeot France — Peugeot Store','Peugeot France','https://store.peugeot.fr/',array['store.peugeot.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','NEW_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',46,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_citroen_france_93d19721cb','citroen_france','Citroën France','Citroën France','https://www.citroen.fr/',array['citroen.fr','www.citroen.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',47,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_citroen_france_b1ff314733','citroen_france','Citroën France — offres','Citroën France','https://www.citroen.fr/acheter/offres.html',array['citroen.fr','www.citroen.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','OFFERS','PRIMARY','HTML_DISCOVERY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',47,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_citroen_france_9d28cfadec','citroen_france','Citroën France — Citroën Store','Citroën France','https://store.citroen.fr/',array['store.citroen.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','NEW_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',47,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_ds_automobiles_dc883cdd9d','ds_automobiles','DS Automobiles','DS Automobiles','https://www.dsautomobiles.fr/',array['dsautomobiles.fr','www.dsautomobiles.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',48,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_alpine_5258dde0d9','alpine','Alpine','Alpine','https://www.alpinecars.fr/',array['alpinecars.fr','www.alpinecars.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',49,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_opel_france_42ebef308a','opel_france','Opel France','Opel France','https://www.opel.fr/',array['opel.fr','www.opel.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',50,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_opel_france_4404bea1bc','opel_france','Opel France — offres','Opel France','https://www.opel.fr/offres/offres-opel.html',array['opel.fr','www.opel.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','OFFERS','PRIMARY','HTML_DISCOVERY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',50,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_opel_france_c7d7723069','opel_france','Opel France — stock','Opel France','https://store.opel.fr/',array['store.opel.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','NEW_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',50,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_fiat_france_640c838393','fiat_france','Fiat France','Fiat France','https://www.fiat.fr/',array['fiat.fr','www.fiat.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',51,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_abarth_france_1185e8a46d','abarth_france','Abarth France','Abarth France','https://www.abarth.fr/',array['abarth.fr','www.abarth.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',52,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_alfa_romeo_france_85860465a3','alfa_romeo_france','Alfa Romeo France','Alfa Romeo France','https://www.alfaromeo.fr/',array['alfaromeo.fr','www.alfaromeo.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',53,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_alfa_romeo_france_3394b01f90','alfa_romeo_france','Alfa Romeo France — offres','Alfa Romeo France','https://www.alfaromeo.fr/offres',array['alfaromeo.fr','www.alfaromeo.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','OFFERS','PRIMARY','HTML_DISCOVERY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',53,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_jeep_france_b4e01d02ca','jeep_france','Jeep France','Jeep France','https://www.jeep.fr/',array['jeep.fr','www.jeep.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',54,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_jeep_france_46653f6e1a','jeep_france','Jeep France — offres','Jeep France','https://www.jeep.fr/offres-suv-4x4',array['jeep.fr','www.jeep.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','OFFERS','PRIMARY','HTML_DISCOVERY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',54,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_jeep_france_d5f34d679a','jeep_france','Jeep France — stock','Jeep France','https://www.jeep.fr/nouveaux-suvs-en-stock',array['jeep.fr','www.jeep.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','NEW_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',54,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_lancia_france_d39c29e8bb','lancia_france','Lancia France','Lancia France','https://www.lancia.fr/',array['lancia.fr','www.lancia.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',55,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_ford_france_642b6591b3','ford_france','Ford France','Ford France','https://www.ford.fr/',array['ford.fr','www.ford.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',56,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_volkswagen_france_18c0ba2df6','volkswagen_france','Volkswagen France','Volkswagen France','https://www.volkswagen.fr/fr.html',array['volkswagen.fr','www.volkswagen.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',57,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_volkswagen_france_07d9b133f9','volkswagen_france','Volkswagen France — offres','Volkswagen France','https://www.volkswagen.fr/fr/acheter/offres.html',array['volkswagen.fr','www.volkswagen.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','OFFERS','PRIMARY','HTML_DISCOVERY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',57,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_volkswagen_france_3bf2fda1fd','volkswagen_france','Volkswagen France — stock','Volkswagen France','https://www.volkswagen.fr/fr/acheter/voitures-en-stock.html',array['volkswagen.fr','www.volkswagen.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','NEW_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',57,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_volkswagen_vehicules_utilitaires_cfed2fe768','volkswagen_vehicules_utilitair','Volkswagen Véhicules Utilitaires','Volkswagen Véhicules Utilitaires','https://www.volkswagen-utilitaires.fr/fr.html',array['volkswagen-utilitaires.fr','www.volkswagen-utilitaires.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',58,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_audi_france_f6a58352ca','audi_france','Audi France','Audi France','https://www.audi.fr/',array['audi.fr','www.audi.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',59,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_audi_france_da70c5c02d','audi_france','Audi France — offres','Audi France','https://www.audi.fr/fr/offres-audi',array['audi.fr','www.audi.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','OFFERS','PRIMARY','HTML_DISCOVERY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',59,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_skoda_france_59729cf6fd','skoda_france','Škoda France','Škoda France','https://www.skoda.fr/',array['skoda.fr','www.skoda.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',60,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_seat_france_a8a56aadfe','seat_france','SEAT France','SEAT France','https://www.seat.fr/',array['seat.fr','www.seat.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',61,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_cupra_france_e2a873239c','cupra_france','CUPRA France','CUPRA France','https://www.cupraofficial.fr/',array['cupraofficial.fr','www.cupraofficial.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',62,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_bmw_france_1433d9a882','bmw_france','BMW France','BMW France','https://www.bmw.fr/fr/accueil.html',array['bmw.fr','www.bmw.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',63,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_bmw_france_110505b75c','bmw_france','BMW France — offres','BMW France','https://www.bmw.fr/fr/Shop-Online/offres-exclusives.html',array['bmw.fr','www.bmw.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','OFFERS','PRIMARY','HTML_DISCOVERY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',63,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_mini_france_5152015c40','mini_france','MINI France','MINI France','https://www.mini.fr/',array['mini.fr','www.mini.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',64,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_mercedes_benz_france_bd7574bc67','mercedes_benz_france','Mercedes-Benz France','Mercedes-Benz France','https://www.mercedes-benz.fr/',array['mercedes-benz.fr','www.mercedes-benz.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',65,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_mercedes_benz_france_9b19716460','mercedes_benz_france','Mercedes-Benz France — configurateur et stock','Mercedes-Benz France','https://www.mercedes-benz.fr/passengercars/configurator.html',array['mercedes-benz.fr','www.mercedes-benz.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','NEW_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',65,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_smart_france_8628299494','smart_france','smart France','smart France','https://fr.smart.com/',array['fr.smart.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',66,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_porsche_france_04ddacf192','porsche_france','Porsche France','Porsche France','https://www.porsche.com/france',array['porsche.com','www.porsche.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',67,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_porsche_france_d14fc5ba37','porsche_france','Porsche France — Porsche Finder','Porsche France','https://finder.porsche.com/fr/fr-FR',array['finder.porsche.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','USED_OR_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',67,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_toyota_france_2e9898de6c','toyota_france','Toyota France','Toyota France','https://www.toyota.fr/',array['toyota.fr','www.toyota.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',68,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_lexus_france_0912699bfd','lexus_france','Lexus France','Lexus France','https://www.lexus.fr/',array['lexus.fr','www.lexus.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',69,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_nissan_france_3420bc726a','nissan_france','Nissan France','Nissan France','https://www.nissan.fr/',array['nissan.fr','www.nissan.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',70,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_honda_france_e0219affc4','honda_france','Honda France','Honda France','https://auto.honda.fr/',array['auto.honda.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',71,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_mazda_france_a4e60c7e14','mazda_france','Mazda France','Mazda France','https://www.mazda.fr/',array['mazda.fr','www.mazda.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',72,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_mitsubishi_motors_france_dab4f04e94','mitsubishi_motors_france','Mitsubishi Motors France','Mitsubishi Motors France','https://www.mitsubishi-motors.fr/',array['mitsubishi-motors.fr','www.mitsubishi-motors.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',73,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_suzuki_france_40ed4da15b','suzuki_france','Suzuki France','Suzuki France','https://www.suzuki.fr/automobile',array['suzuki.fr','www.suzuki.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',74,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_subaru_france_cc8c55ec43','subaru_france','Subaru France','Subaru France','https://www.subaru.fr/',array['subaru.fr','www.subaru.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',75,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_isuzu_france_cf9e8d660f','isuzu_france','Isuzu France','Isuzu France','https://www.isuzu.fr/',array['isuzu.fr','www.isuzu.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',76,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_hyundai_france_d60d471730','hyundai_france','Hyundai France','Hyundai France','https://www.hyundai.com/fr/fr.html',array['hyundai.com','www.hyundai.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',77,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_kia_france_2eb0f074ae','kia_france','Kia France','Kia France','https://www.kia.com/fr',array['kia.com','www.kia.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',78,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_volvo_cars_france_70bb329f20','volvo_cars_france','Volvo Cars France','Volvo Cars France','https://www.volvocars.com/fr',array['volvocars.com','www.volvocars.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',79,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_jaguar_france_ca5ff73d50','jaguar_france','Jaguar France','Jaguar France','https://www.jaguar.fr/',array['jaguar.fr','www.jaguar.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',80,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_land_rover_france_9740131b7d','land_rover_france','Land Rover France','Land Rover France','https://www.landrover.fr/',array['landrover.fr','www.landrover.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',81,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_tesla_france_1d42a3420f','tesla_france','Tesla France','Tesla France','https://www.tesla.com/fr_fr',array['tesla.com','www.tesla.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',82,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_tesla_france_5712d1b4f1','tesla_france','Tesla France — inventaire','Tesla France','https://www.tesla.com/fr_FR/inventory/new/m3',array['tesla.com','www.tesla.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','USED_OR_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',82,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_mg_motor_france_c4aa8cdfd8','mg_motor_france','MG Motor France','MG Motor France','https://www.mgmotor.fr/',array['mgmotor.fr','www.mgmotor.fr']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',83,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_byd_france_89cfec88da','byd_france','BYD France','BYD France','https://www.byd.com/fr',array['byd.com','www.byd.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',84,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_leapmotor_france_a79250889a','leapmotor_france','Leapmotor France','Leapmotor France','https://www.leapmotor.net/fr',array['leapmotor.net','www.leapmotor.net']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',85,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_xpeng_france_2345927496','xpeng_france','XPENG France','XPENG France','https://www.xpeng.com/fr',array['www.xpeng.com','xpeng.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',86,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_polestar_france_dd84d2b559','polestar_france','Polestar France','Polestar France','https://www.polestar.com/fr',array['polestar.com','www.polestar.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',87,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_lynk_co_france_7d65a77d6c','lynk_co_france','Lynk & Co France','Lynk & Co France','https://www.lynkco.com/fr-fr',array['lynkco.com','www.lynkco.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',88,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_ineos_grenadier_france_3c190bc934','ineos_grenadier_france','INEOS Grenadier France','INEOS Grenadier France','https://ineosgrenadier.com/fr/fr',array['ineosgrenadier.com','www.ineosgrenadier.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',89,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_lotus_france_e989a03693','lotus_france','Lotus France','Lotus France','https://www.lotuscars.com/fr-FR',array['lotuscars.com','www.lotuscars.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',90,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_maserati_france_02a92cf50a','maserati_france','Maserati France','Maserati France','https://www.maserati.com/fr/fr',array['maserati.com','www.maserati.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',91,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_aston_martin_france_74984500d3','aston_martin_france','Aston Martin France','Aston Martin France','https://www.astonmartin.com/fr',array['astonmartin.com','www.astonmartin.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',92,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_bentley_motors_france_fa3c055da1','bentley_motors_france','Bentley Motors France','Bentley Motors France','https://www.bentleymotors.com/fr/fr.html',array['bentleymotors.com','www.bentleymotors.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',93,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_ferrari_france_f4bb3e8540','ferrari_france','Ferrari France','Ferrari France','https://www.ferrari.com/fr-FR',array['ferrari.com','www.ferrari.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',94,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_lamborghini_france_77ae86671d','lamborghini_france','Lamborghini France','Lamborghini France','https://www.lamborghini.com/fr-en',array['lamborghini.com','www.lamborghini.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',95,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_mclaren_france_da6c25b5ec','mclaren_france','McLaren France','McLaren France','https://cars.mclaren.com/fr-fr',array['cars.mclaren.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',96,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_rolls_royce_motor_cars_95b62ef241','rolls_royce_motor_cars','Rolls-Royce Motor Cars','Rolls-Royce Motor Cars','https://www.rolls-roycemotorcars.com/',array['rolls-roycemotorcars.com','www.rolls-roycemotorcars.com']::text[],'OFFICIAL_MANUFACTURER','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',true,10,72,'FR','deep-research-report.md',97,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Marques généralistes et premium à diffusion nationale'),
    ('report_renew_43352df5d3','renew','Renew','Renew','https://occasion.renault.fr/',array['occasion.renault.fr']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','USED_OR_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',105,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_dacia_occasion_9342d8c141','dacia_occasion','Dacia Occasion','Dacia Occasion','https://www.dacia.fr/vehicules-occasion-dacia.html',array['dacia.fr','www.dacia.fr']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','USED_OR_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',106,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_spoticar_58a0b6b6a1','spoticar','Spoticar','Spoticar','https://www.spoticar.fr/',array['spoticar.fr','www.spoticar.fr']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',107,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_alfa_romeo_certified_2d7cf26713','alfa_romeo_certified','Alfa Romeo Certified','Alfa Romeo Certified','https://www.certified.alfaromeo.fr/',array['certified.alfaromeo.fr','www.certified.alfaromeo.fr']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',108,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_audi_occasion_plus_fa4ae28c70','audi_occasion_plus','Audi Occasion :plus','Audi Occasion :plus','https://www.audi.fr/fr/acheter/audi-occasion-plus',array['audi.fr','www.audi.fr']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','USED_OR_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',109,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_bmw_premium_selection_8bd949fa40','bmw_premium_selection','BMW Premium Selection','BMW Premium Selection','https://occasion.bmw.fr/',array['occasion.bmw.fr']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','USED_OR_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',110,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_mini_next_a65b88cc97','mini_next','MINI Next','MINI Next','https://occasion.mini.fr/',array['occasion.mini.fr']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','USED_OR_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',111,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_mercedes_benz_certified_e001fd9f93','mercedes_benz_certified','Mercedes-Benz Certified','Mercedes-Benz Certified','https://occasion.mercedes-benz.fr/',array['occasion.mercedes-benz.fr']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','USED_OR_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',112,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_volkswagen_occasions_17515524e2','volkswagen_occasions','Volkswagen Occasions','Volkswagen Occasions','https://occasion.volkswagen.fr/',array['occasion.volkswagen.fr']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','USED_OR_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',113,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_skoda_plus_eea326715f','skoda_plus','Škoda Plus','Škoda Plus','https://occasion.skoda.fr/',array['occasion.skoda.fr']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','USED_OR_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',114,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_seat_occasion_8510903e4e','seat_occasion','SEAT Occasion','SEAT Occasion','https://occasion.seat.fr/',array['occasion.seat.fr']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','USED_OR_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',115,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_cupra_occasion_f9fd8ff4df','cupra_occasion','CUPRA Occasion','CUPRA Occasion','https://occasion.cupraofficial.fr/',array['occasion.cupraofficial.fr']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','USED_OR_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',116,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_toyota_occasions_e3f4c52e2e','toyota_occasions','Toyota Occasions','Toyota Occasions','https://www.toyota.fr/occasions',array['toyota.fr','www.toyota.fr']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','USED_OR_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',117,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_lexus_preference_2b42bd8c14','lexus_preference','Lexus Préférence','Lexus Préférence','https://www.lexus-preference.fr/',array['lexus-preference.fr','www.lexus-preference.fr']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',118,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_nissan_intelligent_choice_00dab2398f','nissan_intelligent_choice','Nissan Intelligent Choice','Nissan Intelligent Choice','https://occasion.nissan.fr/',array['occasion.nissan.fr']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','USED_OR_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',119,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_ford_approved_25904edcc2','ford_approved','Ford Approved','Ford Approved','https://www.ford.fr/voitures-occasion',array['ford.fr','www.ford.fr']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','USED_OR_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',120,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_hyundai_promise_57b93f3013','hyundai_promise','Hyundai Promise','Hyundai Promise','https://www.hyundai.com/fr/fr/acheter/vehicules-occasion.html',array['hyundai.com','www.hyundai.com']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','USED_OR_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',121,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_kia_occasion_a5b5f71c51','kia_occasion','Kia Occasion','Kia Occasion','https://occasion.kia.fr/',array['occasion.kia.fr']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','USED_OR_STOCK','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',122,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_volvo_selekt_daf9d90f94','volvo_selekt','Volvo Selekt','Volvo Selekt','https://selekt.volvocars.fr/',array['selekt.volvocars.fr']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',123,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_jaguar_approved_5d1760cea8','jaguar_approved','Jaguar Approved','Jaguar Approved','https://approved.jaguar.fr/',array['approved.jaguar.fr']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',124,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_land_rover_approved_7df1cbc9f3','land_rover_approved','Land Rover Approved','Land Rover Approved','https://approved.landrover.fr/',array['approved.landrover.fr']::text[],'OFFICIAL_USED','VEHICLE_PURCHASE','HOME_OR_CATALOG','PRIMARY','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',125,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Labels officiels d’occasion des constructeurs'),
    ('report_mobilize_financial_services_be82526ab8','mobilize_financial_services','Mobilize Financial Services','Mobilize Financial Services','https://www.mobilize-fs.fr/',array['mobilize-fs.fr','www.mobilize-fs.fr']::text[],'OFFICIAL_SERVICE_FINANCE','CURRENT_VEHICLE','AFTER_SALES','PRIMARY','REFERENCE_ONLY','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',132,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Financement, entretien, garantie et assistance officiels'),
    ('report_stellantis_financial_services_b12bbf3e85','stellantis_financial_services','Stellantis Financial Services','Stellantis Financial Services','https://www.stellantis-financial-services.fr/',array['stellantis-financial-services.fr','www.stellantis-financial-services.fr']::text[],'OFFICIAL_SERVICE_FINANCE','CURRENT_VEHICLE','AFTER_SALES','PRIMARY','REFERENCE_ONLY','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',133,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Financement, entretien, garantie et assistance officiels'),
    ('report_leasys_france_956cec4a52','leasys_france','Leasys France','Leasys France','https://www.leasys.com/fr/francais',array['leasys.com','www.leasys.com']::text[],'OFFICIAL_SERVICE_FINANCE','CURRENT_VEHICLE','HOME_OR_CATALOG','PRIMARY','REFERENCE_ONLY','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',134,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Financement, entretien, garantie et assistance officiels'),
    ('report_volkswagen_financial_services_0e0e177327','volkswagen_financial_services','Volkswagen Financial Services','Volkswagen Financial Services','https://www.vwfs.fr/',array['vwfs.fr','www.vwfs.fr']::text[],'OFFICIAL_SERVICE_FINANCE','CURRENT_VEHICLE','AFTER_SALES','PRIMARY','REFERENCE_ONLY','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',135,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Financement, entretien, garantie et assistance officiels'),
    ('report_bmw_financial_services_203aed0afc','bmw_financial_services','BMW Financial Services','BMW Financial Services','https://www.bmw.fr/fr/topics/offers-and-services/bmw-financial-services.html',array['bmw.fr','www.bmw.fr']::text[],'OFFICIAL_SERVICE_FINANCE','CURRENT_VEHICLE','AFTER_SALES','PRIMARY','REFERENCE_ONLY','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',136,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Financement, entretien, garantie et assistance officiels'),
    ('report_mercedes_benz_financial_services_c92666ecf7','mercedes_benz_financial_servic','Mercedes-Benz Financial Services','Mercedes-Benz Financial Services','https://www.mercedes-benz.fr/passengercars/finance.html',array['mercedes-benz.fr','www.mercedes-benz.fr']::text[],'OFFICIAL_SERVICE_FINANCE','CURRENT_VEHICLE','AFTER_SALES','PRIMARY','REFERENCE_ONLY','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',137,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Financement, entretien, garantie et assistance officiels'),
    ('report_toyota_financial_services_7daa86a768','toyota_financial_services','Toyota Financial Services','Toyota Financial Services','https://www.toyota.fr/achat/financement',array['toyota.fr','www.toyota.fr']::text[],'OFFICIAL_SERVICE_FINANCE','CURRENT_VEHICLE','AFTER_SALES','PRIMARY','REFERENCE_ONLY','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',138,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Financement, entretien, garantie et assistance officiels'),
    ('report_kinto_france_d3862d397f','kinto_france','KINTO France','KINTO France','https://www.kinto-mobility.eu/fr/fr',array['kinto-mobility.eu','www.kinto-mobility.eu']::text[],'OFFICIAL_SERVICE_FINANCE','CURRENT_VEHICLE','HOME_OR_CATALOG','PRIMARY','REFERENCE_ONLY','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',139,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Financement, entretien, garantie et assistance officiels'),
    ('report_ford_credit_6de1473954','ford_credit','Ford Credit','Ford Credit','https://www.ford.fr/financement',array['ford.fr','www.ford.fr']::text[],'OFFICIAL_SERVICE_FINANCE','CURRENT_VEHICLE','FINANCE','PRIMARY','REFERENCE_ONLY','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',140,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Financement, entretien, garantie et assistance officiels'),
    ('report_hyundai_capital_france_6c98e06951','hyundai_capital_france','Hyundai Capital France','Hyundai Capital France','https://www.hyundai.com/fr/fr/acheter/financement.html',array['hyundai.com','www.hyundai.com']::text[],'OFFICIAL_SERVICE_FINANCE','CURRENT_VEHICLE','FINANCE','PRIMARY','REFERENCE_ONLY','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',141,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Financement, entretien, garantie et assistance officiels'),
    ('report_kia_finance_6fd0925e42','kia_finance','Kia Finance','Kia Finance','https://www.kia.com/fr/achat/financement',array['kia.com','www.kia.com']::text[],'OFFICIAL_SERVICE_FINANCE','CURRENT_VEHICLE','FINANCE','PRIMARY','REFERENCE_ONLY','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',142,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Financement, entretien, garantie et assistance officiels'),
    ('report_volvo_car_financial_services_cb78ec8ab8','volvo_car_financial_services','Volvo Car Financial Services','Volvo Car Financial Services','https://www.volvocars.com/fr/l/financement',array['volvocars.com','www.volvocars.com']::text[],'OFFICIAL_SERVICE_FINANCE','CURRENT_VEHICLE','AFTER_SALES','PRIMARY','REFERENCE_ONLY','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',143,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Financement, entretien, garantie et assistance officiels'),
    ('report_audi_financial_services_c0c4a5935b','audi_financial_services','Audi Financial Services','Audi Financial Services','https://www.audi.fr/fr/acheter/financement',array['audi.fr','www.audi.fr']::text[],'OFFICIAL_SERVICE_FINANCE','CURRENT_VEHICLE','AFTER_SALES','PRIMARY','REFERENCE_ONLY','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',144,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Financement, entretien, garantie et assistance officiels'),
    ('report_porsche_financial_services_9965bc2a54','porsche_financial_services','Porsche Financial Services','Porsche Financial Services','https://www.porsche.com/france/accessoriesandservice/porschefinancialservices',array['porsche.com','www.porsche.com']::text[],'OFFICIAL_SERVICE_FINANCE','CURRENT_VEHICLE','AFTER_SALES','PRIMARY','REFERENCE_ONLY','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',145,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Financement, entretien, garantie et assistance officiels'),
    ('report_mopar_services_ef1649b6fc','mopar_services','Mopar Services','Mopar Services','https://www.mopar.eu/fr/fr',array['mopar.eu','www.mopar.eu']::text[],'OFFICIAL_SERVICE_FINANCE','CURRENT_VEHICLE','AFTER_SALES','PRIMARY','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,10,24,'FR','deep-research-report.md',146,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Financement, entretien, garantie et assistance officiels'),
    ('report_renault_care_service_96bced321d','renault_care_service','Renault Care Service','Renault Care Service','https://www.renault.fr/entretien.html',array['renault.fr','www.renault.fr']::text[],'OFFICIAL_SERVICE_FINANCE','CURRENT_VEHICLE','AFTER_SALES','PRIMARY','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,10,24,'FR','deep-research-report.md',147,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Financement, entretien, garantie et assistance officiels'),
    ('report_peugeot_services_913ae098cc','peugeot_services','Peugeot Services','Peugeot Services','https://www.peugeot.fr/entretien-et-services.html',array['peugeot.fr','www.peugeot.fr']::text[],'OFFICIAL_SERVICE_FINANCE','CURRENT_VEHICLE','AFTER_SALES','PRIMARY','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,10,24,'FR','deep-research-report.md',148,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Financement, entretien, garantie et assistance officiels'),
    ('report_citroen_services_9104f24909','citroen_services','Citroën Services','Citroën Services','https://www.citroen.fr/entretenir.html',array['citroen.fr','www.citroen.fr']::text[],'OFFICIAL_SERVICE_FINANCE','CURRENT_VEHICLE','AFTER_SALES','PRIMARY','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,10,24,'FR','deep-research-report.md',149,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Financement, entretien, garantie et assistance officiels'),
    ('report_audi_apres_vente_1a1a57df7f','audi_apres_vente','Audi Après-Vente','Audi Après-Vente','https://www.audi.fr/fr/entretenir',array['audi.fr','www.audi.fr']::text[],'OFFICIAL_SERVICE_FINANCE','CURRENT_VEHICLE','AFTER_SALES','PRIMARY','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,10,24,'FR','deep-research-report.md',150,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Financement, entretien, garantie et assistance officiels'),
    ('report_opel_flexcare_1f45405e06','opel_flexcare','Opel FlexCare','Opel FlexCare','https://www.opel.fr/entretien-services/flexcare.html',array['opel.fr','www.opel.fr']::text[],'OFFICIAL_SERVICE_FINANCE','CURRENT_VEHICLE','AFTER_SALES','PRIMARY','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,10,24,'FR','deep-research-report.md',151,'Cartographie des sources d’offres commerciales automobiles valables en France > Constructeurs et services officiels > Financement, entretien, garantie et assistance officiels'),
    ('report_autosphere_6ee83a63c1','autosphere','Autosphere','Autosphere','https://www.autosphere.fr/',array['autosphere.fr','www.autosphere.fr']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',161,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_bymycar_0da2a2968b','bymycar','BYmyCAR','BYmyCAR','https://www.bymycar.fr/',array['bymycar.fr','www.bymycar.fr']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',162,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_edenauto_6b01a32504','edenauto','Edenauto','Edenauto','https://www.edenauto.com/',array['edenauto.com','www.edenauto.com']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',163,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_groupe_chopard_0baf99eaf1','groupe_chopard','Groupe Chopard','Groupe Chopard','https://www.groupechopard.com/',array['groupechopard.com','www.groupechopard.com']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',164,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_groupe_chopard_ab1e53b133','groupe_chopard','Groupe Chopard — offres','Groupe Chopard','https://www.groupechopard.com/offres',array['groupechopard.com','www.groupechopard.com']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','OFFERS','PROFESSIONAL','HTML_DISCOVERY','QUARANTINE_ONLY',true,20,72,'FR','deep-research-report.md',164,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_gueudet_1880_eb3b9f8b56','gueudet_1880','Gueudet 1880','Gueudet 1880','https://www.gueudet.fr/',array['gueudet.fr','www.gueudet.fr']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',165,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_groupe_bpm_4f3714af83','groupe_bpm','Groupe BPM','Groupe BPM','https://www.bpmgroup.fr/',array['bpmgroup.fr','www.bpmgroup.fr']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',166,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_mary_automobiles_a34f5d0653','mary_automobiles','Mary Automobiles','Mary Automobiles','https://www.maryautomobiles.fr/',array['maryautomobiles.fr','www.maryautomobiles.fr']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',167,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_jean_rouyer_automobiles_1d705f4f96','jean_rouyer_automobiles','Jean Rouyer Automobiles','Jean Rouyer Automobiles','https://www.jeanrouyerautomobiles.fr/',array['jeanrouyerautomobiles.fr','www.jeanrouyerautomobiles.fr']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',168,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_groupe_dubreuil_automobiles_6151edf885','groupe_dubreuil_automobiles','Groupe Dubreuil Automobiles','Groupe Dubreuil Automobiles','https://www.dubreuil-automobiles.com/',array['dubreuil-automobiles.com','www.dubreuil-automobiles.com']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',169,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_bodemerauto_177ddbaf15','bodemerauto','BodemerAuto','BodemerAuto','https://www.bodemerauto.com/',array['bodemerauto.com','www.bodemerauto.com']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',170,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_gca_1a57aab401','gca','GCA','GCA','https://www.groupegca.com/',array['groupegca.com','www.groupegca.com']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',171,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_groupe_maurin_14c5fa0a54','groupe_maurin','Groupe Maurin','Groupe Maurin','https://www.groupe-maurin.com/',array['groupe-maurin.com','www.groupe-maurin.com']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',172,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_groupe_hess_automobile_e404592cd9','groupe_hess_automobile','Groupe Hess Automobile','Groupe Hess Automobile','https://www.hessautomobile.com/',array['hessautomobile.com','www.hessautomobile.com']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',173,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_groupe_bernard_78417b1fe1','groupe_bernard','Groupe Bernard','Groupe Bernard','https://www.groupe-bernard.fr/',array['groupe-bernard.fr','www.groupe-bernard.fr']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',174,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_groupe_kroely_03b657ff75','groupe_kroely','Groupe Kroely','Groupe Kroely','https://www.kroely.fr/',array['kroely.fr','www.kroely.fr']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',175,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_neubauer_63b977fdd4','neubauer','Neubauer','Neubauer','https://www.neubauer.fr/',array['neubauer.fr','www.neubauer.fr']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',176,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_groupe_vauban_060c48657d','groupe_vauban','Groupe Vauban','Groupe Vauban','https://www.groupe-vauban.com/',array['groupe-vauban.com','www.groupe-vauban.com']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',177,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_groupe_priod_691371f7a3','groupe_priod','Groupe Priod','Groupe Priod','https://www.priod.fr/',array['priod.fr','www.priod.fr']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',178,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_groupe_como_35ddbe6da8','groupe_como','Groupe Como','Groupe Como','https://www.groupe-como.fr/',array['groupe-como.fr','www.groupe-como.fr']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',179,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_distinxion_e5d4c8771d','distinxion','Distinxion','Distinxion','https://www.distinxion.fr/',array['distinxion.fr','www.distinxion.fr']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',180,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_simplicicar_cb52577c12','simplicicar','Simplicicar','Simplicicar','https://www.simplicicar.com/',array['simplicicar.com','www.simplicicar.com']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',181,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_vpn_autos_8eda491f75','vpn_autos','VPN Autos','VPN Autos','https://www.vpauto.fr/',array['vpauto.fr','www.vpauto.fr']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',182,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_aramisauto_fad05a6c7c','aramisauto','Aramisauto','Aramisauto','https://www.aramisauto.com/',array['aramisauto.com','www.aramisauto.com']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',183,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_cfao_mobility_77dc90f0a0','cfao_mobility','CFAO Mobility','CFAO Mobility','https://www.cfao.com/fr/automotive',array['cfao.com','www.cfao.com']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',184,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_gbh_automobile_fda06e59b3','gbh_automobile','GBH Automobile','GBH Automobile','https://www.gbh.fr/fr/activites/automobile',array['gbh.fr','www.gbh.fr']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',185,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_sogecore_7451f6fa5a','sogecore','Sogecore','Sogecore','https://www.sogecore.re/',array['sogecore.re','www.sogecore.re']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',186,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_cmm_automobiles_aeaa883af5','cmm_automobiles','CMM Automobiles','CMM Automobiles','https://www.cmmautomobiles.com/',array['cmmautomobiles.com','www.cmmautomobiles.com']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',187,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_bamy_automobiles_0a43fef6ce','bamy_automobiles','Bamy Automobiles','Bamy Automobiles','https://www.bamyautomobiles.com/',array['bamyautomobiles.com','www.bamyautomobiles.com']::text[],'DEALER_GROUP','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','LINK_DISCOVERY_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',188,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Groupes de concessionnaires et réseaux multimarques'),
    ('report_leboncoin_voitures_9ac7d8a7d3','leboncoin_voitures','Leboncoin Voitures','Leboncoin Voitures','https://www.leboncoin.fr/c/voitures',array['leboncoin.fr','www.leboncoin.fr']::text[],'VEHICLE_MARKETPLACE','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',194,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Portails d’annonces et places de marché automobiles'),
    ('report_la_centrale_48169bb3ee','la_centrale','La Centrale','La Centrale','https://www.lacentrale.fr/',array['lacentrale.fr','www.lacentrale.fr']::text[],'VEHICLE_MARKETPLACE','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',195,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Portails d’annonces et places de marché automobiles'),
    ('report_autoscout24_france_6299a72655','autoscout24_france','AutoScout24 France','AutoScout24 France','https://www.autoscout24.fr/',array['autoscout24.fr','www.autoscout24.fr']::text[],'VEHICLE_MARKETPLACE','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',196,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Portails d’annonces et places de marché automobiles'),
    ('report_paruvendu_auto_81250d4b13','paruvendu_auto','ParuVendu Auto','ParuVendu Auto','https://www.paruvendu.fr/voiture-occasion',array['paruvendu.fr','www.paruvendu.fr']::text[],'VEHICLE_MARKETPLACE','VEHICLE_PURCHASE','USED_OR_STOCK','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',197,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Portails d’annonces et places de marché automobiles'),
    ('report_largus_annonces_463b85b39b','largus_annonces','L’Argus Annonces','L’Argus Annonces','https://occasion.largus.fr/',array['occasion.largus.fr']::text[],'VEHICLE_MARKETPLACE','VEHICLE_PURCHASE','USED_OR_STOCK','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',198,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Portails d’annonces et places de marché automobiles'),
    ('report_ouest_france_auto_3178436ad7','ouest_france_auto','Ouest-France Auto','Ouest-France Auto','https://www.ouestfrance-auto.com/',array['ouestfrance-auto.com','www.ouestfrance-auto.com']::text[],'VEHICLE_MARKETPLACE','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',199,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Portails d’annonces et places de marché automobiles'),
    ('report_facebook_marketplace_45e1a9bdd5','facebook_marketplace','Facebook Marketplace','Facebook Marketplace','https://www.facebook.com/marketplace/category/vehicles',array['facebook.com','www.facebook.com']::text[],'VEHICLE_MARKETPLACE','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',200,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Portails d’annonces et places de marché automobiles'),
    ('report_autohero_2b31a8da2b','autohero','Autohero','Autohero','https://www.autohero.com/fr',array['autohero.com','www.autohero.com']::text[],'VEHICLE_MARKETPLACE','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',201,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Portails d’annonces et places de marché automobiles'),
    ('report_carizy_865d4a2d48','carizy','Carizy','Carizy','https://www.carizy.com/',array['carizy.com','www.carizy.com']::text[],'VEHICLE_MARKETPLACE','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',202,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Portails d’annonces et places de marché automobiles'),
    ('report_reezocar_517ad0182e','reezocar','Reezocar','Reezocar','https://www.reezocar.com/',array['reezocar.com','www.reezocar.com']::text[],'VEHICLE_MARKETPLACE','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',203,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Portails d’annonces et places de marché automobiles'),
    ('report_vivacar_1b44d862f1','vivacar','Vivacar','Vivacar','https://www.vivacar.fr/',array['vivacar.fr','www.vivacar.fr']::text[],'VEHICLE_MARKETPLACE','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',204,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Portails d’annonces et places de marché automobiles'),
    ('report_promoneuve_d086493301','promoneuve','Promoneuve','Promoneuve','https://www.promoneuve.fr/',array['promoneuve.fr','www.promoneuve.fr']::text[],'VEHICLE_MARKETPLACE','VEHICLE_PURCHASE','OFFERS','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',205,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Portails d’annonces et places de marché automobiles'),
    ('report_vendezvotrevoiture_fr_5f442b3170','vendezvotrevoiture_fr','Vendezvotrevoiture.fr','Vendezvotrevoiture.fr','https://www.vendezvotrevoiture.fr/',array['vendezvotrevoiture.fr','www.vendezvotrevoiture.fr']::text[],'VEHICLE_MARKETPLACE','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',206,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Portails d’annonces et places de marché automobiles'),
    ('report_caroom_0b02a4dfc2','caroom','Caroom','Caroom','https://www.caroom.fr/',array['caroom.fr','www.caroom.fr']::text[],'VEHICLE_COMPARATOR','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',212,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Comparateurs, mandataires et observatoires de prix'),
    ('report_kidioui_38466ac0f2','kidioui','Kidioui','Kidioui','https://voiture.kidioui.fr/',array['voiture.kidioui.fr']::text[],'VEHICLE_COMPARATOR','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',213,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Comparateurs, mandataires et observatoires de prix'),
    ('report_drivek_offres_5519b2d8de','drivek_offres','DriveK Offres','DriveK Offres','https://www.drivek.fr/offres',array['drivek.fr','www.drivek.fr']::text[],'VEHICLE_COMPARATOR','VEHICLE_PURCHASE','OFFERS','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',214,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Comparateurs, mandataires et observatoires de prix'),
    ('report_autodiscount_cb2b802867','autodiscount','Autodiscount','Autodiscount','https://www.autodiscount.fr/',array['autodiscount.fr','www.autodiscount.fr']::text[],'VEHICLE_COMPARATOR','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',215,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Comparateurs, mandataires et observatoires de prix'),
    ('report_elite_auto_25804127a4','elite_auto','Elite Auto','Elite Auto','https://www.elite-auto.fr/',array['elite-auto.fr','www.elite-auto.fr']::text[],'VEHICLE_COMPARATOR','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',216,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Comparateurs, mandataires et observatoires de prix'),
    ('report_auto_ies_e1b4d8411a','auto_ies','Auto-IES','Auto-IES','https://www.auto-ies.com/',array['auto-ies.com','www.auto-ies.com']::text[],'VEHICLE_COMPARATOR','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',217,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Comparateurs, mandataires et observatoires de prix'),
    ('report_degrifcars_b7936352ae','degrifcars','Degrifcars','Degrifcars','https://www.degrifcars.com/',array['degrifcars.com','www.degrifcars.com']::text[],'VEHICLE_COMPARATOR','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',218,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Comparateurs, mandataires et observatoires de prix'),
    ('report_club_auto_6d3f143519','club_auto','Club Auto','Club Auto','https://www.club-auto.com/',array['club-auto.com','www.club-auto.com']::text[],'VEHICLE_COMPARATOR','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',219,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Comparateurs, mandataires et observatoires de prix'),
    ('report_caradisiac_promotions_constructeurs_d3a0c98930','caradisiac_promotions_construc','Caradisiac – promotions constructeurs','Caradisiac – promotions constructeurs','https://www.caradisiac.com/guide--achat-neuf--promotion',array['caradisiac.com','www.caradisiac.com']::text[],'VEHICLE_COMPARATOR','VEHICLE_PURCHASE','OFFERS','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',220,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Comparateurs, mandataires et observatoires de prix'),
    ('report_largus_prix_et_cote_9cc612d9a6','largus_prix_et_cote','L’Argus – prix et cote','L’Argus – prix et cote','https://www.largus.fr/cote',array['largus.fr','www.largus.fr']::text[],'VEHICLE_COMPARATOR','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',221,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Comparateurs, mandataires et observatoires de prix'),
    ('report_la_centrale_cote_7045caa287','la_centrale_cote','La Centrale – cote','La Centrale – cote','https://www.lacentrale.fr/cote-auto.html',array['lacentrale.fr','www.lacentrale.fr']::text[],'VEHICLE_COMPARATOR','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',222,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Comparateurs, mandataires et observatoires de prix'),
    ('report_paruvendu_cote_14891226ca','paruvendu_cote','ParuVendu – cote','ParuVendu – cote','https://www.paruvendu.fr/cote-auto-gratuite',array['paruvendu.fr','www.paruvendu.fr']::text[],'VEHICLE_COMPARATOR','VEHICLE_PURCHASE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',223,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Comparateurs, mandataires et observatoires de prix'),
    ('report_car_labelling_ademe_3f4286d244','car_labelling_ademe','Car Labelling ADEME','Car Labelling ADEME','https://carlabelling.ademe.fr/',array['carlabelling.ademe.fr']::text[],'VEHICLE_COMPARATOR','VEHICLE_PURCHASE','REFERENCE','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',224,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Comparateurs, mandataires et observatoires de prix'),
    ('report_pneus_fr_15802e0da6','pneus_fr','Pneus.fr','Pneus.fr','https://www.pneus.fr/',array['pneus.fr','www.pneus.fr']::text[],'VEHICLE_COMPARATOR','VEHICLE_PURCHASE','AFTER_SALES','PROFESSIONAL','ADAPTER_REQUIRED','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',225,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Comparateurs, mandataires et observatoires de prix'),
    ('report_dealabs_db047af1e5','dealabs','Dealabs','Dealabs','https://www.dealabs.com/',array['dealabs.com','www.dealabs.com']::text[],'COMMUNITY_DEALS','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',231,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Deals, cashback, codes promotionnels et communautés'),
    ('report_serial_dealer_973df99f01','serial_dealer','Serial Dealer','Serial Dealer','https://www.serialdealer.fr/',array['serialdealer.fr','www.serialdealer.fr']::text[],'COMMUNITY_DEALS','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',232,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Deals, cashback, codes promotionnels et communautés'),
    ('report_ma_reduc_4595ece0ab','ma_reduc','Ma Reduc','Ma Reduc','https://www.ma-reduc.com/',array['ma-reduc.com','www.ma-reduc.com']::text[],'COMMUNITY_DEALS','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',233,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Deals, cashback, codes promotionnels et communautés'),
    ('report_igraal_a0eb2b7d61','igraal','iGraal','iGraal','https://fr.igraal.com/',array['fr.igraal.com']::text[],'COMMUNITY_DEALS','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',234,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Deals, cashback, codes promotionnels et communautés'),
    ('report_ebuyclub_6cd9ed8793','ebuyclub','eBuyClub','eBuyClub','https://www.ebuyclub.com/',array['ebuyclub.com','www.ebuyclub.com']::text[],'COMMUNITY_DEALS','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',235,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Deals, cashback, codes promotionnels et communautés'),
    ('report_poulpeo_ba3e7bb8fb','poulpeo','Poulpeo','Poulpeo','https://www.poulpeo.com/',array['poulpeo.com','www.poulpeo.com']::text[],'COMMUNITY_DEALS','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',236,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Deals, cashback, codes promotionnels et communautés'),
    ('report_groupon_france_28461cefa7','groupon_france','Groupon France','Groupon France','https://www.groupon.fr/',array['groupon.fr','www.groupon.fr']::text[],'COMMUNITY_DEALS','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',237,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Deals, cashback, codes promotionnels et communautés'),
    ('report_forum_auto_caradisiac_6753bb90d0','forum_auto_caradisiac','Forum-Auto Caradisiac','Forum-Auto Caradisiac','https://forum-auto.caradisiac.com/',array['forum-auto.caradisiac.com']::text[],'COMMUNITY_DEALS','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',238,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Deals, cashback, codes promotionnels et communautés'),
    ('report_forum_automobile_propre_c43ad02b4c','forum_automobile_propre','Forum Automobile Propre','Forum Automobile Propre','https://forums.automobile-propre.com/',array['forums.automobile-propre.com']::text[],'COMMUNITY_DEALS','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',239,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Deals, cashback, codes promotionnels et communautés'),
    ('report_tesla_motors_club_france_a12a869eb3','tesla_motors_club_france','Tesla Motors Club France','Tesla Motors Club France','https://www.blogtesla.fr/forum',array['blogtesla.fr','www.blogtesla.fr']::text[],'COMMUNITY_DEALS','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',240,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Deals, cashback, codes promotionnels et communautés'),
    ('report_reddit_r_voiture_2d82346833','reddit_r_voiture','Reddit r/voiture','Reddit r/voiture','https://www.reddit.com/r/voiture',array['reddit.com','www.reddit.com']::text[],'COMMUNITY_DEALS','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',241,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Deals, cashback, codes promotionnels et communautés'),
    ('report_les_forums_de_marques_55c45b168f','les_forums_de_marques','Les forums de marques','Les forums de marques','https://www.forum-peugeot.com/',array['forum-peugeot.com','www.forum-peugeot.com']::text[],'COMMUNITY_DEALS','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',242,'Cartographie des sources d’offres commerciales automobiles valables en France > Distribution, annonces, comparateurs et deals > Deals, cashback, codes promotionnels et communautés'),
    ('report_norauto_5b67250e80','norauto','Norauto','Norauto','https://www.norauto.fr/',array['norauto.fr','www.norauto.fr']::text[],'AFTER_SALES_NETWORK','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,20,24,'FR','deep-research-report.md',250,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Réseaux d’entretien, réparation et centres automobiles'),
    ('report_feu_vert_d480ed5e8b','feu_vert','Feu Vert','Feu Vert','https://www.feuvert.fr/',array['feuvert.fr','www.feuvert.fr']::text[],'AFTER_SALES_NETWORK','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,20,24,'FR','deep-research-report.md',251,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Réseaux d’entretien, réparation et centres automobiles'),
    ('report_midas_0aeca5e6e1','midas','Midas','Midas','https://www.midas.fr/',array['midas.fr','www.midas.fr']::text[],'AFTER_SALES_NETWORK','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,20,24,'FR','deep-research-report.md',252,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Réseaux d’entretien, réparation et centres automobiles'),
    ('report_speedy_9e5dd69a95','speedy','Speedy','Speedy','https://www.speedy.fr/',array['speedy.fr','www.speedy.fr']::text[],'AFTER_SALES_NETWORK','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,20,24,'FR','deep-research-report.md',253,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Réseaux d’entretien, réparation et centres automobiles'),
    ('report_roady_6b0900b26a','roady','Roady','Roady','https://www.roady.fr/',array['roady.fr','www.roady.fr']::text[],'AFTER_SALES_NETWORK','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,20,24,'FR','deep-research-report.md',254,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Réseaux d’entretien, réparation et centres automobiles'),
    ('report_carter_cash_b010c10992','carter_cash','Carter-Cash','Carter-Cash','https://www.carter-cash.com/',array['carter-cash.com','www.carter-cash.com']::text[],'AFTER_SALES_NETWORK','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,20,24,'FR','deep-research-report.md',255,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Réseaux d’entretien, réparation et centres automobiles'),
    ('report_point_s_5fd567643c','point_s','Point S','Point S','https://www.points.fr/',array['points.fr','www.points.fr']::text[],'AFTER_SALES_NETWORK','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,20,24,'FR','deep-research-report.md',256,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Réseaux d’entretien, réparation et centres automobiles'),
    ('report_point_s_a52e8caa3b','point_s','Point S — promotions','Point S','https://www.points.fr/promotions',array['points.fr','www.points.fr']::text[],'AFTER_SALES_NETWORK','CURRENT_VEHICLE','OFFERS','PROFESSIONAL','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,20,24,'FR','deep-research-report.md',256,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Réseaux d’entretien, réparation et centres automobiles'),
    ('report_euromaster_b30b3a834c','euromaster','Euromaster','Euromaster','https://www.euromaster.fr/',array['euromaster.fr','www.euromaster.fr']::text[],'AFTER_SALES_NETWORK','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,20,24,'FR','deep-research-report.md',257,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Réseaux d’entretien, réparation et centres automobiles'),
    ('report_first_stop_c67aac601c','first_stop','First Stop','First Stop','https://www.firststop.fr/',array['firststop.fr','www.firststop.fr']::text[],'AFTER_SALES_NETWORK','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,20,24,'FR','deep-research-report.md',258,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Réseaux d’entretien, réparation et centres automobiles'),
    ('report_bestdrive_5182cbcb21','bestdrive','BestDrive','BestDrive','https://www.bestdrive.fr/',array['bestdrive.fr','www.bestdrive.fr']::text[],'AFTER_SALES_NETWORK','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,20,24,'FR','deep-research-report.md',259,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Réseaux d’entretien, réparation et centres automobiles'),
    ('report_bosch_car_service_0a1c19174c','bosch_car_service','Bosch Car Service','Bosch Car Service','https://www.boschcarservice.com/fr/fr',array['boschcarservice.com','www.boschcarservice.com']::text[],'AFTER_SALES_NETWORK','CURRENT_VEHICLE','AFTER_SALES','PROFESSIONAL','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,20,24,'FR','deep-research-report.md',260,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Réseaux d’entretien, réparation et centres automobiles'),
    ('report_ad_garage_57c7175d7e','ad_garage','AD Garage','AD Garage','https://www.ad.fr/',array['ad.fr','www.ad.fr']::text[],'AFTER_SALES_NETWORK','CURRENT_VEHICLE','AFTER_SALES','PROFESSIONAL','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,20,24,'FR','deep-research-report.md',261,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Réseaux d’entretien, réparation et centres automobiles'),
    ('report_eurorepar_car_service_68c6b54a8e','eurorepar_car_service','Eurorepar Car Service','Eurorepar Car Service','https://www.eurorepar.fr/',array['eurorepar.fr','www.eurorepar.fr']::text[],'AFTER_SALES_NETWORK','CURRENT_VEHICLE','AFTER_SALES','PROFESSIONAL','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,20,24,'FR','deep-research-report.md',262,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Réseaux d’entretien, réparation et centres automobiles'),
    ('report_motrio_ad64d23eca','motrio','Motrio','Motrio','https://www.motrio.fr/',array['motrio.fr','www.motrio.fr']::text[],'AFTER_SALES_NETWORK','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,20,24,'FR','deep-research-report.md',263,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Réseaux d’entretien, réparation et centres automobiles'),
    ('report_five_star_c2fe4ca6b7','five_star','Five Star','Five Star','https://www.five-star.fr/',array['five-star.fr','www.five-star.fr']::text[],'AFTER_SALES_NETWORK','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,20,24,'FR','deep-research-report.md',264,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Réseaux d’entretien, réparation et centres automobiles'),
    ('report_axial_0af3364fa5','axial','Axial','Axial','https://www.axial.org/',array['axial.org','www.axial.org']::text[],'AFTER_SALES_NETWORK','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','HTML_DISCOVERY','VALIDATED_RULES_ONLY',true,20,24,'FR','deep-research-report.md',265,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Réseaux d’entretien, réparation et centres automobiles'),
    ('report_vroomly_3c15b692ff','vroomly','Vroomly','Vroomly','https://www.vroomly.com/',array['vroomly.com','www.vroomly.com']::text[],'GARAGE_COMPARATOR','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',271,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Comparateurs de garages et devis d’entretien'),
    ('report_idgarages_e1dd12c9cf','idgarages','idGarages','idGarages','https://www.idgarages.com/',array['idgarages.com','www.idgarages.com']::text[],'GARAGE_COMPARATOR','CURRENT_VEHICLE','AFTER_SALES','PROFESSIONAL','ADAPTER_REQUIRED','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',272,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Comparateurs de garages et devis d’entretien'),
    ('report_allogarage_cde0090a4e','allogarage','Allogarage','Allogarage','https://www.allogarage.fr/',array['allogarage.fr','www.allogarage.fr']::text[],'GARAGE_COMPARATOR','CURRENT_VEHICLE','AFTER_SALES','PROFESSIONAL','ADAPTER_REQUIRED','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',273,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Comparateurs de garages et devis d’entretien'),
    ('report_goodmecano_9f38503ed5','goodmecano','GoodMecano','GoodMecano','https://www.goodmecano.com/',array['goodmecano.com','www.goodmecano.com']::text[],'GARAGE_COMPARATOR','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',274,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Comparateurs de garages et devis d’entretien'),
    ('report_fixter_d896b32c7b','fixter','Fixter','Fixter','https://www.fixter.fr/',array['fixter.fr','www.fixter.fr']::text[],'GARAGE_COMPARATOR','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',275,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Comparateurs de garages et devis d’entretien'),
    ('report_oscaro_13756b4244','oscaro','Oscaro','Oscaro','https://www.oscaro.com/',array['oscaro.com','www.oscaro.com']::text[],'PARTS_TYRES','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',281,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Pièces, accessoires, pneus et équipements'),
    ('report_mister_auto_2417393716','mister_auto','Mister-Auto','Mister-Auto','https://www.mister-auto.com/',array['mister-auto.com','www.mister-auto.com']::text[],'PARTS_TYRES','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',282,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Pièces, accessoires, pneus et équipements'),
    ('report_autodoc_france_a1262fc6ba','autodoc_france','AUTODOC France','AUTODOC France','https://www.auto-doc.fr/',array['auto-doc.fr','www.auto-doc.fr']::text[],'PARTS_TYRES','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',283,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Pièces, accessoires, pneus et équipements'),
    ('report_piecesauto24_4c1cd5c07a','piecesauto24','PiècesAuto24','PiècesAuto24','https://www.piecesauto24.com/',array['piecesauto24.com','www.piecesauto24.com']::text[],'PARTS_TYRES','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',284,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Pièces, accessoires, pneus et équipements'),
    ('report_norauto_pieces_5948a5f8c1','norauto_pieces','Norauto Pièces','Norauto Pièces','https://www.norauto.fr/e/remplacer-une-piece.html',array['norauto.fr','www.norauto.fr']::text[],'PARTS_TYRES','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',286,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Pièces, accessoires, pneus et équipements'),
    ('report_ebay_auto_81d1c13811','ebay_auto','eBay Auto','eBay Auto','https://www.ebay.fr/b/Pieces-et-accessoires-pour-vehicules/131090/bn_16576412',array['ebay.fr','www.ebay.fr']::text[],'PARTS_TYRES','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',287,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Pièces, accessoires, pneus et équipements'),
    ('report_opisto_de520290bd','opisto','Opisto','Opisto','https://www.opisto.fr/',array['opisto.fr','www.opisto.fr']::text[],'PARTS_TYRES','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',288,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Pièces, accessoires, pneus et équipements'),
    ('report_france_casse_e0e149dd7d','france_casse','France Casse','France Casse','https://www.francecasse.fr/',array['francecasse.fr','www.francecasse.fr']::text[],'PARTS_TYRES','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',289,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Pièces, accessoires, pneus et équipements'),
    ('report_allopneus_9712eab553','allopneus','Allopneus','Allopneus','https://www.allopneus.com/',array['allopneus.com','www.allopneus.com']::text[],'PARTS_TYRES','CURRENT_VEHICLE','AFTER_SALES','PROFESSIONAL','ADAPTER_REQUIRED','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',290,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Pièces, accessoires, pneus et équipements'),
    ('report_1001pneus_efe1173dfa','1001pneus','1001Pneus','1001Pneus','https://www.1001pneus.fr/',array['1001pneus.fr','www.1001pneus.fr']::text[],'PARTS_TYRES','CURRENT_VEHICLE','AFTER_SALES','PROFESSIONAL','ADAPTER_REQUIRED','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',291,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Pièces, accessoires, pneus et équipements'),
    ('report_centralepneus_54d9cbd654','centralepneus','CentralePneus','CentralePneus','https://www.centralepneus.fr/',array['centralepneus.fr','www.centralepneus.fr']::text[],'PARTS_TYRES','CURRENT_VEHICLE','AFTER_SALES','PROFESSIONAL','ADAPTER_REQUIRED','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',292,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Pièces, accessoires, pneus et équipements'),
    ('report_123pneus_1de4cd8c1e','123pneus','123pneus','123pneus','https://www.123pneus.fr/',array['123pneus.fr','www.123pneus.fr']::text[],'PARTS_TYRES','CURRENT_VEHICLE','AFTER_SALES','PROFESSIONAL','ADAPTER_REQUIRED','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',293,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Pièces, accessoires, pneus et équipements'),
    ('report_pneus_online_fb1d212644','pneus_online','Pneus Online','Pneus Online','https://www.pneus-online.fr/',array['pneus-online.fr','www.pneus-online.fr']::text[],'PARTS_TYRES','CURRENT_VEHICLE','AFTER_SALES','PROFESSIONAL','ADAPTER_REQUIRED','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',294,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Pièces, accessoires, pneus et équipements'),
    ('report_glasurit_restagraf_thule_et_equipementiers_23d3611518','glasurit_restagraf_thule_et_eq','Glasurit, Restagraf, Thule et équipementiers','Glasurit, Restagraf, Thule et équipementiers','https://www.thule.com/fr-fr',array['thule.com','www.thule.com']::text[],'PARTS_TYRES','CURRENT_VEHICLE','HOME_OR_CATALOG','PROFESSIONAL','ADAPTER_REQUIRED','VALIDATED_RULES_ONLY',false,80,168,'FR','deep-research-report.md',295,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Pièces, accessoires, pneus et équipements'),
    ('report_europ_assistance_france_f2514ff7dd','europ_assistance_france','Europ Assistance France','Europ Assistance France','https://www.europ-assistance.fr/',array['europ-assistance.fr','www.europ-assistance.fr']::text[],'ASSISTANCE_INSURANCE','FINANCE_INSURANCE','HOME_OR_CATALOG','PROFESSIONAL','REFERENCE_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',301,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Assistance, dépannage, garantie et assurance'),
    ('report_allianz_partners_mondial_assistance_c460ded755','allianz_partners_mondial_assis','Allianz Partners / Mondial Assistance','Allianz Partners / Mondial Assistance','https://www.allianz-partners.com/fr_FR.html',array['allianz-partners.com','www.allianz-partners.com']::text[],'ASSISTANCE_INSURANCE','FINANCE_INSURANCE','HOME_OR_CATALOG','PROFESSIONAL','REFERENCE_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',302,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Assistance, dépannage, garantie et assurance'),
    ('report_axa_assistance_3d88543c2b','axa_assistance','AXA Assistance','AXA Assistance','https://www.axa-assistance.fr/',array['axa-assistance.fr','www.axa-assistance.fr']::text[],'ASSISTANCE_INSURANCE','FINANCE_INSURANCE','HOME_OR_CATALOG','PROFESSIONAL','REFERENCE_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',303,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Assistance, dépannage, garantie et assurance'),
    ('report_roole_e6fb8d8b43','roole','Roole','Roole','https://www.roole.fr/',array['roole.fr','www.roole.fr']::text[],'ASSISTANCE_INSURANCE','FINANCE_INSURANCE','HOME_OR_CATALOG','PROFESSIONAL','REFERENCE_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',304,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Assistance, dépannage, garantie et assurance'),
    ('report_opteven_bc2158c758','opteven','Opteven','Opteven','https://www.opteven.com/fr',array['opteven.com','www.opteven.com']::text[],'ASSISTANCE_INSURANCE','FINANCE_INSURANCE','HOME_OR_CATALOG','PROFESSIONAL','REFERENCE_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',305,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Assistance, dépannage, garantie et assurance'),
    ('report_cirano_garantie_m_67cd53ba52','cirano_garantie_m','Cirano / Garantie M','Cirano / Garantie M','https://www.garantiem.fr/',array['garantiem.fr','www.garantiem.fr']::text[],'ASSISTANCE_INSURANCE','FINANCE_INSURANCE','HOME_OR_CATALOG','PROFESSIONAL','REFERENCE_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',306,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Assistance, dépannage, garantie et assurance'),
    ('report_maif_auto_22a0da9fff','maif_auto','MAIF Auto','MAIF Auto','https://www.maif.fr/vehicule-mobilite/assurance-auto',array['maif.fr','www.maif.fr']::text[],'ASSISTANCE_INSURANCE','FINANCE_INSURANCE','FINANCE','PROFESSIONAL','REFERENCE_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',307,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Assistance, dépannage, garantie et assurance'),
    ('report_macif_auto_b5cfc6a541','macif_auto','MACIF Auto','MACIF Auto','https://www.macif.fr/assurance/particuliers/assurance-auto-moto',array['macif.fr','www.macif.fr']::text[],'ASSISTANCE_INSURANCE','FINANCE_INSURANCE','FINANCE','PROFESSIONAL','REFERENCE_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',308,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Assistance, dépannage, garantie et assurance'),
    ('report_matmut_auto_d895b9c254','matmut_auto','Matmut Auto','Matmut Auto','https://www.matmut.fr/assurance/auto',array['matmut.fr','www.matmut.fr']::text[],'ASSISTANCE_INSURANCE','FINANCE_INSURANCE','FINANCE','PROFESSIONAL','REFERENCE_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',309,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Assistance, dépannage, garantie et assurance'),
    ('report_gmf_auto_25fe87f3f6','gmf_auto','GMF Auto','GMF Auto','https://www.gmf.fr/assurances-auto-moto/assurance-auto',array['gmf.fr','www.gmf.fr']::text[],'ASSISTANCE_INSURANCE','FINANCE_INSURANCE','FINANCE','PROFESSIONAL','REFERENCE_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',310,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Assistance, dépannage, garantie et assurance'),
    ('report_mma_auto_730af7232d','mma_auto','MMA Auto','MMA Auto','https://www.mma.fr/assurance-auto.html',array['mma.fr','www.mma.fr']::text[],'ASSISTANCE_INSURANCE','FINANCE_INSURANCE','FINANCE','PROFESSIONAL','REFERENCE_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',311,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Assistance, dépannage, garantie et assurance'),
    ('report_groupama_auto_ba75e50b92','groupama_auto','Groupama Auto','Groupama Auto','https://www.groupama.fr/assurance-auto',array['groupama.fr','www.groupama.fr']::text[],'ASSISTANCE_INSURANCE','FINANCE_INSURANCE','FINANCE','PROFESSIONAL','REFERENCE_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',312,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Assistance, dépannage, garantie et assurance'),
    ('report_allianz_auto_f0408b37fa','allianz_auto','Allianz Auto','Allianz Auto','https://www.allianz.fr/assurance-particulier/vehicules/assurance-auto.html',array['allianz.fr','www.allianz.fr']::text[],'ASSISTANCE_INSURANCE','FINANCE_INSURANCE','FINANCE','PROFESSIONAL','REFERENCE_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',313,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Assistance, dépannage, garantie et assurance'),
    ('report_axa_auto_23f8f084c5','axa_auto','AXA Auto','AXA Auto','https://www.axa.fr/assurance-auto.html',array['axa.fr','www.axa.fr']::text[],'ASSISTANCE_INSURANCE','FINANCE_INSURANCE','FINANCE','PROFESSIONAL','REFERENCE_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',314,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Assistance, dépannage, garantie et assurance'),
    ('report_sos_autoroute_412c742d2b','sos_autoroute','SOS Autoroute','SOS Autoroute','https://www.sosautoroute.fr/',array['sosautoroute.fr','www.sosautoroute.fr']::text[],'ASSISTANCE_INSURANCE','FINANCE_INSURANCE','HOME_OR_CATALOG','PROFESSIONAL','REFERENCE_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',315,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Assistance, dépannage, garantie et assurance'),
    ('report_vinci_autoroutes_b098b0114d','vinci_autoroutes','VINCI Autoroutes','VINCI Autoroutes','https://www.vinci-autoroutes.com/',array['vinci-autoroutes.com','www.vinci-autoroutes.com']::text[],'ASSISTANCE_INSURANCE','FINANCE_INSURANCE','HOME_OR_CATALOG','PROFESSIONAL','REFERENCE_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',316,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Assistance, dépannage, garantie et assurance'),
    ('report_aprr_area_a23418285b','aprr_area','APRR / AREA','APRR / AREA','https://voyage.aprr.fr/',array['voyage.aprr.fr']::text[],'ASSISTANCE_INSURANCE','FINANCE_INSURANCE','HOME_OR_CATALOG','PROFESSIONAL','REFERENCE_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',317,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Assistance, dépannage, garantie et assurance'),
    ('report_sanef_9a9d1e4ad9','sanef','Sanef','Sanef','https://www.sanef.com/',array['sanef.com','www.sanef.com']::text[],'ASSISTANCE_INSURANCE','FINANCE_INSURANCE','HOME_OR_CATALOG','PROFESSIONAL','REFERENCE_ONLY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',318,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Assistance, dépannage, garantie et assurance'),
    ('report_amazon_france_auto_et_moto_5a3c48757a','amazon_france_auto_et_moto','Amazon France – Auto et Moto','Amazon France – Auto et Moto','https://www.amazon.fr/auto-moto/b?ie=UTF8&node=1571265031',array['amazon.fr','www.amazon.fr']::text[],'GENERAL_MARKETPLACE','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',324,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Marketplaces généralistes proposant des offres automobiles'),
    ('report_cdiscount_auto_75fff72b8b','cdiscount_auto','Cdiscount Auto','Cdiscount Auto','https://www.cdiscount.com/auto/r-133.html',array['cdiscount.com','www.cdiscount.com']::text[],'GENERAL_MARKETPLACE','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',325,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Marketplaces généralistes proposant des offres automobiles'),
    ('report_rakuten_auto_moto_b0194f9881','rakuten_auto_moto','Rakuten Auto-Moto','Rakuten Auto-Moto','https://fr.shopping.rakuten.com/nav/Auto-Moto',array['fr.shopping.rakuten.com']::text[],'GENERAL_MARKETPLACE','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',326,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Marketplaces généralistes proposant des offres automobiles'),
    ('report_manomano_auto_74412651c8','manomano_auto','ManoMano Auto','ManoMano Auto','https://www.manomano.fr/cat/accessoires+auto',array['manomano.fr','www.manomano.fr']::text[],'GENERAL_MARKETPLACE','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',327,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Marketplaces généralistes proposant des offres automobiles'),
    ('report_ebay_auto_0cf439bdbc','ebay_auto','eBay Auto','eBay Auto','https://www.ebay.fr/b/Auto-moto-pieces-accessoires/9800/bn_7000259124',array['ebay.fr','www.ebay.fr']::text[],'GENERAL_MARKETPLACE','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',328,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Marketplaces généralistes proposant des offres automobiles'),
    ('report_aliexpress_49c8f31ecc','aliexpress','AliExpress','AliExpress','https://fr.aliexpress.com/',array['fr.aliexpress.com']::text[],'GENERAL_MARKETPLACE','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',329,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Marketplaces généralistes proposant des offres automobiles'),
    ('report_temu_france_8e0bcb8ccc','temu_france','Temu France','Temu France','https://www.temu.com/fr',array['temu.com','www.temu.com']::text[],'GENERAL_MARKETPLACE','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',330,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Marketplaces généralistes proposant des offres automobiles'),
    ('report_carrefour_1726659194','carrefour','Carrefour','Carrefour','https://www.carrefour.fr/r/auto-moto',array['carrefour.fr','www.carrefour.fr']::text[],'GENERAL_MARKETPLACE','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',331,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Marketplaces généralistes proposant des offres automobiles'),
    ('report_e_leclerc_auto_9829f9f5d7','e_leclerc_auto','E.Leclerc Auto','E.Leclerc Auto','https://www.e-leclerc.com/catalogue/rayons/auto-moto',array['e-leclerc.com','www.e-leclerc.com']::text[],'GENERAL_MARKETPLACE','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',332,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Marketplaces généralistes proposant des offres automobiles'),
    ('report_facebook_marketplace_32a8a9ce66','facebook_marketplace','Facebook Marketplace','Facebook Marketplace','https://www.facebook.com/marketplace/category/auto-parts',array['facebook.com','www.facebook.com']::text[],'GENERAL_MARKETPLACE','DISCOVERY_ONLY','HOME_OR_CATALOG','COMMUNITY_OR_MARKETPLACE','DISABLED_BY_POLICY','QUARANTINE_ONLY',false,80,168,'FR','deep-research-report.md',333,'Cartographie des sources d’offres commerciales automobiles valables en France > Après-vente, pièces, assistance et marketplaces > Marketplaces généralistes proposant des offres automobiles'),
    ('report_service_public_achat_dun_vehicule_89ba0f41d0','service_public_achat_dun_vehic','Service-Public – achat d’un véhicule','Service-Public – achat d’un véhicule','https://www.service-public.fr/particuliers/vosdroits/F24254',array['service-public.fr','www.service-public.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','AFTER_SALES','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',341,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_service_public_vente_ou_don_dun_vehicule_7194887f20','service_public_vente_ou_don_du','Service-Public – vente ou don d’un véhicule','Service-Public – vente ou don d’un véhicule','https://www.service-public.fr/particuliers/vosdroits/F1707',array['service-public.fr','www.service-public.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','AFTER_SALES','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',342,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_service_public_loa_et_lld_7546451a93','service_public_loa_et_lld','Service-Public – LOA et LLD','Service-Public – LOA et LLD','https://www.service-public.fr/particuliers/vosdroits/F2437',array['service-public.fr','www.service-public.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','AFTER_SALES','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',343,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_service_public_garantie_de_conformite_ae4137ccb6','service_public_garantie_de_con','Service-Public – garantie de conformité','Service-Public – garantie de conformité','https://www.service-public.fr/particuliers/vosdroits/F11094',array['service-public.fr','www.service-public.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','AFTER_SALES','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',344,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_service_public_vices_caches_69f7040b47','service_public_vices_caches','Service-Public – vices cachés','Service-Public – vices cachés','https://www.service-public.fr/particuliers/vosdroits/F11007',array['service-public.fr','www.service-public.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','AFTER_SALES','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',345,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_dgccrf_achat_dun_vehicule_neuf_c85cd13977','dgccrf_achat_dun_vehicule_neuf','DGCCRF – achat d’un véhicule neuf','DGCCRF – achat d’un véhicule neuf','https://www.economie.gouv.fr/dgccrf/les-fiches-pratiques/achat-dun-vehicule-neuf-quelles-sont-les-obligations-du-vendeur',array['economie.gouv.fr','www.economie.gouv.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','REFERENCE','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',346,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_dgccrf_achat_dun_vehicule_doccasion_0743e95b2f','dgccrf_achat_dun_vehicule_docc','DGCCRF – achat d’un véhicule d’occasion','DGCCRF – achat d’un véhicule d’occasion','https://www.economie.gouv.fr/dgccrf/les-fiches-pratiques/achat-dun-vehicule-doccasion-quelles-sont-les-obligations-du-vendeur',array['economie.gouv.fr','www.economie.gouv.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','USED_OR_STOCK','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',347,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_dgccrf_vehicules_et_deplacements_bb724a7453','dgccrf_vehicules_et_deplacemen','DGCCRF – véhicules et déplacements','DGCCRF – véhicules et déplacements','https://www.economie.gouv.fr/dgccrf/les-fiches-pratiques/vehicules-et-deplacements',array['economie.gouv.fr','www.economie.gouv.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','REFERENCE','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',348,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_signalconso_043f8f1477','signalconso','SignalConso','SignalConso','https://signal.conso.gouv.fr/',array['signal.conso.gouv.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','HOME_OR_CATALOG','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',349,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_histovec_f9257b7bea','histovec','HistoVec','HistoVec','https://histovec.interieur.gouv.fr/',array['histovec.interieur.gouv.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','REFERENCE','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',350,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_ants_12b0e02dec','ants','ANTS','ANTS','https://ants.gouv.fr/',array['ants.gouv.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','HOME_OR_CATALOG','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',351,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_france_titres_db031b4bd5','france_titres','France Titres','France Titres','https://immatriculation.ants.gouv.fr/',array['immatriculation.ants.gouv.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','HOME_OR_CATALOG','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',352,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_ministere_de_la_transition_ecologique_aide_7fc270ab9d','ministere_de_la_transition_eco','Ministère de la Transition écologique – aides véhicules','Ministère de la Transition écologique – aides véhicules','https://www.ecologie.gouv.fr/politiques-publiques/prime-retrofit-bonus-ecologique-toutes-aides-faveur-lacquisition-vehicules',array['ecologie.gouv.fr','www.ecologie.gouv.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','REFERENCE','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',353,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_coup_de_pouce_vehicules_electriques_77ce37f9da','coup_de_pouce_vehicules_electr','Coup de pouce véhicules électriques','Coup de pouce véhicules électriques','https://www.ecologie.gouv.fr/politiques-publiques/coup-pouce-vehicules-particuliers-electriques',array['ecologie.gouv.fr','www.ecologie.gouv.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','REFERENCE','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',354,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_leasing_social_8f7ac590d3','leasing_social','Leasing social','Leasing social','https://www.ecologie.gouv.fr/politiques-publiques/faq-leasing-social',array['ecologie.gouv.fr','www.ecologie.gouv.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','FINANCE','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',355,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_jechangemavoiture_158212de15','jechangemavoiture','JeChangeMaVoiture','JeChangeMaVoiture','https://jechangemavoiture.gouv.fr/',array['jechangemavoiture.gouv.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','HOME_OR_CATALOG','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',357,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_critair_fb4651c144','critair','Crit’Air','Crit’Air','https://www.certificat-air.gouv.fr/',array['certificat-air.gouv.fr','www.certificat-air.gouv.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','HOME_OR_CATALOG','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',358,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_prix_des_carburants_6af8bf4605','prix_des_carburants','Prix des carburants','Prix des carburants','https://www.prix-carburants.gouv.fr/',array['prix-carburants.gouv.fr','www.prix-carburants.gouv.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','HOME_OR_CATALOG','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',359,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_utac_otc_5ef13bab92','utac_otc','UTAC-OTC','UTAC-OTC','https://www.utac-otc.com/',array['utac-otc.com','www.utac-otc.com']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','HOME_OR_CATALOG','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',360,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_rappelconso_6fdec3df70','rappelconso','RappelConso','RappelConso','https://rappel.conso.gouv.fr/',array['rappel.conso.gouv.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','REFERENCE','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',361,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_safety_gate_de_lunion_europeenne_3ce3db558d','safety_gate_de_lunion_europeen','Safety Gate de l’Union européenne','Safety Gate de l’Union européenne','https://ec.europa.eu/safety-gate-alerts/screen/webReport',array['ec.europa.eu']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','HOME_OR_CATALOG','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',362,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_legifrance_5130ba2661','legifrance','Légifrance','Légifrance','https://www.legifrance.gouv.fr/',array['legifrance.gouv.fr','www.legifrance.gouv.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','REFERENCE','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',363,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_orias_39c4098ac6','orias','ORIAS','ORIAS','https://www.orias.fr/',array['orias.fr','www.orias.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','REFERENCE','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',364,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_regafi_b1bc15d714','regafi','REGAFI','REGAFI','https://www.regafi.fr/',array['regafi.fr','www.regafi.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','REFERENCE','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',365,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_mediateur_de_lasf_34fb2aeed1','mediateur_de_lasf','Médiateur de l’ASF','Médiateur de l’ASF','https://lemediateur.asf-france.com/',array['lemediateur.asf-france.com']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','HOME_OR_CATALOG','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',366,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_mediateur_mobilians_1e15b60b8e','mediateur_mobilians','Médiateur Mobilians','Médiateur Mobilians','https://www.mediateur-mobilians.fr/',array['mediateur-mobilians.fr','www.mediateur-mobilians.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','HOME_OR_CATALOG','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',367,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_mediateur_fna_b38fed33c2','mediateur_fna','Médiateur FNA','Médiateur FNA','https://www.mediateur.fna.fr/',array['mediateur.fna.fr','www.mediateur.fna.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','HOME_OR_CATALOG','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',368,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_ufc_que_choisir_bca808cea3','ufc_que_choisir','UFC-Que Choisir','UFC-Que Choisir','https://www.quechoisir.org/thematique-automobile-t10',array['quechoisir.org','www.quechoisir.org']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','HOME_OR_CATALOG','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',369,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_inc_institut_national_de_la_consommation_799a40478f','inc_institut_national_de_la_co','INC – Institut national de la consommation','INC – Institut national de la consommation','https://www.inc-conso.fr/',array['inc-conso.fr','www.inc-conso.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','HOME_OR_CATALOG','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',370,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_sirene_annuaire_des_entreprises_5cbe8fca23','sirene_annuaire_des_entreprise','SIRENE / Annuaire des entreprises','SIRENE / Annuaire des entreprises','https://annuaire-entreprises.data.gouv.fr/',array['annuaire-entreprises.data.gouv.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','HOME_OR_CATALOG','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',371,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_bodacc_f8649d3736','bodacc','BODACC','BODACC','https://www.bodacc.fr/',array['bodacc.fr','www.bodacc.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','HOME_OR_CATALOG','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',372,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires'),
    ('report_acheter_un_vehicule_dans_lunion_europeenne_cf23038953','acheter_un_vehicule_dans_lunio','Acheter un véhicule dans l’Union européenne','Acheter un véhicule dans l’Union européenne','https://www.service-public.fr/particuliers/vosdroits/F2991',array['service-public.fr','www.service-public.fr']::text[],'INSTITUTIONAL_REFERENCE','REFERENCE_ONLY','AFTER_SALES','PRIMARY','REFERENCE_ONLY','REFERENCE_ONLY',false,80,168,'FR','deep-research-report.md',373,'Cartographie des sources d’offres commerciales automobiles valables en France > Sources institutionnelles et réglementaires')
)
insert into public.commercial_offer_sources (
  source_key,
  brand_code,
  source_name,
  operator_name,
  source_url,
  allowed_hostnames,
  status,
  robots_status,
  source_category,
  source_purpose,
  endpoint_type,
  trust_tier,
  monitoring_mode,
  publication_policy,
  search_enabled,
  search_priority,
  check_frequency_hours,
  next_check_at,
  territory_code,
  report_reference,
  report_line,
  report_section,
  metadata,
  updated_at
)
select
  source_catalog.source_key::text,
  source_catalog.brand_code::text,
  source_catalog.source_name::text,
  source_catalog.operator_name::text,
  source_catalog.source_url::text,
  source_catalog.allowed_hostnames::text[],
  case
    when source_catalog.search_enabled::boolean
      and source_catalog.source_purpose::text = 'CURRENT_VEHICLE'
      then 'ACTIVE'
    else 'PAUSED'
  end,
  'UNKNOWN',
  source_catalog.source_category::text,
  source_catalog.source_purpose::text,
  source_catalog.endpoint_type::text,
  source_catalog.trust_tier::text,
  source_catalog.monitoring_mode::text,
  source_catalog.publication_policy::text,
  source_catalog.search_enabled::boolean,
  source_catalog.search_priority::integer,
  source_catalog.check_frequency_hours::integer,
  case
    when source_catalog.search_enabled::boolean
      then now()
    else null
  end,
  source_catalog.territory_code::text,
  source_catalog.report_reference::text,
  source_catalog.report_line::integer,
  source_catalog.report_section::text,
  jsonb_build_object(
    'catalog_version', 2,
    'automatic_publication', false,
    'derived_from_user_report', true
  ),
  now()
from source_catalog
on conflict (source_key) do update set
  brand_code = excluded.brand_code,
  source_name = excluded.source_name,
  operator_name = excluded.operator_name,
  source_url = excluded.source_url,
  allowed_hostnames = excluded.allowed_hostnames,
  source_category = excluded.source_category,
  source_purpose = excluded.source_purpose,
  endpoint_type = excluded.endpoint_type,
  trust_tier = excluded.trust_tier,
  monitoring_mode = excluded.monitoring_mode,
  publication_policy = excluded.publication_policy,
  search_enabled = excluded.search_enabled,
  search_priority = excluded.search_priority,
  check_frequency_hours = excluded.check_frequency_hours,
  next_check_at = case
    when excluded.search_enabled then
      coalesce(
        public.commercial_offer_sources.next_check_at,
        now()
      )
    else null
  end,
  territory_code = excluded.territory_code,
  report_reference = excluded.report_reference,
  report_line = excluded.report_line,
  report_section = excluded.report_section,
  status = case
    when excluded.search_enabled
      and excluded.source_purpose = 'CURRENT_VEHICLE'
      then case
        when public.commercial_offer_sources.status = 'BLOCKED'
          then 'BLOCKED'
        else 'ACTIVE'
      end
    else 'PAUSED'
  end,
  metadata = coalesce(
    public.commercial_offer_sources.metadata,
    '{}'::jsonb
  ) || excluded.metadata,
  updated_at = now();

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
  '17 */2 * * *',
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
      'trigger', 'scheduled-catalog-v2',
      'force', false,
      'batch_size', 5
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
    'trigger', 'installation-catalog-v2',
    'force', false,
    'batch_size', 5
  )
);

comment on table public.commercial_offer_discovered_urls is
  'Liens internes ressemblant à des pages d’offres. Ils restent en '
  'quarantaine et ne sont jamais publiés automatiquement.';

comment on column public.commercial_offer_sources.search_enabled is
  'Autorise uniquement la recherche technique. Ne vaut jamais autorisation '
  'de publication automatique.';

comment on column public.commercial_offer_sources.publication_policy is
  'VALIDATED_RULES_ONLY impose une règle structurée validée ; '
  'QUARANTINE_ONLY interdit toute publication directe.';

commit;
