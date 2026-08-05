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
  if to_regclass('public.documents') is null then
    v_missing := array_append(v_missing, 'public.documents');
  end if;

  foreach v_column in array array[
    'id', 'vehicle_id', 'status', 'occurred_at', 'metadata',
    'source_document_id'
  ] loop
    if not exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'vehicle_events'
        and column_name = v_column
    ) then
      v_missing := array_append(v_missing, 'vehicle_events.' || v_column);
    end if;
  end loop;

  foreach v_column in array array['id', 'user_id'] loop
    if not exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'vehicles'
        and column_name = v_column
    ) then
      v_missing := array_append(v_missing, 'vehicles.' || v_column);
    end if;
  end loop;

  foreach v_column in array array['id', 'user_id', 'vehicle_id'] loop
    if not exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'documents'
        and column_name = v_column
    ) then
      v_missing := array_append(v_missing, 'documents.' || v_column);
    end if;
  end loop;

  if cardinality(v_missing) > 0 then
    raise exception
      'EVENT_DOCUMENT_REMINDER_V3_PRECHECK_FAILED:%',
      array_to_string(v_missing, ',');
  end if;
end
$precheck$;

alter table public.vehicle_events
  add column if not exists reminder_enabled boolean not null default false,
  add column if not exists reminder_days_before smallint,
  add column if not exists reminder_at timestamptz;

create or replace function public.autoclair_prepare_vehicle_event_v3()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_vehicle_user_id uuid;
  v_document_user_id uuid;
  v_document_vehicle_id uuid;
  v_enabled boolean := false;
  v_days integer;
begin
  select v.user_id
  into v_vehicle_user_id
  from public.vehicles v
  where v.id = new.vehicle_id;

  if v_vehicle_user_id is null then
    raise exception 'EVENT_VEHICLE_NOT_FOUND';
  end if;

  if auth.uid() is not null and auth.uid() <> v_vehicle_user_id then
    raise exception 'EVENT_VEHICLE_FORBIDDEN';
  end if;

  if new.source_document_id is not null then
    select d.user_id, d.vehicle_id
    into v_document_user_id, v_document_vehicle_id
    from public.documents d
    where d.id = new.source_document_id;

    if v_document_user_id is null
       or v_document_user_id <> v_vehicle_user_id
       or (
         v_document_vehicle_id is not null
         and v_document_vehicle_id <> new.vehicle_id
       ) then
      raise exception 'EVENT_DOCUMENT_NOT_ALLOWED';
    end if;

    if v_document_vehicle_id is null then
      update public.documents
      set vehicle_id = new.vehicle_id
      where id = new.source_document_id
        and user_id = v_vehicle_user_id
        and vehicle_id is null;
    end if;
  end if;

  if upper(coalesce(new.status, '')) = 'PLANNED' then
    begin
      v_enabled := coalesce(
        (coalesce(new.metadata, '{}'::jsonb) ->> 'reminder_enabled')::boolean,
        false
      );
    exception when invalid_text_representation then
      raise exception 'EVENT_REMINDER_INVALID';
    end;

    if v_enabled then
      begin
        v_days := (
          coalesce(new.metadata, '{}'::jsonb) ->> 'reminder_days_before'
        )::integer;
      exception when invalid_text_representation then
        raise exception 'EVENT_REMINDER_INVALID';
      end;

      if v_days not in (1, 3, 7, 14, 30) then
        raise exception 'EVENT_REMINDER_INVALID';
      end if;

      new.reminder_enabled := true;
      new.reminder_days_before := v_days;
      new.reminder_at := date_trunc('day', new.occurred_at)
        + interval '9 hours'
        - make_interval(days => v_days);

      if new.reminder_at <= now() then
        raise exception 'EVENT_REMINDER_INVALID';
      end if;
    else
      new.reminder_enabled := false;
      new.reminder_days_before := null;
      new.reminder_at := null;
      new.metadata := (
        coalesce(new.metadata, '{}'::jsonb)
        || jsonb_build_object('reminder_enabled', false)
      ) - 'reminder_days_before';
    end if;
  else
    new.reminder_enabled := false;
    new.reminder_days_before := null;
    new.reminder_at := null;
    new.metadata := coalesce(new.metadata, '{}'::jsonb)
      - 'reminder_enabled'
      - 'reminder_days_before';
  end if;

  return new;
end
$function$;

revoke all
  on function public.autoclair_prepare_vehicle_event_v3()
  from public, anon, authenticated;

drop trigger if exists autoclair_prepare_vehicle_event_v3
  on public.vehicle_events;

create trigger autoclair_prepare_vehicle_event_v3
before insert or update of
  vehicle_id,
  status,
  occurred_at,
  metadata,
  source_document_id
on public.vehicle_events
for each row
execute function public.autoclair_prepare_vehicle_event_v3();

update public.vehicle_events
set metadata = coalesce(metadata, '{}'::jsonb)
where metadata is null;

create index if not exists vehicle_events_active_reminder_idx
  on public.vehicle_events(reminder_at)
  where reminder_enabled = true and status = 'PLANNED';

comment on column public.vehicle_events.reminder_enabled is
  'Indique qu’une notification locale a été demandée par l’utilisateur.';
comment on column public.vehicle_events.reminder_days_before is
  'Délai choisi : 1, 3, 7, 14 ou 30 jours avant l’événement prévu.';
comment on column public.vehicle_events.reminder_at is
  'Date calculée du rappel, également utilisable pour les rappels dans l’application.';
comment on function public.autoclair_prepare_vehicle_event_v3() is
  'Valide le document lié, la propriété des données et les rappels des événements.';

commit;
