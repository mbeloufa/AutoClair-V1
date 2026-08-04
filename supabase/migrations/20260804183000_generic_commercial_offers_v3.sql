begin;

do $precheck$
declare
  v_missing text[] := array[]::text[];
begin
  if to_regclass('public.commercial_offer_sources') is null then
    v_missing := array_append(v_missing, 'commercial_offer_sources');
  end if;

  if to_regclass('public.commercial_offers') is null then
    v_missing := array_append(v_missing, 'commercial_offers');
  end if;

  if to_regclass('public.commercial_offer_candidates') is null then
    v_missing := array_append(v_missing, 'commercial_offer_candidates');
  end if;

  if to_regclass('public.commercial_offer_discovered_urls') is null then
    v_missing := array_append(
      v_missing,
      'commercial_offer_discovered_urls'
    );
  end if;

  if to_regprocedure(
    'public.validate_commercial_offer_sync_secret(text)'
  ) is null then
    v_missing := array_append(
      v_missing,
      'validate_commercial_offer_sync_secret'
    );
  end if;

  if cardinality(v_missing) > 0 then
    raise exception
      'GENERIC_COMMERCIAL_OFFERS_PRECHECK_FAILED:%',
      array_to_string(v_missing, ',');
  end if;
end
$precheck$;

create table if not exists public.commercial_offer_brand_aliases (
  alias_key text primary key,
  canonical_brand_code text not null,
  created_at timestamptz not null default now()
);

alter table public.commercial_offer_brand_aliases enable row level security;
revoke all
  on table public.commercial_offer_brand_aliases
  from public, anon, authenticated;
grant select, insert, update, delete
  on table public.commercial_offer_brand_aliases
  to service_role;

insert into public.commercial_offer_brand_aliases (
  alias_key,
  canonical_brand_code
)
values
  ('volkswagen vehicules utilitaires', 'volkswagen'),
  ('volkswagen utilitaires', 'volkswagen'),
  ('rolls royce motor cars', 'rolls_royce'),
  ('mercedes benz', 'mercedes_benz'),
  ('land rover', 'land_rover'),
  ('alfa romeo', 'alfa_romeo'),
  ('aston martin', 'aston_martin'),
  ('mg motor', 'mg'),
  ('lynk co', 'lynk_co'),
  ('ineos grenadier', 'ineos'),
  ('mitsubishi motors', 'mitsubishi'),
  ('volkswagen', 'volkswagen'),
  ('citroen', 'citroen'),
  ('citroën', 'citroen'),
  ('renault', 'renault'),
  ('dacia', 'dacia'),
  ('peugeot', 'peugeot'),
  ('ds automobiles', 'ds'),
  ('opel', 'opel'),
  ('vauxhall', 'opel'),
  ('fiat', 'fiat'),
  ('abarth', 'abarth'),
  ('jeep', 'jeep'),
  ('lancia', 'lancia'),
  ('ford', 'ford'),
  ('audi', 'audi'),
  ('skoda', 'skoda'),
  ('škoda', 'skoda'),
  ('seat', 'seat'),
  ('cupra', 'cupra'),
  ('bmw', 'bmw'),
  ('mini', 'mini'),
  ('smart', 'smart'),
  ('porsche', 'porsche'),
  ('toyota', 'toyota'),
  ('lexus', 'lexus'),
  ('nissan', 'nissan'),
  ('honda', 'honda'),
  ('mazda', 'mazda'),
  ('suzuki', 'suzuki'),
  ('subaru', 'subaru'),
  ('isuzu', 'isuzu'),
  ('hyundai', 'hyundai'),
  ('kia', 'kia'),
  ('volvo', 'volvo'),
  ('jaguar', 'jaguar'),
  ('tesla', 'tesla'),
  ('byd', 'byd'),
  ('leapmotor', 'leapmotor'),
  ('xpeng', 'xpeng'),
  ('polestar', 'polestar'),
  ('lotus', 'lotus'),
  ('maserati', 'maserati'),
  ('bentley', 'bentley'),
  ('ferrari', 'ferrari'),
  ('lamborghini', 'lamborghini'),
  ('mclaren', 'mclaren'),
  ('rolls royce', 'rolls_royce'),
  ('alpine', 'alpine')
