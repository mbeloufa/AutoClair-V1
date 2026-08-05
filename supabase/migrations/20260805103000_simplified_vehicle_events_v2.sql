begin;

do $precheck$
declare
  v_missing text[] := array[]::text[];
  v_column text;
begin
  if to_regclass('public.vehicle_events') is null then
    v_missing := array_append(v_missing, 'public.vehicle_events');
  end if;

  if to_regclass('public.vehicles') is null then
    v_missing := array_append(v_missing, 'public.vehicles');
  end if;

  if to_regclass('public.vehicle_document_suggestions') is null then
    v_missing := array_append(
      v_missing,
      'public.vehicle_document_suggestions'
    );
  end if;

  if to_regclass('public.document_analyses') is null then
    v_missing := array_append(v_missing, 'public.document_analyses');
  end if;

  if to_regprocedure(
    'public.confirm_document_carnet_event(uuid)'
  ) is null then
    v_missing := array_append(
      v_missing,
      'public.confirm_document_carnet_event(uuid)'
    );
  end if;

  if to_regprocedure(
    'public.confirm_document_suggestion(uuid,uuid,jsonb)'
  ) is null then
    v_missing := array_append(
      v_missing,
      'public.confirm_document_suggestion(uuid,uuid,jsonb)'
    );
  end if;

  foreach v_column in array array[
    'id',
    'vehicle_id',
    'mileage',
    'amount',
    'metadata',
    'source_document_id',
    'created_at'
  ] loop
    if not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'vehicle_events'
        and column_name = v_column
    ) then
      v_missing := array_append(
        v_missing,
        'vehicle_events.' || v_column
      );
    end if;
  end loop;

  foreach v_column in array array['id', 'user_id'] loop
    if not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'vehicles'
        and column_name = v_column
    ) then
      v_missing := array_append(v_missing, 'vehicles.' || v_column);
    end if;
  end loop;

  foreach v_column in array array[
    'id',
    'vehicle_id',
    'document_id',
    'status'
  ] loop
    if not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'vehicle_document_suggestions'
        and column_name = v_column
    ) then
      v_missing := array_append(
        v_missing,
        'vehicle_document_suggestions.' || v_column
      );
    end if;
  end loop;

  foreach v_column in array array['result_json', 'summary'] loop
    if not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'document_analyses'
        and column_name = v_column
    ) then
      v_missing := array_append(
        v_missing,
        'document_analyses.' || v_column
      );
    end if;
  end loop;

  if cardinality(v_missing) > 0 then
    raise exception
      'SIMPLIFIED_EVENTS_V2_PRECHECK_FAILED:%',
      array_to_string(v_missing, ',');
  end if;
end
$precheck$;

create or replace function public.autoclair_sanitize_analysis_json(
  p_value jsonb
)
returns jsonb
language plpgsql
immutable
strict
set search_path = ''
as $function$
declare
  v_type text := jsonb_typeof(p_value);
  v_result jsonb;
begin
  if v_type = 'object' then
    select coalesce(
      jsonb_object_agg(
        source.key,
        public.autoclair_sanitize_analysis_json(source.value)
      ),
      '{}'::jsonb
    )
    into v_result
    from jsonb_each(p_value) source
    where lower(
      regexp_replace(source.key, '[^a-zA-Z0-9]+', '_', 'g')
    ) not in (
      'client',
      'client_name',
      'customer',
      'customer_name',
      'owner',
      'owner_name',
      'recipient',
      'recipient_name',
      'person_name',
      'address',
      'email',
      'phone',
      'telephone',
      'mobile',
      'contact',
      'client_address',
      'customer_address',
      'owner_address',
      'recipient_address',
      'billing_address',
      'client_email',
      'customer_email',
      'owner_email',
      'recipient_email',
      'client_phone',
      'customer_phone',
      'owner_phone',
      'recipient_phone',
      'billed_to',
      'invoice_to'
    );

    return v_result;
  end if;

  if v_type = 'array' then
    select coalesce(
      jsonb_agg(
        public.autoclair_sanitize_analysis_json(source.value)
        order by source.ordinality
      ),
      '[]'::jsonb
    )
    into v_result
    from jsonb_array_elements(p_value) with ordinality source(
      value,
      ordinality
    );

    return v_result;
  end if;

  return p_value;
end
$function$;

revoke all
  on function public.autoclair_sanitize_analysis_json(jsonb)
  from public, anon, authenticated;

grant execute
  on function public.autoclair_sanitize_analysis_json(jsonb)
  to service_role;

create or replace function public.autoclair_sanitize_analysis_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  new.result_json := public.autoclair_sanitize_analysis_json(
    coalesce(new.result_json, '{}'::jsonb)
  );

  if coalesce(new.summary, '') ~* (
    'client|customer|nom du client|propri[eé]taire|destinataire'
  ) then
    new.summary := 'Analyse automobile terminée.';
  end if;

  return new;
end
$function$;

revoke all
  on function public.autoclair_sanitize_analysis_row()
  from public, anon, authenticated;

drop trigger if exists autoclair_sanitize_analysis_identity
  on public.document_analyses;

create trigger autoclair_sanitize_analysis_identity
before insert or update of result_json, summary
on public.document_analyses
for each row
execute function public.autoclair_sanitize_analysis_row();

update public.document_analyses
set
  result_json = public.autoclair_sanitize_analysis_json(
    coalesce(result_json, '{}'::jsonb)
  ),
  summary = case
    when coalesce(summary, '') ~* (
      'client|customer|nom du client|propri[eé]taire|destinataire'
    ) then 'Analyse automobile terminée.'
    else summary
  end;

