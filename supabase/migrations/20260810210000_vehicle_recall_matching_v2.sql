begin;

alter table public.vehicles
  add column if not exists first_registration_date date;

alter table public.official_vehicle_recalls
  add column if not exists identification_products jsonb not null default '[]'::jsonb,
  add column if not exists additional_information text,
  add column if not exists additional_public_information text;

comment on column public.vehicles.first_registration_date is
  'Date exacte de premiere mise en circulation saisie ou issue du fournisseur. Ce signal ameliore le rapprochement sans prouver une date de fabrication.';

create or replace function public.set_vehicle_first_registration_date(
    p_vehicle_id uuid,
    p_first_registration_date date
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_owner uuid;
begin
    v_owner := private.require_vehicle_owner(p_vehicle_id);

    if p_first_registration_date is not null then
        if p_first_registration_date < date '1886-01-29'
           or p_first_registration_date > current_date then
            raise exception 'Date de premiere mise en circulation invalide';
        end if;
    end if;

    update public.vehicles
       set first_registration_date = p_first_registration_date,
           updated_at = now()
     where id = p_vehicle_id
       and user_id = v_owner;
end;
$function$;

create or replace function private.recall_context_contains_vin(
    p_context text,
    p_vin text
)
returns boolean
language sql
immutable
set search_path = ''
as $function$
select case
    when upper(regexp_replace(coalesce(p_vin, ''), '[^A-Z0-9]', '', 'g')) !~ '^[A-Z0-9]{17}$'
        then false
    else (
        ' ' || upper(regexp_replace(coalesce(p_context, ''), '[^A-Z0-9]+', ' ', 'g')) || ' '
    ) like (
        '% ' || upper(regexp_replace(p_vin, '[^A-Z0-9]', '', 'g')) || ' %'
    )
end;
$function$;

create or replace function private.recall_match_score_v2(
    p_vehicle_make text,
    p_vehicle_model text,
    p_vehicle_year integer,
    p_first_registration_date date,
    p_vin text,
    p_recall_brand text,
    p_recall_models text,
    p_start date,
    p_end date,
    p_context text
)
returns numeric
language plpgsql
immutable
set search_path = ''
as $function$
declare
    v_score numeric;
    v_date_compatible boolean := false;
    v_vin_exact boolean := false;
begin
    v_score := private.recall_match_score(
        p_vehicle_make,
        p_vehicle_model,
        p_vehicle_year,
        p_recall_brand,
        p_recall_models,
        p_start,
        p_end
    );

    if v_score < 0.85 then
        return v_score;
    end if;

    if p_first_registration_date is not null then
        v_date_compatible :=
            (p_start is null or p_first_registration_date >= p_start)
            and (p_end is null or p_first_registration_date <= p_end);
        if v_date_compatible then
            v_score := v_score + 0.02;
        end if;
    end if;

    v_vin_exact := private.recall_context_contains_vin(p_context, p_vin);
    if v_vin_exact then
        v_score := v_score + 0.05;
    end if;

    return least(1.00, v_score);
end;
$function$;

create or replace function private.sync_vehicle_recall_matches_v2(
    p_vehicle_id uuid,
    p_user_id uuid,
    p_make text,
    p_model text,
    p_year integer,
    p_first_registration_date date,
    p_vin text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_count integer;
begin
    -- Le moteur historique reste responsable de la creation/suppression des
    -- rapprochements et preserve deja NOT_CONCERNED / COMPLETED / SCHEDULED.
    v_count := private.sync_vehicle_recall_matches(
        p_vehicle_id,
        p_user_id,
        p_make,
        p_model,
        p_year
    );

    update public.vehicle_recall_matches m
       set match_score = scored.score,
           match_reason = case
               when scored.vin_exact then
                   regexp_replace(m.match_reason, '\s+(Le VIN exact|La date de premiere mise en circulation).*$','')
                   || ' Le VIN exact apparait comme valeur complete dans le texte officiel. Confirmation constructeur toujours recommandee.'
               when scored.date_compatible then
                   regexp_replace(m.match_reason, '\s+(Le VIN exact|La date de premiere mise en circulation).*$','')
                   || ' La date de premiere mise en circulation est compatible avec la periode publiee ; ce signal ne prouve pas la fabrication.'
               else regexp_replace(
                   m.match_reason,
                   '\s+(Le VIN exact|La date de premiere mise en circulation).*$',''
               )
           end,
           updated_at = now()
      from (
          select recall.id as recall_id,
                 private.recall_match_score_v2(
                     p_make,
                     p_model,
                     p_year,
                     p_first_registration_date,
                     p_vin,
                     recall.brand,
                     recall.models_references,
                     recall.commercialization_start,
                     recall.commercialization_end,
                     concat_ws(
                         ' ',
                         recall.title,
                         recall.models_references,
                         recall.recall_reason,
                         recall.risks,
                         recall.consumer_actions,
                         recall.contact,
                         recall.compensation,
                         recall.identification_products::text,
                         recall.additional_information,
                         recall.additional_public_information
                     )
                 ) as score,
                 private.recall_context_contains_vin(
                     concat_ws(
                         ' ',
                         recall.title,
                         recall.models_references,
                         recall.recall_reason,
                         recall.risks,
                         recall.consumer_actions,
                         recall.contact,
                         recall.compensation,
                         recall.identification_products::text,
                         recall.additional_information,
                         recall.additional_public_information
                     ),
                     p_vin
                 ) as vin_exact,
                 (
                     p_first_registration_date is not null
                     and (recall.commercialization_start is null
                          or p_first_registration_date >= recall.commercialization_start)
                     and (recall.commercialization_end is null
                          or p_first_registration_date <= recall.commercialization_end)
                 ) as date_compatible
            from public.official_vehicle_recalls recall
      ) scored
     where m.vehicle_id = p_vehicle_id
       and m.recall_id = scored.recall_id;

    return v_count;
end;
$function$;

create or replace function public.match_vehicle_recalls(p_vehicle_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_owner uuid;
    v_make text;
    v_model text;
    v_year integer;
    v_first_registration_date date;
    v_vin text;
    v_count integer;
begin
    v_owner := private.require_vehicle_owner(p_vehicle_id);

    select vehicle.make,
           vehicle.model,
           vehicle.vehicle_year,
           vehicle.first_registration_date,
           vehicle.vin
      into v_make,
           v_model,
           v_year,
           v_first_registration_date,
           v_vin
      from public.vehicles vehicle
     where vehicle.id = p_vehicle_id;

    v_count := private.sync_vehicle_recall_matches_v2(
        p_vehicle_id,
        v_owner,
        v_make,
        v_model,
        v_year,
        v_first_registration_date,
        v_vin
    );

    perform public.recalculate_vehicle_reminders(p_vehicle_id);
    return v_count;
end;
$function$;

create or replace function public.match_all_vehicle_recalls()
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_vehicle record;
    v_total integer := 0;
begin
    for v_vehicle in
        select id,
               user_id,
               make,
               model,
               vehicle_year,
               first_registration_date,
               vin
          from public.vehicles
    loop
        v_total := v_total + private.sync_vehicle_recall_matches_v2(
            v_vehicle.id,
            v_vehicle.user_id,
            v_vehicle.make,
            v_vehicle.model,
            v_vehicle.vehicle_year,
            v_vehicle.first_registration_date,
            v_vehicle.vin
        );
        -- Le recalcul global est execute sans session utilisateur.
        -- private.sync_vehicle_recall_matches() gere deja les reminders RECALL.
    end loop;

    return v_total;
end;
$function$;

revoke all on function public.set_vehicle_first_registration_date(uuid,date)
from public, anon;
grant execute on function public.set_vehicle_first_registration_date(uuid,date)
to authenticated, service_role;

revoke all on function private.recall_context_contains_vin(text,text) from public;
revoke all on function private.recall_match_score_v2(text,text,integer,date,text,text,text,date,date,text) from public;
revoke all on function private.sync_vehicle_recall_matches_v2(uuid,uuid,text,text,integer,date,text) from public;

revoke all on function public.match_vehicle_recalls(uuid) from public, anon;
grant execute on function public.match_vehicle_recalls(uuid) to authenticated, service_role;

revoke all on function public.match_all_vehicle_recalls() from public, anon, authenticated;
grant execute on function public.match_all_vehicle_recalls() to service_role;

select public.match_all_vehicle_recalls() as recall_matches_recalculated;

commit;