on conflict (alias_key) do update set
  canonical_brand_code = excluded.canonical_brand_code;

create or replace function private.autoclair_offer_brand(
  p_value text
)
returns text
language sql
stable
set search_path = ''
as $function$
  with normalized as (
    select private.autoclair_offer_normalize_words(p_value) as value
  )
  select coalesce(
    (
      select a.canonical_brand_code
      from public.commercial_offer_brand_aliases a
      cross join normalized n
      where
        (' ' || n.value || ' ') like
        ('% ' || private.autoclair_offer_normalize_words(a.alias_key) || ' %')
        or n.value =
          private.autoclair_offer_normalize_words(a.alias_key)
        or n.value like
          private.autoclair_offer_normalize_words(a.alias_key) || ' %'
      order by
        length(
          private.autoclair_offer_normalize_words(a.alias_key)
        ) desc
      limit 1
    ),
    nullif((select value from normalized), ''),
    '*'
  );
$function$;

create or replace function private.autoclair_offer_model_tokens_match(
  p_targeting_text text,
  p_vehicle_model text
)
returns boolean
language sql
immutable
set search_path = ''
as $function$
  with normalized as (
    select
      private.autoclair_offer_normalize_words(p_vehicle_model)
        as model_value,
      ' ' ||
      private.autoclair_offer_normalize_words(p_targeting_text) ||
      ' ' as target_value
  ),
  model_tokens as (
    select token
    from normalized n,
      regexp_split_to_table(n.model_value, '\s+') token
    where length(token) >= 2
      and token not in (
        'de',
        'du',
        'la',
        'le',
        'les',
        'new',
        'nouveau',
        'nouvelle',
        'model',
        'modele'
      )
  )
  select
    exists (
      select 1
      from normalized n
      where n.model_value <> ''
        and position(
          ' ' || n.model_value || ' '
          in n.target_value
        ) > 0
    )
    or (
      exists (select 1 from model_tokens)
      and not exists (
        select 1
        from model_tokens mt
        cross join normalized n
        where position(
          ' ' || mt.token || ' '
          in n.target_value
        ) = 0
      )
    );
$function$;

revoke all
  on function private.autoclair_offer_brand(text)
  from public, anon, authenticated;

revoke all
  on function private.autoclair_offer_model_tokens_match(text, text)
  from public, anon, authenticated;

alter table public.commercial_offer_sources
  add column if not exists canonical_brand_code text
    not null default '*',
  add column if not exists auto_publish_threshold integer
    not null default 86,
  add column if not exists crawl_depth integer
    not null default 1,
  add column if not exists max_pages_per_cycle integer
    not null default 4,
  add column if not exists last_extraction_at timestamptz,
  add column if not exists extracted_offer_count integer
    not null default 0;

do $source_constraints$
begin
  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'commercial_offer_sources_auto_publish_valid'
      and conrelid = 'public.commercial_offer_sources'::regclass
  ) then
    alter table public.commercial_offer_sources
      add constraint commercial_offer_sources_auto_publish_valid
      check (
        auto_publish_threshold between 70 and 100
        and crawl_depth between 0 and 2
        and max_pages_per_cycle between 1 and 10
      );
  end if;

  alter table public.commercial_offer_sources
    drop constraint if exists
      commercial_offer_sources_publication_allowed;

  alter table public.commercial_offer_sources
    add constraint commercial_offer_sources_publication_allowed
    check (
      publication_policy in (
        'VALIDATED_RULES_ONLY',
        'AUTO_HIGH_CONFIDENCE',
        'QUARANTINE_ONLY',
        'REFERENCE_ONLY'
      )
    );
end
$source_constraints$;

