begin;

do $precheck$
declare
  v_missing text[] := array[]::text[];
begin
  if to_regclass('public.documents') is null then
    v_missing := array_append(v_missing, 'public.documents');
  end if;

  if to_regclass('public.document_analyses') is null then
    v_missing := array_append(v_missing, 'public.document_analyses');
  end if;

  if to_regclass('public.vehicles') is null then
    v_missing := array_append(v_missing, 'public.vehicles');
  end if;

  if to_regclass('public.vehicle_events') is null then
    v_missing := array_append(v_missing, 'public.vehicle_events');
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'record_vehicle_event'
  ) then
    v_missing := array_append(
      v_missing,
      'public.record_vehicle_event'
    );
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'recalculate_vehicle_reminders'
  ) then
    v_missing := array_append(
      v_missing,
      'public.recalculate_vehicle_reminders'
    );
  end if;

  if cardinality(v_missing) > 0 then
    raise exception
      'DOCUMENT_CARNET_PRECHECK_FAILED:%',
      array_to_string(v_missing, ',');
  end if;
end
$precheck$;

create schema if not exists private;

create or replace function private.autoclair_normalize_identifier(
  p_value text
)
returns text
language sql
immutable
strict
set search_path = ''
as $function$
  select upper(
    regexp_replace(
      coalesce(p_value, ''),
      '[^A-Za-z0-9]',
      '',
      'g'
    )
  );
$function$;

create or replace function private.autoclair_normalize_words(
  p_value text
)
returns text
language sql
immutable
strict
set search_path = ''
as $function$
  select trim(
    regexp_replace(
      lower(coalesce(p_value, '')),
      '[^a-z0-9]+',
      ' ',
      'g'
    )
  );
$function$;

revoke all
  on function private.autoclair_normalize_identifier(text)
  from public, anon, authenticated;

revoke all
  on function private.autoclair_normalize_words(text)
  from public, anon, authenticated;

create table if not exists public.document_carnet_syncs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  document_id uuid not null
    references public.documents(id) on delete cascade,
  vehicle_id uuid not null
    references public.vehicles(id) on delete cascade,
  analysis_id uuid
    references public.document_analyses(id) on delete cascade,
  event_id uuid
    references public.vehicle_events(id) on delete set null,
  status text not null,
  reason_code text,
  match_method text,
  match_score numeric(5,4),
  event_title text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint document_carnet_syncs_document_unique
    unique (document_id),
  constraint document_carnet_syncs_status_allowed
    check (
      status in (
        'AUTO_CREATED',
        'ALREADY_CREATED',
        'REVIEW_REQUIRED',
        'NOT_APPLICABLE',
        'NO_EVENT_DETECTED',
        'FAILED'
      )
    ),
  constraint document_carnet_syncs_match_score_valid
    check (
      match_score is null or
      (match_score >= 0 and match_score <= 1)
    )
);

create index if not exists document_carnet_syncs_user_idx
  on public.document_carnet_syncs(user_id, updated_at desc);

create index if not exists document_carnet_syncs_vehicle_idx
  on public.document_carnet_syncs(vehicle_id, updated_at desc);

create index if not exists document_carnet_syncs_event_idx
  on public.document_carnet_syncs(event_id)
  where event_id is not null;

alter table public.document_carnet_syncs enable row level security;

revoke all on table public.document_carnet_syncs
  from public, anon, authenticated;

grant select on table public.document_carnet_syncs
  to authenticated;

grant select, insert, update, delete
  on table public.document_carnet_syncs
  to service_role;

drop policy if exists
  document_carnet_syncs_select_own
  on public.document_carnet_syncs;

create policy document_carnet_syncs_select_own
  on public.document_carnet_syncs
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

comment on table public.document_carnet_syncs is
  'Journal fonctionnel de la synchronisation entre une analyse documentaire '
  'et le carnet du véhicule. Aucun VIN ni immatriculation extrait n’est '
  'conservé dans ce journal.';

