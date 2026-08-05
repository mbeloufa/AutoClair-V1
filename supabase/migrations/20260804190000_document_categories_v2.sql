begin;

do $precheck$
begin
  if to_regclass('public.documents') is null then
    raise exception 'DOCUMENT_CATEGORIES_PRECHECK_MISSING:public.documents';
  end if;

  if to_regprocedure(
    'public.create_document_draft(uuid,text,text)'
  ) is null then
    raise exception
      'DOCUMENT_CATEGORIES_PRECHECK_MISSING:create_document_draft';
  end if;
end
$precheck$;

do $constraints$
declare
  v_constraint record;
begin
  for v_constraint in
    select c.conname
    from pg_catalog.pg_constraint c
    join pg_catalog.pg_class t on t.oid = c.conrelid
    join pg_catalog.pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'documents'
      and c.contype = 'c'
      and pg_catalog.pg_get_constraintdef(c.oid)
        ilike '%document_type%'
  loop
    execute format(
      'alter table public.documents drop constraint %I',
      v_constraint.conname
    );
  end loop;
end
$constraints$;

alter table public.documents
  add constraint documents_document_type_check_v2
  check (
    document_type in (
      'estimate',
      'invoice',
      'repair_order',
      'technical_inspection_report',
      'other',
      'unknown',
      'quote',
      'registration_certificate',
      'insurance_certificate',
      'maintenance_booklet',
      'purchase_order'
    )
  );

create or replace function public.create_document_draft_v2(
  p_vehicle_id uuid,
  p_document_type text,
  p_comment text default null
)
returns table(id uuid)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_requested_type text := lower(trim(coalesce(p_document_type, '')));
  v_legacy_type text;
  v_payload jsonb;
  v_document_id_text text;
  v_document_id uuid;
  v_updated_count integer := 0;
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if v_requested_type not in (
    'estimate',
    'invoice',
    'repair_order',
    'technical_inspection_report',
    'other'
  ) then
    raise exception 'DOCUMENT_TYPE_INVALID';
  end if;

  -- La fonction historique conserve toutes ses validations de sécurité,
  -- de véhicule et de commentaire. Les deux nouvelles catégories sont
  -- créées avec un type historique accepté, puis corrigées dans la même
  -- transaction avant que le brouillon ne soit renvoyé au mobile.
  v_legacy_type := case
    when v_requested_type in (
      'technical_inspection_report',
      'other'
    ) then 'repair_order'
    else v_requested_type
  end;

  select to_jsonb(draft_row)
  into v_payload
  from public.create_document_draft(
    p_vehicle_id,
    v_legacy_type,
    p_comment
  ) as draft_row
  limit 1;

  v_document_id_text := nullif(v_payload ->> 'id', '');

  if v_document_id_text is null then
    select nullif(candidate #>> '{}', '')
    into v_document_id_text
    from jsonb_path_query(v_payload, '$.**.id') as candidate
    limit 1;
  end if;

  if v_document_id_text is null then
    raise exception 'DOCUMENT_DRAFT_ID_MISSING';
  end if;

  begin
    v_document_id := v_document_id_text::uuid;
  exception
    when invalid_text_representation then
      raise exception 'DOCUMENT_DRAFT_ID_INVALID';
  end;

  update public.documents d
  set
    document_type = v_requested_type,
    updated_at = now()
  where d.id = v_document_id
    and d.user_id = v_uid;

  get diagnostics v_updated_count = row_count;

  if v_updated_count <> 1 then
    raise exception 'DOCUMENT_DRAFT_UPDATE_FAILED';
  end if;

  return query select v_document_id;
end
$function$;

revoke all
  on function public.create_document_draft_v2(uuid, text, text)
  from public, anon;

grant execute
  on function public.create_document_draft_v2(uuid, text, text)
  to authenticated, service_role;

comment on function public.create_document_draft_v2(uuid, text, text) is
  'Crée un brouillon via les validations historiques puis prend en charge '
  'Contrôle technique et Autre sans dupliquer la logique de sécurité.';

commit;