update public.commercial_offer_sources s
set
  canonical_brand_code = case
    when s.source_category in (
      'AFTER_SALES_NETWORK',
      'GARAGE_COMPARATOR',
      'PARTS_TYRES',
      'GENERAL_MARKETPLACE',
      'VEHICLE_MARKETPLACE',
      'VEHICLE_COMPARATOR',
      'DEALER_GROUP'
    ) then '*'
    else private.autoclair_offer_brand(
      concat_ws(
        ' ',
        s.brand_code,
        s.operator_name,
        s.source_name
      )
    )
  end,
  publication_policy = case
    when s.search_enabled
      and s.trust_tier = 'PRIMARY'
      and s.source_category in (
        'OFFICIAL_MANUFACTURER',
        'OFFICIAL_SERVICE_FINANCE'
      )
      then 'AUTO_HIGH_CONFIDENCE'
    when s.search_enabled
      and s.trust_tier = 'PROFESSIONAL'
      and s.source_purpose = 'CURRENT_VEHICLE'
      then 'AUTO_HIGH_CONFIDENCE'
    else s.publication_policy
  end,
  auto_publish_threshold = case
    when s.trust_tier = 'PRIMARY' then 80
    when s.trust_tier = 'PROFESSIONAL' then 86
    else 100
  end,
  crawl_depth = case
    when s.monitoring_mode = 'LINK_DISCOVERY_ONLY' then 2
    when s.monitoring_mode in ('HTML_DISCOVERY', 'HTML_RULES') then 1
    else 0
  end,
  max_pages_per_cycle = case
    when s.trust_tier = 'PRIMARY' then 5
    else 3
  end,
  metadata = coalesce(s.metadata, '{}'::jsonb) ||
    jsonb_build_object(
      'catalog_version', 3,
      'generic_extraction', true,
      'automatic_publication',
        s.search_enabled
        and (
          (
            s.trust_tier = 'PRIMARY'
            and s.source_category in (
              'OFFICIAL_MANUFACTURER',
              'OFFICIAL_SERVICE_FINANCE'
            )
          )
          or (
            s.trust_tier = 'PROFESSIONAL'
            and s.source_purpose = 'CURRENT_VEHICLE'
          )
        )
    ),
  updated_at = now();

alter table public.commercial_offers
  add column if not exists offer_context text
    not null default 'CURRENT_VEHICLE',
  add column if not exists targeting_scope text
    not null default 'BRAND',
  add column if not exists targeting_text text
    not null default '',
  add column if not exists auto_extracted boolean
    not null default false,
  add column if not exists extraction_confidence integer,
  add column if not exists extraction_method text,
  add column if not exists source_page_url text,
  add column if not exists source_fingerprint text,
  add column if not exists evidence jsonb
    not null default '{}'::jsonb,
  add column if not exists first_seen_at timestamptz
    not null default now(),
  add column if not exists last_seen_at timestamptz
    not null default now(),
  add column if not exists miss_count integer
    not null default 0;

do $offer_constraints$
begin
  alter table public.commercial_offers
    drop constraint if exists commercial_offers_category_allowed;

  alter table public.commercial_offers
    add constraint commercial_offers_category_allowed
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
        'PARTS',
        'NEW_VEHICLE',
        'USED_VEHICLE',
        'FINANCE',
        'INSURANCE',
        'ASSISTANCE',
        'OTHER'
      )
    );

  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'commercial_offers_context_allowed'
      and conrelid = 'public.commercial_offers'::regclass
  ) then
    alter table public.commercial_offers
      add constraint commercial_offers_context_allowed
      check (
        offer_context in (
          'CURRENT_VEHICLE',
          'VEHICLE_PURCHASE',
          'FINANCE_INSURANCE'
        )
      );
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'commercial_offers_targeting_allowed'
      and conrelid = 'public.commercial_offers'::regclass
  ) then
    alter table public.commercial_offers
      add constraint commercial_offers_targeting_allowed
      check (
        targeting_scope in (
          'ALL_VEHICLES',
          'BRAND',
          'MODEL',
          'UNKNOWN'
        )
      );
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'commercial_offers_extraction_valid'
      and conrelid = 'public.commercial_offers'::regclass
  ) then
    alter table public.commercial_offers
      add constraint commercial_offers_extraction_valid
      check (
        extraction_confidence is null
        or extraction_confidence between 0 and 100
      );
  end if;