create or replace function public.sync_document_carnet_event(
  p_document_id uuid,
  p_force_review boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_document record;
  v_analysis record;
  v_existing_sync record;
  v_existing_event_id uuid;
  v_event_id uuid;
  v_result jsonb;
  v_vehicle jsonb;
  v_dates jsonb;
  v_amounts jsonb;
  v_parties jsonb;
  v_quality jsonb;
  v_document_type text;
  v_readability text;
  v_extracted_vin text;
  v_extracted_registration text;
  v_stored_vin text;
  v_stored_registration text;
  v_extracted_make text;
  v_extracted_model text;
  v_stored_make text;
  v_stored_model text;
  v_vin_exact boolean := false;
  v_registration_exact boolean := false;
  v_identifier_conflict boolean := false;
  v_make_model_match boolean := false;
  v_user_matching_vehicle_count integer := 0;
  v_match_method text := 'SELECTED_VEHICLE_ONLY';
  v_match_score numeric := 0.8000;
  v_auto_allowed boolean := false;
  v_automotive_event_evidence boolean := false;
  v_reason_code text;
  v_message text;
  v_event_type text := 'MAINTENANCE';
  v_event_title text;
  v_first_line text;
  v_line_summary text;
  v_search_text text;
  v_date_text text;
  v_occurred_at timestamptz;
  v_extracted_mileage integer;
  v_event_mileage integer;
  v_amount numeric;
  v_currency text := 'EUR';
  v_provider_name text;
  v_description text;
  v_status text;
  v_details jsonb := '{}'::jsonb;
begin
  if v_uid is null then
    raise exception 'DOCUMENT_CARNET_AUTH_REQUIRED';
  end if;

  if p_document_id is null then
    raise exception 'DOCUMENT_CARNET_DOCUMENT_REQUIRED';
  end if;

  perform pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_document_id::text, 0)
  );

  select
    d.id,
    d.vehicle_id,
    d.status as document_status,
    d.document_type as declared_document_type,
    v.user_id,
    v.make,
    v.model,
    v.mileage,
    v.registration_number,
    v.vin
  into v_document
  from public.documents d
  join public.vehicles v on v.id = d.vehicle_id
  where d.id = p_document_id
    and v.user_id = v_uid;

  if not found then
    raise exception 'DOCUMENT_CARNET_DOCUMENT_NOT_FOUND';
  end if;

  select
    da.id,
    da.summary,
    da.overall_confidence,
    da.result_json
  into v_analysis
  from public.document_analyses da
  where da.document_id = p_document_id
  limit 1;

  if not found then
    raise exception 'DOCUMENT_CARNET_ANALYSIS_NOT_FOUND';
  end if;

  if v_document.document_status <> 'completed' then
    return jsonb_build_object(
      'status', 'REVIEW_REQUIRED',
      'message', 'Le document doit être entièrement analysé avant de mettre à jour le carnet.',
      'vehicle_id', v_document.vehicle_id,
      'reason_code', 'DOCUMENT_NOT_COMPLETED',
      'match_method', null,
      'match_score', null,
      'event_id', null,
      'event_title', null,
      'suggestion_count', 0,
      'user_confirmation_required', true,
      'user_confirmed', false
    );
  end if;

  select *
  into v_existing_sync
  from public.document_carnet_syncs s
  where s.document_id = p_document_id;

  if found
     and v_existing_sync.status in ('AUTO_CREATED', 'ALREADY_CREATED')
     and v_existing_sync.event_id is not null
     and exists (
       select 1
       from public.vehicle_events e
       where e.id = v_existing_sync.event_id
         and e.vehicle_id = v_document.vehicle_id
     )
  then
    return jsonb_build_object(
      'status', 'ALREADY_CREATED',
      'message', 'Cet événement est déjà présent dans le carnet.',
      'vehicle_id', v_document.vehicle_id,
      'event_id', v_existing_sync.event_id,
      'event_title', v_existing_sync.event_title,
      'reason_code', v_existing_sync.reason_code,
      'match_method', v_existing_sync.match_method,
      'match_score', v_existing_sync.match_score,
      'suggestion_count', 0,
      'user_confirmation_required', not coalesce(
        (
          select e.user_confirmed
          from public.vehicle_events e
          where e.id = v_existing_sync.event_id
        ),
        false
      ),
      'user_confirmed', coalesce(
        (
          select e.user_confirmed
          from public.vehicle_events e
          where e.id = v_existing_sync.event_id
        ),
        false
      )
    );
  end if;

  select e.id
  into v_existing_event_id
  from public.vehicle_events e
  where e.vehicle_id = v_document.vehicle_id
    and e.source_document_id = p_document_id
    and e.source_analysis_id = v_analysis.id
  limit 1;

  if v_existing_event_id is not null then
    insert into public.document_carnet_syncs (
      user_id,
      document_id,
      vehicle_id,
      analysis_id,
      event_id,
      status,
      reason_code,
      match_method,
      match_score,
      event_title,
      details,
      updated_at
    )
    values (
      v_uid,
      p_document_id,
      v_document.vehicle_id,
      v_analysis.id,
      v_existing_event_id,
      'ALREADY_CREATED',
      'SOURCE_EVENT_ALREADY_EXISTS',
      coalesce(v_existing_sync.match_method, 'SELECTED_VEHICLE_ONLY'),
      coalesce(v_existing_sync.match_score, 0.8000),
      coalesce(v_existing_sync.event_title, 'Événement issu du document'),
      jsonb_build_object(
        'analysis_confidence', v_analysis.overall_confidence,
        'automatic', true
      ),
      now()
    )
    on conflict (document_id) do update set
      event_id = excluded.event_id,
      status = excluded.status,
      reason_code = excluded.reason_code,
      details = excluded.details,
      updated_at = now();

    return jsonb_build_object(
      'status', 'ALREADY_CREATED',
      'message', 'Un événement issu de ce document est déjà présent dans le carnet.',
      'vehicle_id', v_document.vehicle_id,
      'event_id', v_existing_event_id,
      'event_title', coalesce(
        v_existing_sync.event_title,
        'Événement issu du document'
      ),
      'reason_code', 'SOURCE_EVENT_ALREADY_EXISTS',
      'match_method', coalesce(
        v_existing_sync.match_method,
        'SELECTED_VEHICLE_ONLY'
      ),
      'match_score', coalesce(v_existing_sync.match_score, 0.8000),
      'suggestion_count', 0,
      'user_confirmation_required', not coalesce(
        (
          select e.user_confirmed
          from public.vehicle_events e
          where e.id = v_existing_event_id
        ),
        false
      ),
      'user_confirmed', coalesce(
        (
          select e.user_confirmed
          from public.vehicle_events e
          where e.id = v_existing_event_id
        ),
        false
      )
    );
  end if;

  v_result := coalesce(v_analysis.result_json, '{}'::jsonb);
  v_vehicle := coalesce(v_result -> 'vehicle', '{}'::jsonb);
  v_dates := coalesce(v_result -> 'dates', '{}'::jsonb);
  v_amounts := coalesce(v_result -> 'amounts', '{}'::jsonb);
  v_parties := coalesce(v_result -> 'parties', '{}'::jsonb);
  v_quality := coalesce(v_result -> 'document_quality', '{}'::jsonb);

  v_document_type := lower(
    coalesce(
      nullif(v_result ->> 'document_type_detected', ''),
      nullif(v_document.declared_document_type, ''),
      'unknown'
    )
  );

  v_readability := lower(
    coalesce(nullif(v_quality ->> 'readability', ''), 'unknown')
  );

  v_extracted_vin :=
    private.autoclair_normalize_identifier(v_vehicle ->> 'vin');
  v_extracted_registration :=
    private.autoclair_normalize_identifier(
      v_vehicle ->> 'registration_number'
    );
  v_stored_vin :=
    private.autoclair_normalize_identifier(v_document.vin);
  v_stored_registration :=
    private.autoclair_normalize_identifier(
      v_document.registration_number
    );

  v_extracted_make :=
    private.autoclair_normalize_words(v_vehicle ->> 'make');
  v_extracted_model :=
    private.autoclair_normalize_words(v_vehicle ->> 'model');
  v_stored_make :=
    private.autoclair_normalize_words(v_document.make);
  v_stored_model :=
    private.autoclair_normalize_words(v_document.model);

  v_vin_exact :=
    v_extracted_vin <> ''
    and v_stored_vin <> ''
    and v_extracted_vin = v_stored_vin;

  v_registration_exact :=
    v_extracted_registration <> ''
    and v_stored_registration <> ''
    and v_extracted_registration = v_stored_registration;

  v_identifier_conflict :=
    (
      v_extracted_vin <> ''
      and v_stored_vin <> ''
      and v_extracted_vin <> v_stored_vin
    )
    or
    (
      v_extracted_registration <> ''
      and v_stored_registration <> ''
      and v_extracted_registration <> v_stored_registration
    );

  v_make_model_match :=
    v_extracted_make <> ''
    and v_extracted_model <> ''
    and v_stored_make <> ''
    and v_stored_model <> ''
    and v_extracted_make = v_stored_make
    and (
      v_stored_model = v_extracted_model
      or v_stored_model like '%' || v_extracted_model || '%'
      or v_extracted_model like '%' || v_stored_model || '%'
    );

  if v_make_model_match then
    select count(*)::integer
    into v_user_matching_vehicle_count
    from public.vehicles candidate
    where candidate.user_id = v_uid
      and private.autoclair_normalize_words(candidate.make) =
        v_extracted_make
      and (
        private.autoclair_normalize_words(candidate.model) =
          v_extracted_model
        or private.autoclair_normalize_words(candidate.model)
          like '%' || v_extracted_model || '%'
        or v_extracted_model
          like '%' ||
            private.autoclair_normalize_words(candidate.model) ||
            '%'
      );
  end if;

  if v_vin_exact and v_registration_exact then
    v_match_method := 'VIN_AND_REGISTRATION_EXACT';
    v_match_score := 1.0000;
  elsif v_vin_exact then
    v_match_method := 'VIN_EXACT';
    v_match_score := 1.0000;
  elsif v_registration_exact then
    v_match_method := 'REGISTRATION_EXACT';
    v_match_score := 0.9900;
  elsif v_make_model_match
        and v_user_matching_vehicle_count = 1
  then
    v_match_method := 'MAKE_MODEL_MATCH';
    v_match_score := 0.9400;
  else
    v_match_method := 'SELECTED_VEHICLE_ONLY';
    v_match_score := 0.8000;
  end if;

  if v_identifier_conflict then
    v_reason_code := 'VEHICLE_IDENTIFIER_CONFLICT';
    v_message :=
      'Le VIN ou l’immatriculation détecté ne correspond pas au véhicule sélectionné. '
      'Aucune donnée n’a été ajoutée automatiquement.';
  elsif v_document_type = 'estimate' then
    v_reason_code := 'ESTIMATE_REQUIRES_CONFIRMATION';
    v_message :=
      'Un devis décrit une intervention envisagée, pas une opération réalisée. '
      'Les informations doivent être confirmées dans le carnet.';
  elsif v_document_type = 'repair_order' then
    v_reason_code := 'REPAIR_ORDER_REQUIRES_CONFIRMATION';
    v_message :=
      'Un ordre de réparation ne prouve pas toujours que les travaux ont été '
      'terminés. Les opérations doivent être confirmées dans le carnet.';
  elsif v_document_type not in (
    'invoice',
    'technical_inspection_report'
  ) then
    v_reason_code := 'DOCUMENT_TYPE_NOT_AUTOMATIC';
    v_message :=
      'Ce type de document ne permet pas de confirmer automatiquement un événement réalisé.';
  elsif v_readability = 'poor' then
    v_reason_code := 'DOCUMENT_READABILITY_POOR';
    v_message :=
      'La lisibilité du document est insuffisante pour créer un événement fiable.';
  elsif coalesce(v_analysis.overall_confidence, 0) < 0.88 then
    v_reason_code := 'ANALYSIS_CONFIDENCE_TOO_LOW';
    v_message :=
      'La confiance de l’analyse est insuffisante. Les informations doivent être vérifiées.';
  elsif v_match_score < 0.93 then
    v_reason_code := 'VEHICLE_MATCH_REQUIRES_CONFIRMATION';
    v_message :=
      'Le document est rattaché au véhicule sélectionné, mais aucun identifiant ou couple marque-modèle suffisamment fiable ne le confirme.';
  else
    v_auto_allowed := true;
  end if;

  v_date_text := nullif(v_dates ->> 'document_date', '');

  if v_auto_allowed then
    begin
      if v_date_text ~ '^\d{4}-\d{2}-\d{2}' then
        v_occurred_at :=
          (substring(v_date_text from 1 for 10)::date + time '12:00')::timestamptz;
      elsif v_date_text ~ '^\d{2}[./-]\d{2}[./-]\d{4}' then
        v_occurred_at :=
          (
            to_date(
              replace(replace(substring(v_date_text from 1 for 10), '.', '/'), '-', '/'),
              'DD/MM/YYYY'
            ) + time '12:00'
          )::timestamptz;
      else
        v_occurred_at := null;
      end if;
    exception when others then
      v_occurred_at := null;
    end;

    if v_occurred_at is null then
      v_auto_allowed := false;
      v_reason_code := 'DOCUMENT_DATE_MISSING';
      v_message :=
        'La date de l’intervention n’est pas suffisamment lisible. Une vérification est nécessaire.';
    elsif v_occurred_at > now() + interval '1 day' then
      v_auto_allowed := false;
      v_reason_code := 'DOCUMENT_DATE_IN_FUTURE';
      v_message :=
        'La date détectée se situe dans le futur. Aucune opération réalisée n’a été ajoutée.';
    elsif v_occurred_at < timestamptz '1950-01-01 00:00:00+00' then
      v_auto_allowed := false;
      v_reason_code := 'DOCUMENT_DATE_INVALID';
      v_message :=
        'La date détectée est incohérente. Une vérification est nécessaire.';
    end if;
  end if;

  select
    nullif(left(item ->> 'description', 180), '')
  into v_first_line
  from jsonb_array_elements(
    case
      when jsonb_typeof(v_result -> 'line_items') = 'array'
        then v_result -> 'line_items'
      else '[]'::jsonb
    end
  ) with ordinality as lines(item, position)
  where nullif(item ->> 'description', '') is not null
  order by position
  limit 1;

  select
    nullif(
      left(
        string_agg(
          nullif(item ->> 'description', ''),
          ' ; '
          order by position
        ),
        1800
      ),
      ''
    )
  into v_line_summary
  from jsonb_array_elements(
    case
      when jsonb_typeof(v_result -> 'line_items') = 'array'
        then v_result -> 'line_items'
      else '[]'::jsonb
    end
  ) with ordinality as lines(item, position)
  where nullif(item ->> 'description', '') is not null;

  v_search_text := lower(
    concat_ws(
      ' ',
      coalesce(v_analysis.summary, ''),
      coalesce(v_line_summary, '')
    )
  );

  v_automotive_event_evidence :=
    v_line_summary is not null
    and v_search_text ~ (
      'vidange|huile|filtre|r[ée]vision|entretien|courroie|distribution|'
      'bougie|frein|plaquette|disque|batterie|amortisseur|embrayage|'
      'pneu|pneumatique|roue|jante|diagnostic|r[ée]paration|carrosserie|'
      'contr[ôo]le technique|contre[- ]?visite|main.?d.?oeuvre|'
      'remplacement|remplac[ée]|pose|montage|purge|liquide|climatisation|'
      'essuie.?glace|g[ée]om[ée]trie|parall[ée]lisme|injecteur|'
      '[ée]chappement|alternateur|d[ée]marreur'
    );

  if v_document_type = 'invoice'
     and not v_automotive_event_evidence
  then
    v_auto_allowed := false;
    v_reason_code := 'INVOICE_EVENT_NOT_DETECTED';
    v_message :=
      'La facture ne contient pas de prestation automobile suffisamment '
      'claire pour créer automatiquement un événement.';
  end if;

  if v_document_type = 'technical_inspection_report' then
    v_event_type := case
      when v_search_text ~ '(contre[- ]?visite)'
        then 'REINSPECTION'
      else 'INSPECTION'
    end;
  elsif v_search_text ~ '(contre[- ]?visite)' then
    v_event_type := 'REINSPECTION';
  elsif v_search_text ~ '(contr[ôo]le technique)' then
    v_event_type := 'INSPECTION';
  elsif v_search_text ~ '(carrosserie|pare[- ]?choc|sinistre|accident|collision|choc)' then
    v_event_type := 'REPAIR';
  elsif v_search_text ~ '(pneu|pneumatique|roue|jante)' then
    v_event_type := 'TYRES';
  else
    v_event_type := 'MAINTENANCE';
  end if;

  v_provider_name := nullif(
    left(coalesce(v_parties ->> 'garage_name', ''), 200),
    ''
  );

  v_event_title := left(
    coalesce(
      v_first_line,
      case v_event_type
        when 'INSPECTION' then 'Contrôle technique'
        when 'REINSPECTION' then 'Contre-visite'
        when 'REPAIR' then 'Réparation du véhicule'
        when 'TYRES' then 'Intervention sur les pneumatiques'
        else
          case v_document_type
            when 'invoice' then 'Entretien selon facture'
            else 'Intervention selon ordre de réparation'
          end
      end
    ),
    180
  );

  v_description := left(
    concat_ws(
      E'\n\n',
      nullif(v_analysis.summary, ''),
      case
        when v_line_summary is not null
          then 'Prestations relevées : ' || v_line_summary
        else null
      end,
      'Événement créé automatiquement à partir du document analysé. '
      'Le document original reste la source de référence.'
    ),
    3500
  );

  begin
    v_extracted_mileage :=
      round(
        replace(
          regexp_replace(
            coalesce(v_vehicle ->> 'mileage', ''),
            '[^0-9,.-]',
            '',
            'g'
          ),
          ',',
          '.'
        )::numeric
      )::integer;
  exception when others then
    v_extracted_mileage := null;
  end;

  if v_extracted_mileage is not null
     and v_extracted_mileage between 0 and 3000000
     and (
       v_document.mileage is null
       or v_extracted_mileage >= v_document.mileage
     )
  then
    v_event_mileage := v_extracted_mileage;
  else
    v_event_mileage := null;
  end if;

  begin
    v_amount := replace(
      regexp_replace(
        coalesce(v_amounts ->> 'total_including_tax', ''),
        '[^0-9,.-]',
        '',
        'g'
      ),
      ',',
      '.'
    )::numeric;
  exception when others then
    v_amount := null;
  end;

  if v_amount is not null
     and (v_amount < 0 or v_amount > 1000000)
  then
    v_amount := null;
  end if;

  v_currency := upper(
    coalesce(nullif(v_amounts ->> 'currency', ''), 'EUR')
  );

  if length(v_currency) <> 3 then
    v_currency := 'EUR';
  end if;

  if v_auto_allowed
     and nullif(v_event_title, '') is null
     and nullif(v_analysis.summary, '') is null
  then
    v_auto_allowed := false;
    v_reason_code := 'NO_EVENT_CONTENT';
    v_message :=
      'Aucune opération suffisamment précise n’a été détectée dans le document.';
  end if;

  if not v_auto_allowed or p_force_review then
    v_status := case
      when v_reason_code = 'DOCUMENT_TYPE_NOT_AUTOMATIC'
        then 'NOT_APPLICABLE'
      when v_reason_code = 'NO_EVENT_CONTENT'
        then 'NO_EVENT_DETECTED'
      else 'REVIEW_REQUIRED'
    end;

    if p_force_review then
      v_status := 'REVIEW_REQUIRED';
      v_reason_code := 'FORCED_REVIEW';
      v_message :=
        'La création automatique a été désactivée pour cette vérification.';
    end if;

    v_details := jsonb_build_object(
      'analysis_confidence', v_analysis.overall_confidence,
      'document_type', v_document_type,
      'readability', v_readability,
      'identifier_conflict', v_identifier_conflict,
      'matching_vehicle_count', v_user_matching_vehicle_count,
      'automotive_event_evidence', v_automotive_event_evidence,
      'automatic', false
    );

    insert into public.document_carnet_syncs (
      user_id,
      document_id,
      vehicle_id,
      analysis_id,
      event_id,
      status,
      reason_code,
      match_method,
      match_score,
      event_title,
      details,
      updated_at
    )
    values (
      v_uid,
      p_document_id,
      v_document.vehicle_id,
      v_analysis.id,
      null,
      v_status,
      v_reason_code,
      v_match_method,
      v_match_score,
      v_event_title,
      v_details,
      now()
    )
    on conflict (document_id) do update set
      analysis_id = excluded.analysis_id,
      event_id = null,
      status = excluded.status,
      reason_code = excluded.reason_code,
      match_method = excluded.match_method,
      match_score = excluded.match_score,
      event_title = excluded.event_title,
      details = excluded.details,
      updated_at = now();

    return jsonb_build_object(
      'status', v_status,
      'message', coalesce(
        v_message,
        'Les informations doivent être vérifiées avant d’être ajoutées au carnet.'
      ),
      'vehicle_id', v_document.vehicle_id,
      'event_id', null,
      'event_title', v_event_title,
      'reason_code', v_reason_code,
      'match_method', v_match_method,
      'match_score', v_match_score,
      'suggestion_count', 0,
      'user_confirmation_required', true,
      'user_confirmed', false
    );
  end if;

  perform public.record_vehicle_event(
    p_vehicle_id => v_document.vehicle_id,
    p_event_type => v_event_type,
    p_title => v_event_title,
    p_occurred_at => v_occurred_at,
    p_status => 'COMPLETED',
    p_mileage => v_event_mileage,
    p_amount => case
      when v_document_type = 'invoice' then v_amount
      else null
    end,
    p_currency => v_currency,
    p_provider_name => v_provider_name,
    p_description => v_description,
    p_location_text => null,
    p_source_type => 'DOCUMENT_AI',
    p_source_document_id => p_document_id,
    p_source_analysis_id => v_analysis.id,
    p_confidence => least(
      coalesce(v_analysis.overall_confidence, 0),
      v_match_score
    ),
    p_user_confirmed => false,
    p_metadata => jsonb_build_object(
      'automatic_document_sync', true,
      'document_type', v_document_type,
      'match_method', v_match_method,
      'match_score', v_match_score,
      'matching_vehicle_count', v_user_matching_vehicle_count,
      'automotive_event_evidence', v_automotive_event_evidence,
      'analysis_confidence', v_analysis.overall_confidence,
      'document_mileage', v_extracted_mileage,
      'mileage_applied', v_event_mileage is not null,
      'source_is_reference', true
    ),
    p_create_expense => (
      v_document_type = 'invoice'
      and v_amount is not null
      and v_amount > 0
    )
  );

  select e.id
  into v_event_id
  from public.vehicle_events e
  where e.vehicle_id = v_document.vehicle_id
    and e.source_document_id = p_document_id
    and e.source_analysis_id = v_analysis.id
  limit 1;

  if v_event_id is null then
    raise exception 'DOCUMENT_CARNET_EVENT_CREATE_FAILED';
  end if;

  v_details := jsonb_build_object(
    'analysis_confidence', v_analysis.overall_confidence,
    'document_type', v_document_type,
    'readability', v_readability,
    'automatic', true,
    'expense_created', (
      v_document_type = 'invoice'
      and v_amount is not null
      and v_amount > 0
    ),
    'mileage_applied', v_event_mileage is not null
  );

  insert into public.document_carnet_syncs (
    user_id,
    document_id,
    vehicle_id,
    analysis_id,
    event_id,
    status,
    reason_code,
    match_method,
    match_score,
    event_title,
    details,
    updated_at
  )
  values (
    v_uid,
    p_document_id,
    v_document.vehicle_id,
    v_analysis.id,
    v_event_id,
    'AUTO_CREATED',
    'SAFE_AUTOMATIC_MATCH',
    v_match_method,
    v_match_score,
    v_event_title,
    v_details,
    now()
  )
  on conflict (document_id) do update set
    analysis_id = excluded.analysis_id,
    event_id = excluded.event_id,
    status = excluded.status,
    reason_code = excluded.reason_code,
    match_method = excluded.match_method,
    match_score = excluded.match_score,
    event_title = excluded.event_title,
    details = excluded.details,
    updated_at = now();

  perform public.recalculate_vehicle_reminders(
    p_vehicle_id => v_document.vehicle_id
  );

  return jsonb_build_object(
    'status', 'AUTO_CREATED',
    'message', 'L’intervention a été ajoutée automatiquement au carnet.',
    'vehicle_id', v_document.vehicle_id,
    'event_id', v_event_id,
    'event_title', v_event_title,
    'reason_code', 'SAFE_AUTOMATIC_MATCH',
    'match_method', v_match_method,
    'match_score', v_match_score,
    'suggestion_count', 0,
    'user_confirmation_required', true,
    'user_confirmed', false
  );