create or replace function public.confirm_document_carnet_event_v2(
  p_document_id uuid,
  p_mileage integer default null,
  p_amount numeric default null,
  p_category_code text default null,
  p_subcategory_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
  v_event_id uuid;
  v_updated integer := 0;
begin
  if v_uid is null then
    raise exception 'DOCUMENT_OPERATION_AUTH_REQUIRED';
  end if;

  if p_mileage is not null and p_mileage < 0 then
    raise exception 'DOCUMENT_OPERATION_MILEAGE_INVALID';
  end if;

  if p_amount is not null and p_amount < 0 then
    raise exception 'DOCUMENT_OPERATION_AMOUNT_INVALID';
  end if;

  v_result := public.confirm_document_carnet_event(p_document_id);

  begin
    v_event_id := nullif(v_result ->> 'event_id', '')::uuid;
  exception
    when invalid_text_representation then
      v_event_id := null;
  end;

  if v_event_id is not null then
    update public.vehicle_events e
    set
      mileage = coalesce(p_mileage, e.mileage),
      amount = coalesce(p_amount, e.amount),
      metadata = coalesce(e.metadata, '{}'::jsonb) ||
        jsonb_strip_nulls(
          jsonb_build_object(
            'category_code', nullif(trim(p_category_code), ''),
            'subcategory_code', nullif(trim(p_subcategory_code), ''),
            'user_reviewed_operation', true
          )
        )
    from public.vehicles v
    where e.id = v_event_id
      and v.id = e.vehicle_id
      and v.user_id = v_uid;

    get diagnostics v_updated = row_count;
  end if;

  return coalesce(v_result, '{}'::jsonb) || jsonb_build_object(
    'operation_details_updated', v_updated > 0,
    'event_category_code', nullif(trim(p_category_code), ''),
    'event_subcategory_code', nullif(trim(p_subcategory_code), '')
  );
end
$function$;

create or replace function public.confirm_document_suggestion_v2(
  p_suggestion_id uuid,
  p_vehicle_id uuid,
  p_mileage integer default null,
  p_amount numeric default null,
  p_category_code text default null,
  p_subcategory_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_document_id uuid;
  v_event_id uuid;
  v_overrides jsonb;
begin
  if v_uid is null then
    raise exception 'DOCUMENT_OPERATION_AUTH_REQUIRED';
  end if;

  if p_mileage is not null and p_mileage < 0 then
    raise exception 'DOCUMENT_OPERATION_MILEAGE_INVALID';
  end if;

  if p_amount is not null and p_amount < 0 then
    raise exception 'DOCUMENT_OPERATION_AMOUNT_INVALID';
  end if;

  select s.document_id
  into v_document_id
  from public.vehicle_document_suggestions s
  join public.vehicles v on v.id = s.vehicle_id
  where s.id = p_suggestion_id
    and s.vehicle_id = p_vehicle_id
    and v.user_id = v_uid
    and s.status = 'PENDING';

  if v_document_id is null then
    raise exception 'DOCUMENT_SUGGESTION_NOT_FOUND';
  end if;

  v_overrides := jsonb_strip_nulls(
    jsonb_build_object(
      'mileage', p_mileage,
      'amount', p_amount,
      'category_code', nullif(trim(p_category_code), ''),
      'subcategory_code', nullif(trim(p_subcategory_code), '')
    )
  );

  perform public.confirm_document_suggestion(
    p_suggestion_id,
    p_vehicle_id,
    v_overrides
  );

  select e.id
  into v_event_id
  from public.vehicle_events e
  join public.vehicles v on v.id = e.vehicle_id
  where e.vehicle_id = p_vehicle_id
    and v.user_id = v_uid
    and e.source_document_id = v_document_id
  order by e.created_at desc
  limit 1;

  if v_event_id is not null then
    update public.vehicle_events e
    set
      mileage = coalesce(p_mileage, e.mileage),
      amount = coalesce(p_amount, e.amount),
      metadata = coalesce(e.metadata, '{}'::jsonb) ||
        jsonb_strip_nulls(
          jsonb_build_object(
            'category_code', nullif(trim(p_category_code), ''),
            'subcategory_code', nullif(trim(p_subcategory_code), ''),
            'user_reviewed_operation', true
          )
        )
    where e.id = v_event_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'event_id', v_event_id,
    'document_id', v_document_id,
    'category_code', nullif(trim(p_category_code), ''),
    'subcategory_code', nullif(trim(p_subcategory_code), '')
  );
end
$function$;

revoke all
  on function public.confirm_document_carnet_event_v2(
    uuid,
    integer,
    numeric,
    text,
    text
  )
  from public, anon;

grant execute
  on function public.confirm_document_carnet_event_v2(
    uuid,
    integer,
    numeric,
    text,
    text
  )
  to authenticated, service_role;

revoke all
  on function public.confirm_document_suggestion_v2(
    uuid,
    uuid,
    integer,
    numeric,
    text,
    text
  )
  from public, anon;

grant execute
  on function public.confirm_document_suggestion_v2(
    uuid,
    uuid,
    integer,
    numeric,
    text,
    text
  )
  to authenticated, service_role;

comment on function public.confirm_document_carnet_event_v2(
  uuid,
  integer,
  numeric,
  text,
  text
) is
  'Confirme une opération détectée et permet à l’utilisateur de compléter '
  'uniquement le kilométrage, le prix et sa catégorie automobile.';

comment on function public.confirm_document_suggestion_v2(
  uuid,
  uuid,
  integer,
  numeric,
  text,
  text
) is
  'Confirme une suggestion documentaire avec les corrections simples de '
  'l’utilisateur sans exposer les données nominatives de la facture.';

comment on function public.autoclair_sanitize_analysis_json(jsonb) is
  'Retire récursivement les champs d’identité client des résultats '
  'd’analyse documentaire stockés par AutoClair.';

commit;