end
$offer_constraints$;

update public.commercial_offers o
set
  offer_context = 'CURRENT_VEHICLE',
  targeting_scope = case
    when cardinality(o.model_patterns) > 0 then 'MODEL'
    when '*' = any(o.brands) then 'ALL_VEHICLES'
    else 'BRAND'
  end,
  targeting_text = private.autoclair_offer_normalize_words(
    concat_ws(
      ' ',
      o.title,
      o.summary,
      o.conditions_summary,
      array_to_string(o.model_patterns, ' ')
    )
  ),
  source_page_url = coalesce(o.source_page_url, o.official_url),
  first_seen_at = coalesce(o.first_seen_at, o.created_at),
  last_seen_at = coalesce(o.last_seen_at, o.last_verified_at, o.updated_at);

create unique index if not exists
  commercial_offers_source_fingerprint_unique
  on public.commercial_offers(source_id, source_fingerprint)
  where source_fingerprint is not null;

create index if not exists commercial_offers_context_idx
  on public.commercial_offers(
    offer_context,
    status,
    last_verified_at desc
  );

create index if not exists commercial_offers_auto_source_page_idx
  on public.commercial_offers(
    source_id,
    source_page_url,
    auto_extracted,
    last_seen_at desc
  );

alter table public.commercial_offer_candidates
  add column if not exists structured_payload jsonb
    not null default '{}'::jsonb,
  add column if not exists extraction_confidence integer,
  add column if not exists extraction_method text,
  add column if not exists rejection_reasons text[]
    not null default array[]::text[],
  add column if not exists source_page_url text;

do $candidate_constraints$
begin
  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'commercial_offer_candidates_confidence_valid'
      and conrelid = 'public.commercial_offer_candidates'::regclass
  ) then
    alter table public.commercial_offer_candidates
      add constraint commercial_offer_candidates_confidence_valid
      check (
        extraction_confidence is null
        or extraction_confidence between 0 and 100
      );
  end if;
end
$candidate_constraints$;

create table if not exists public.commercial_offer_crawl_targets (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null
    references public.commercial_offer_sources(id) on delete cascade,
  target_url text not null,
  url_hash text not null,
  target_kind text not null default 'ROOT',
  depth integer not null default 0,
  status text not null default 'ACTIVE',
  priority integer not null default 50,
  check_frequency_hours integer not null default 72,
  next_check_at timestamptz,
  robots_status text not null default 'UNKNOWN',
  last_http_status integer,
  last_checked_at timestamptz,
  last_success_at timestamptz,
  failure_count integer not null default 0,
  last_error_code text,
  content_hash text,
  parent_url text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (source_id, url_hash),
  constraint commercial_offer_crawl_targets_kind_allowed
    check (target_kind in ('ROOT', 'DISCOVERED')),
  constraint commercial_offer_crawl_targets_status_allowed
    check (status in ('ACTIVE', 'PAUSED', 'ERROR', 'BLOCKED')),
  constraint commercial_offer_crawl_targets_depth_valid
    check (depth between 0 and 2),
  constraint commercial_offer_crawl_targets_schedule_valid
    check (
      priority between 1 and 100
      and check_frequency_hours between 6 and 720
    ),
  constraint commercial_offer_crawl_targets_robots_allowed
    check (
      robots_status in (
        'UNKNOWN',
        'ALLOWED',
        'DISALLOWED',
        'UNAVAILABLE'
      )
    )
);

create index if not exists commercial_offer_crawl_targets_due_idx
  on public.commercial_offer_crawl_targets(
    status,
    next_check_at,
    priority,
    target_kind
  )
  where status in ('ACTIVE', 'ERROR');