exception
  when others then
    if sqlerrm like 'DOCUMENT_CARNET_%' then
      raise;
    end if;

    raise exception
      'DOCUMENT_CARNET_UNEXPECTED:%',
      left(sqlerrm, 500);
end
$function$;


create or replace function public.confirm_document_carnet_event(
  p_document_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_sync record;
begin
  if v_uid is null then
    raise exception 'DOCUMENT_CARNET_AUTH_REQUIRED';
  end if;

  if p_document_id is null then
    raise exception 'DOCUMENT_CARNET_DOCUMENT_REQUIRED';
  end if;

  perform pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_document_id::text, 0)
  );

  select
    s.document_id,
    s.vehicle_id,
    s.event_id,
    s.status,
    s.reason_code,
    s.match_method,
    s.match_score,
    s.event_title,
    s.details,
    e.source_document_id,
    e.source_type,
    e.user_confirmed
  into v_sync
  from public.document_carnet_syncs s
  join public.vehicles v
    on v.id = s.vehicle_id
   and v.user_id = v_uid
  join public.vehicle_events e
    on e.id = s.event_id
   and e.vehicle_id = s.vehicle_id
  where s.document_id = p_document_id;

  if not found then
    raise exception 'DOCUMENT_CARNET_CONFIRM_NOT_FOUND';
  end if;

  if v_sync.status not in ('AUTO_CREATED', 'ALREADY_CREATED')
     or v_sync.event_id is null
     or v_sync.source_document_id <> p_document_id
     or v_sync.source_type <> 'DOCUMENT_AI'
  then
    raise exception 'DOCUMENT_CARNET_CONFIRM_NOT_ALLOWED';
  end if;

  if not coalesce(v_sync.user_confirmed, false) then
    update public.vehicle_events e
    set user_confirmed = true
    where e.id = v_sync.event_id
      and e.vehicle_id = v_sync.vehicle_id
      and e.source_document_id = p_document_id
      and e.source_type = 'DOCUMENT_AI';

    if not found then
      raise exception 'DOCUMENT_CARNET_CONFIRM_UPDATE_FAILED';
    end if;

    update public.document_carnet_syncs s
    set
      details = coalesce(s.details, '{}'::jsonb) ||
        jsonb_build_object(
          'user_confirmed', true,
          'user_confirmed_at', now()
        ),
      updated_at = now()
    where s.document_id = p_document_id
      and s.user_id = v_uid;
  end if;

  return jsonb_build_object(
    'status', 'ALREADY_CREATED',
    'message', 'L’événement a été confirmé dans le carnet.',
    'vehicle_id', v_sync.vehicle_id,
    'event_id', v_sync.event_id,
    'event_title', v_sync.event_title,
    'reason_code', v_sync.reason_code,
    'match_method', v_sync.match_method,
    'match_score', v_sync.match_score,
    'suggestion_count', 0,
    'user_confirmation_required', false,
    'user_confirmed', true
  );
end
$function$;

revoke all
  on function public.confirm_document_carnet_event(uuid)
  from public, anon;

grant execute
  on function public.confirm_document_carnet_event(uuid)
  to authenticated, service_role;

comment on function public.confirm_document_carnet_event(uuid) is
  'Permet au propriétaire de confirmer uniquement l’événement automatique '
  'DOCUMENT_AI lié au document. La fonction ne peut ni confirmer un événement '
  'manuel ni modifier un autre véhicule.';

revoke all
  on function public.sync_document_carnet_event(uuid, boolean)
  from public, anon;

grant execute
  on function public.sync_document_carnet_event(uuid, boolean)
  to authenticated, service_role;

comment on function public.sync_document_carnet_event(uuid, boolean) is
  'Crée de façon idempotente un événement de carnet à partir d’une analyse '
  'documentaire uniquement si le document, le véhicule, la date et la '
  'confiance satisfont les règles de sécurité. Les cas ambigus restent en '
  'attente de confirmation.';

commit;