alter table public.commercial_offer_crawl_targets enable row level security;
revoke all
  on table public.commercial_offer_crawl_targets
  from public, anon, authenticated;
grant select, insert, update, delete
  on table public.commercial_offer_crawl_targets
  to service_role;

insert into public.commercial_offer_crawl_targets (
  source_id,
  target_url,
  url_hash,
  target_kind,
  depth,
  status,
  priority,
  check_frequency_hours,
  next_check_at,
  metadata,
  updated_at
)
select
  s.id,
  s.source_url,
  encode(
    extensions.digest(lower(trim(s.source_url)), 'sha256'),
    'hex'
  ),
  'ROOT',
  0,
  case
    when s.search_enabled then 'ACTIVE'
    else 'PAUSED'
  end,
  s.search_priority,
  s.check_frequency_hours,
  case
    when s.search_enabled then now()
    else null
  end,
  jsonb_build_object(
    'monitoring_mode', s.monitoring_mode,
    'publication_policy', s.publication_policy,
    'seeded_from_catalog', true
  ),
  now()
from public.commercial_offer_sources s
on conflict (source_id, url_hash) do update set
  target_url = excluded.target_url,
  target_kind = 'ROOT',
  depth = 0,
  status = excluded.status,
  priority = excluded.priority,
  check_frequency_hours = excluded.check_frequency_hours,
  next_check_at = case
    when excluded.status = 'ACTIVE' then
      least(
        coalesce(
          public.commercial_offer_crawl_targets.next_check_at,
          now()
        ),
        now()
      )
    else null
  end,
  metadata = coalesce(
    public.commercial_offer_crawl_targets.metadata,
    '{}'::jsonb
  ) || excluded.metadata,
  updated_at = now();

insert into public.commercial_offer_crawl_targets (
  source_id,
  target_url,
  url_hash,
  target_kind,
  depth,
  status,
  priority,
  check_frequency_hours,
  next_check_at,
  parent_url,
  metadata,
  updated_at
)
select
  d.source_id,
  d.discovered_url,
  d.url_hash,
  'DISCOVERED',
  1,
  'ACTIVE',
  greatest(1, 40 - floor(d.discovery_score / 5.0)::integer),
  48,
  now(),
  s.source_url,
  jsonb_build_object(
    'migrated_from_discovered_urls', true,
    'discovery_score', d.discovery_score
  ),
  now()
from public.commercial_offer_discovered_urls d
join public.commercial_offer_sources s on s.id = d.source_id
where d.status in ('PENDING_REVIEW', 'APPROVED')
  and d.discovery_score >= 45
  and s.search_enabled = true
  and s.crawl_depth >= 1
on conflict (source_id, url_hash) do update set
  priority = least(
    public.commercial_offer_crawl_targets.priority,
    excluded.priority
  ),
  next_check_at = least(
    coalesce(
      public.commercial_offer_crawl_targets.next_check_at,
      now()
    ),
    now()
  ),
  status = case
    when public.commercial_offer_crawl_targets.status = 'BLOCKED'
      then 'BLOCKED'
    else 'ACTIVE'
  end,
  updated_at = now();


-- URLs précises fournies lors du diagnostic Audi. Elles servent uniquement
-- de cibles de régression du moteur générique : aucune offre Audi n'est
-- codée dans cette migration.
with regression_targets(source_key, target_url, priority) as (
  values
    (
      'report_audi_apres_vente_1a1a57df7f',
      'https://www.audi.fr/fr/entretien-reparation/offres-apres-vente/',
      1
    ),
    (
      'report_audi_apres_vente_1a1a57df7f',
      'https://www.audi.fr/fr/entretien-reparation/prestations-apres-vente/controle-technique/',
      1
    )
)
insert into public.commercial_offer_crawl_targets (
  source_id,
  target_url,
  url_hash,
  target_kind,
  depth,
  status,
  priority,
  check_frequency_hours,
  next_check_at,
  parent_url,
  metadata,
  updated_at
)
select
  s.id,
  r.target_url,
  encode(
    extensions.digest(lower(trim(r.target_url)), 'sha256'),
    'hex'
  ),
  'DISCOVERED',
  1,
  'ACTIVE',
  r.priority,
  24,
  now(),
  s.source_url,
  jsonb_build_object(
    'regression_target', true,
    'generic_extraction_only', true,
    'provided_during_user_diagnosis', true
  ),
  now()
from regression_targets r
join public.commercial_offer_sources s
  on s.source_key = r.source_key
on conflict (source_id, url_hash) do update set
  status = case
    when public.commercial_offer_crawl_targets.status = 'BLOCKED'
      then 'BLOCKED'
    else 'ACTIVE'
  end,
  priority = 1,
  next_check_at = now(),
  metadata = coalesce(
    public.commercial_offer_crawl_targets.metadata,
    '{}'::jsonb
  ) || excluded.metadata,
  updated_at = now();

alter table public.commercial_offer_sync_runs
  add column if not exists crawl_target_count integer
    not null default 0,
  add column if not exists auto_published_count integer
    not null default 0,
  add column if not exists auto_updated_count integer
    not null default 0,
  add column if not exists high_confidence_count integer
    not null default 0;

create or replace function public.get_vehicle_commercial_offers(
  p_vehicle_id uuid,
  p_limit integer default 100
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
  v_limit integer := greatest(1, least(coalesce(p_limit, 100), 150));
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
  where s.search_enabled = true
    and s.status in ('ACTIVE', 'ERROR', 'PAUSED')
    and s.last_success_at >= now() - interval '14 days';

  select count(*)::integer
  into v_active_offer_count
  from public.commercial_offers o
  join public.commercial_offer_sources s on s.id = o.source_id
  where o.status = 'ACTIVE'
    and (o.starts_at is null or o.starts_at <= current_date)
    and (o.ends_at is null or o.ends_at >= current_date)
    and o.last_verified_at >= now() - interval '14 days'
    and s.last_success_at >= now() - interval '14 days';

  select max(r.finished_at)
  into v_last_sync
  from public.commercial_offer_sync_runs r
  where r.status in ('SUCCESS', 'PARTIAL');

  with base as (
    select
      o.*,
      s.source_name,
      s.trust_tier,
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
        o.targeting_scope in ('ALL_VEHICLES', 'BRAND', 'UNKNOWN')
        or exists (
          select 1
          from unnest(o.model_patterns) pattern
          where private.autoclair_offer_model_tokens_match(
            private.autoclair_offer_normalize_words(pattern),
            v_vehicle.model
          )
        )
        or private.autoclair_offer_model_tokens_match(
          o.targeting_text,
          v_vehicle.model
        )
      ) as model_match,
      (
        cardinality(o.excluded_model_patterns) > 0
        and exists (
          select 1
          from unnest(o.excluded_model_patterns) pattern
          where private.autoclair_offer_model_tokens_match(
            private.autoclair_offer_normalize_words(pattern),
            v_vehicle.model
          )
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
        where o.offer_context = 'CURRENT_VEHICLE'
          and ms.vehicle_id = v_vehicle.id
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
        where o.offer_context = 'CURRENT_VEHICLE'
          and ve.vehicle_id = v_vehicle.id
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
        offer_context <> 'VEHICLE_PURCHASE'
        or targeting_scope = 'MODEL'
      )
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
          case
            when offer_context = 'CURRENT_VEHICLE' then 48
            else 42
          end
          + case when '*' <> all(brands) then 10 else 3 end
          + case when targeting_scope = 'MODEL' then 14 else 4 end
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
          + case
              when auto_extracted
               and extraction_confidence >= 90
                then 3
              else 0
            end
          - case when recent_matching_event then 18 else 0 end
          - case when requires_manual_eligibility then 8 else 0 end
          - case when requires_existing_contract then 8 else 0 end
        )
      )::integer as relevance_score,
      (
        offer_context = 'CURRENT_VEHICLE'
        and schedule_match
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
          or offer_context = 'VEHICLE_PURCHASE'
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
      (offer_context = 'CURRENT_VEHICLE') desc,
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
        'offer_context', offer_context,
        'targeting_scope', targeting_scope,
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
        'auto_extracted', auto_extracted,
        'extraction_confidence', extraction_confidence,
        'why', to_jsonb(
          array_remove(
            array[
              case
                when targeting_scope = 'MODEL'
                  then 'Le modèle du véhicule est cité dans cette campagne'
                when '*' <> all(brands)
                  then 'La marque du véhicule correspond à cette campagne'
                else 'Cette offre est annoncée pour plusieurs marques'
              end,
              case
                when offer_context = 'VEHICLE_PURCHASE'
                  then 'Offre de renouvellement correspondant au même modèle'
                else null
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
                  then 'Un contrat existant doit être confirmé'
                when requires_network_participation
                  then 'La participation du réseau doit être confirmée'
                else null
              end,
              case
                when auto_extracted
                  then 'Offre extraite automatiquement d’une source surveillée'
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
        (offer_context = 'CURRENT_VEHICLE') desc,
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

revoke all
  on function public.get_vehicle_commercial_offers(uuid, integer)
  from public, anon;

grant execute
  on function public.get_vehicle_commercial_offers(uuid, integer)
  to authenticated, service_role;

create or replace function public.dispatch_commercial_offer_sync(
  p_trigger text default 'scheduled-v3',
  p_batch_size integer default 4
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_request_id bigint;
begin
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
      'trigger', coalesce(p_trigger, 'scheduled-v3'),
      'force', false,
      'batch_size', greatest(1, least(coalesce(p_batch_size, 4), 6))
    )
  )
  into v_request_id;

  return v_request_id;
end
$function$;

create or replace function public.bootstrap_commercial_offer_sync_v3()
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_due_count integer;
begin
  select count(*)::integer
  into v_due_count
  from public.commercial_offer_crawl_targets t
  join public.commercial_offer_sources s on s.id = t.source_id
  where s.search_enabled = true
    and t.status in ('ACTIVE', 'ERROR')
    and (t.next_check_at is null or t.next_check_at <= now());

  if v_due_count > 0 then
    perform public.dispatch_commercial_offer_sync(
      'bootstrap-v3',
      4
    );
  elsif exists (
    select 1
    from cron.job
    where jobname = 'autoclair-bootstrap-commercial-offers-v3'
  ) then
    perform cron.unschedule(
      'autoclair-bootstrap-commercial-offers-v3'
    );
  end if;
end
$function$;

revoke all
  on function public.dispatch_commercial_offer_sync(text, integer)
  from public, anon, authenticated;

revoke all
  on function public.bootstrap_commercial_offer_sync_v3()
  from public, anon, authenticated;

grant execute
  on function public.dispatch_commercial_offer_sync(text, integer)
  to service_role;

grant execute
  on function public.bootstrap_commercial_offer_sync_v3()
  to service_role;

-- La planification et le premier déclenchement sont installés par la
-- migration post-déploiement, après validation de l'Edge Function V3.

comment on table public.commercial_offer_crawl_targets is
  'File de pages racines et pages d’offres découvertes. Une page ne peut '
  'être explorée que sur un domaine déjà autorisé pour sa source.';

comment on column public.commercial_offers.auto_extracted is
  'Vrai uniquement pour une offre structurée par le moteur générique. '
  'La publication exige un score supérieur au seuil propre à la source.';

comment on column public.commercial_offers.targeting_text is
  'Texte normalisé utilisé pour vérifier dynamiquement la correspondance '
  'avec le modèle configuré, sans catalogue statique de modèles.';

comment on column public.commercial_offer_sources.publication_policy is
  'AUTO_HIGH_CONFIDENCE autorise uniquement les extractions déterministes '
  'qui dépassent le seuil de confiance. Les autres restent en quarantaine.';

commit;
