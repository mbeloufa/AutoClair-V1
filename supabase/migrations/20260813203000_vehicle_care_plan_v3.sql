begin;

create or replace function public.apply_vehicle_maintenance_fallback(
    p_vehicle_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_owner uuid;
    v_fuel_type text;
    v_current_mileage integer;
    v_first_registration date;
    v_template public.maintenance_templates%rowtype;
    v_item_id uuid;
    v_schedule_id uuid;
    v_due_mileage integer;
    v_due_date date;
    v_last_service_date date;
    v_last_service_mileage integer;
    v_basis text;
    v_count integer := 0;
begin
    v_owner := private.require_vehicle_owner(p_vehicle_id);

    select
        private.normalized_fuel_type(v.fuel_type),
        coalesce(v.mileage, 0),
        v.first_registration_date
      into v_fuel_type, v_current_mileage, v_first_registration
      from public.vehicles v
     where v.id = p_vehicle_id;

    if not found then
        raise exception 'VEHICLE_NOT_FOUND';
    end if;

    for v_template in
        select t.*
          from public.maintenance_templates t
         where t.active = true
           and t.code in ('ENGINE_OIL', 'OIL_FILTER')
           and (
               'ALL' = any(t.applicable_fuel_types)
               or v_fuel_type = any(t.applicable_fuel_types)
               or (v_fuel_type = 'PHEV' and 'HYBRID' = any(t.applicable_fuel_types))
           )
         order by t.code
    loop
        insert into public.vehicle_maintenance_items
        (
            user_id, vehicle_id, template_id, item_code, label,
            category, source_type, confidence, metadata
        )
        values
        (
            v_owner, p_vehicle_id, v_template.id, v_template.code,
            v_template.label, v_template.category,
            'AUTOCLAIR_RULE', 0.55,
            jsonb_build_object(
                'disclaimer', v_template.disclaimer,
                'fallback_scope', 'SERVICE_ONLY'
            )
        )
        on conflict (vehicle_id, item_code)
        do update set
            template_id = excluded.template_id,
            label = excluded.label,
            category = excluded.category,
            source_type = excluded.source_type,
            confidence = excluded.confidence,
            metadata = public.vehicle_maintenance_items.metadata
                || excluded.metadata,
            updated_at = now()
        returning id into v_item_id;

        v_last_service_date := null;
        v_last_service_mileage := null;

        select
            e.occurred_at::date,
            e.mileage
          into v_last_service_date, v_last_service_mileage
          from public.vehicle_events e
         where e.vehicle_id = p_vehicle_id
           and e.status = 'COMPLETED'
           and (
               upper(coalesce(e.event_type, '')) = 'MAINTENANCE'
               or lower(coalesce(e.title, '')) like '%vidange%'
               or lower(coalesce(e.title, '')) like '%revision%'
               or lower(coalesce(e.title, '')) like '%révision%'
               or lower(coalesce(e.title, '')) like '%entretien%'
               or upper(coalesce(e.metadata ->> 'subcategory_code', '')) in (
                   'SERVICE',
                   'SERVICE_OIL',
                   'OIL_CHANGE'
               )
           )
         order by e.occurred_at desc
         limit 1;

        v_due_date := null;
        v_due_mileage := null;

        if v_template.interval_months is not null then
            if v_last_service_date is not null then
                v_due_date := (
                    v_last_service_date
                    + make_interval(months => v_template.interval_months)
                )::date;
            elsif v_first_registration is not null then
                v_due_date := (
                    v_first_registration
                    + make_interval(
                        months => coalesce(
                            v_template.first_due_months,
                            v_template.interval_months
                        )
                    )
                )::date;
                while v_due_date <= current_date loop
                    v_due_date := (
                        v_due_date
                        + make_interval(months => v_template.interval_months)
                    )::date;
                end loop;
            else
                v_due_date := (
                    current_date
                    + make_interval(
                        months => coalesce(
                            v_template.first_due_months,
                            v_template.interval_months
                        )
                    )
                )::date;
            end if;
        end if;

        if v_template.interval_km is not null then
            if v_last_service_mileage is not null then
                v_due_mileage :=
                    v_last_service_mileage + v_template.interval_km;
            elsif v_current_mileage > 0 then
                v_due_mileage :=
                    ((v_current_mileage / v_template.interval_km) + 1)
                    * v_template.interval_km;
            else
                v_due_mileage := coalesce(
                    v_template.first_due_km,
                    v_template.interval_km
                );
            end if;
        end if;

        v_basis := case
            when v_last_service_date is not null
              or v_last_service_mileage is not null
            then 'HISTORY_CONFIRMED'
            else 'AUTOCLAIR_GUIDANCE'
        end;

        select s.id
          into v_schedule_id
          from public.vehicle_maintenance_schedules s
         where s.vehicle_id = p_vehicle_id
           and s.item_id = v_item_id
           and s.status = 'ACTIVE'
         order by s.updated_at desc
         limit 1;

        if v_schedule_id is not null then
            update public.vehicle_maintenance_schedules
               set title = v_template.label,
                   schedule_type = 'MAINTENANCE',
                   due_date = v_due_date,
                   due_mileage = v_due_mileage,
                   interval_months = v_template.interval_months,
                   interval_km = v_template.interval_km,
                   priority = v_template.priority,
                   source_type = 'AUTOCLAIR_RULE',
                   confidence = 0.55,
                   reason =
                       'Pourquoi ? Une révision régulière aide à préserver '
                       'la lubrification du moteur et à repérer plus tôt '
                       'certaines anomalies. · Repère AutoClair indicatif '
                       'à confirmer avec le carnet constructeur.',
                   source_key = 'AUTOCLAIR_FALLBACK:' || v_template.code,
                   source_url = null,
                   source_label = 'Repère AutoClair',
                   source_quality = 'AUTOCLAIR_GUIDANCE',
                   calculation_basis = v_basis,
                   manufacturer_plan_id = null,
                   updated_at = now()
             where id = v_schedule_id;
        else
            insert into public.vehicle_maintenance_schedules
            (
                user_id, vehicle_id, item_id, title, schedule_type,
                due_date, due_mileage, interval_months, interval_km,
                status, priority, source_type, confidence, reason,
                source_key, source_url, source_label, source_quality,
                calculation_basis, manufacturer_plan_id
            )
            values
            (
                v_owner, p_vehicle_id, v_item_id, v_template.label,
                'MAINTENANCE', v_due_date, v_due_mileage,
                v_template.interval_months, v_template.interval_km,
                'ACTIVE', v_template.priority, 'AUTOCLAIR_RULE', 0.55,
                'Pourquoi ? Une révision régulière aide à préserver '
                'la lubrification du moteur et à repérer plus tôt '
                'certaines anomalies. · Repère AutoClair indicatif '
                'à confirmer avec le carnet constructeur.',
                'AUTOCLAIR_FALLBACK:' || v_template.code,
                null, 'Repère AutoClair', 'AUTOCLAIR_GUIDANCE',
                v_basis, null
            )
            on conflict (vehicle_id, source_key)
            do update set
                item_id = excluded.item_id,
                title = excluded.title,
                due_date = excluded.due_date,
                due_mileage = excluded.due_mileage,
                interval_months = excluded.interval_months,
                interval_km = excluded.interval_km,
                status = 'ACTIVE',
                priority = excluded.priority,
                confidence = excluded.confidence,
                reason = excluded.reason,
                source_label = excluded.source_label,
                source_quality = excluded.source_quality,
                calculation_basis = excluded.calculation_basis,
                updated_at = now();
        end if;

        v_count := v_count + 1;
    end loop;

    perform public.recalculate_vehicle_reminders(p_vehicle_id);
    return v_count;
end;
$function$;

revoke all on function public.apply_vehicle_maintenance_fallback(uuid)
from public, anon;
grant execute on function public.apply_vehicle_maintenance_fallback(uuid)
to authenticated;


create or replace function public.recalculate_vehicle_reminders(
    p_vehicle_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_owner uuid;
    v_count integer := 0;
    v_current_mileage integer;
    v_first_registration date;
    v_last_inspection date;
    v_inspection_due date;
    v_inspection_message text;
    v_last_odometer timestamptz;
    v_row record;
begin
    v_owner := private.require_vehicle_owner(p_vehicle_id);

    select
        coalesce(v.mileage, 0),
        coalesce(v.first_registration_date, p.first_registration_date)
      into v_current_mileage, v_first_registration
      from public.vehicles v
      left join public.vehicle_profiles p on p.vehicle_id = v.id
     where v.id = p_vehicle_id;

    for v_row in
        select s.id, s.title, s.due_date, s.due_mileage, s.priority
          from public.vehicle_maintenance_schedules s
         where s.vehicle_id = p_vehicle_id
           and s.status = 'ACTIVE'
    loop
        insert into public.vehicle_reminders
        (
            user_id, vehicle_id, source_type, source_id, source_key,
            title, message, due_at, due_mileage, lead_days, status, priority
        )
        values
        (
            v_owner, p_vehicle_id, 'SCHEDULE', v_row.id,
            'SCHEDULE:' || v_row.id::text,
            v_row.title,
            'Échéance indicative à confirmer avec les préconisations constructeur.',
            case
                when v_row.due_date is not null
                then v_row.due_date::timestamptz
                else null
            end,
            v_row.due_mileage,
            array[60,30,7]::integer[],
            'ACTIVE', v_row.priority
        )
        on conflict (vehicle_id, source_key)
        do update set
            title = excluded.title,
            message = excluded.message,
            due_at = excluded.due_at,
            due_mileage = excluded.due_mileage,
            priority = excluded.priority,
            status = case
                when public.vehicle_reminders.status = 'DONE'
                then 'DONE'
                else 'ACTIVE'
            end,
            updated_at = now();
        v_count := v_count + 1;
    end loop;

    for v_row in
        select w.id, w.title, w.ends_at
          from public.vehicle_warranties w
         where w.vehicle_id = p_vehicle_id
           and w.status = 'ACTIVE'
           and w.ends_at is not null
    loop
        insert into public.vehicle_reminders
        (
            user_id, vehicle_id, source_type, source_id, source_key,
            title, message, due_at, lead_days, status, priority
        )
        values
        (
            v_owner, p_vehicle_id, 'WARRANTY', v_row.id,
            'WARRANTY:' || v_row.id::text,
            'Garantie bientôt échue : ' || v_row.title,
            'Vérifiez les symptômes ou interventions à signaler avant l’expiration.',
            v_row.ends_at::timestamptz,
            array[60,30,7]::integer[], 'ACTIVE', 'HIGH'
        )
        on conflict (vehicle_id, source_key)
        do update set
            due_at = excluded.due_at,
            message = excluded.message,
            updated_at = now();
        v_count := v_count + 1;
    end loop;

    for v_row in
        select m.id, r.title, m.status
          from public.vehicle_recall_matches m
          join public.official_vehicle_recalls r on r.id = m.recall_id
         where m.vehicle_id = p_vehicle_id
           and m.status in ('TO_CHECK','POSSIBLE','SCHEDULED')
    loop
        insert into public.vehicle_reminders
        (
            user_id, vehicle_id, source_type, source_id, source_key,
            title, message, due_at, lead_days, status, priority
        )
        values
        (
            v_owner, p_vehicle_id, 'RECALL', v_row.id,
            'RECALL:' || v_row.id::text,
            coalesce(v_row.title, 'Rappel constructeur à vérifier'),
            'La correspondance est indicative. Confirmez l’éligibilité avec le VIN auprès du constructeur.',
            now(), array[0]::integer[], 'ACTIVE', 'CRITICAL'
        )
        on conflict (vehicle_id, source_key)
        do update set
            title = excluded.title,
            message = excluded.message,
            status = 'ACTIVE',
            updated_at = now();
        v_count := v_count + 1;
    end loop;

    select max(e.occurred_at::date)
      into v_last_inspection
      from public.vehicle_events e
     where e.vehicle_id = p_vehicle_id
       and e.event_type = 'INSPECTION'
       and e.status = 'COMPLETED';

    v_inspection_due := null;
    v_inspection_message := null;

    if v_last_inspection is not null then
        v_inspection_due :=
            (v_last_inspection + interval '2 years')::date;
        v_inspection_message :=
            'Dernier contrôle technique enregistré le '
            || to_char(v_last_inspection, 'DD/MM/YYYY')
            || '. Échéance suivante calculée 2 ans après.';
    elsif v_first_registration is not null then
        v_inspection_due :=
            (v_first_registration + interval '4 years')::date;
        v_inspection_message :=
            'Aucun contrôle technique n’est enregistré dans l’historique. '
            'Cette date est calculée depuis la première mise en circulation '
            'et doit être confirmée si un contrôle a déjà été réalisé.';
    end if;

    if v_inspection_due is not null then
        insert into public.vehicle_reminders
        (
            user_id, vehicle_id, source_type, source_key,
            title, message, due_at, lead_days, status, priority
        )
        values
        (
            v_owner, p_vehicle_id, 'INSPECTION', 'TECHNICAL_INSPECTION',
            'Contrôle technique',
            v_inspection_message,
            v_inspection_due::timestamptz,
            array[60,30,7]::integer[], 'ACTIVE', 'HIGH'
        )
        on conflict (vehicle_id, source_key)
        do update set
            title = excluded.title,
            message = excluded.message,
            due_at = excluded.due_at,
            priority = excluded.priority,
            status = 'ACTIVE',
            updated_at = now();
        v_count := v_count + 1;
    end if;

    select max(r.reading_at)
      into v_last_odometer
      from public.odometer_readings r
     where r.vehicle_id = p_vehicle_id;

    insert into public.vehicle_reminders
    (
        user_id, vehicle_id, source_type, source_key,
        title, message, due_at, lead_days, status, priority
    )
    values
    (
        v_owner, p_vehicle_id, 'ODOMETER_UPDATE', 'ODOMETER_UPDATE',
        'Mettre à jour le kilométrage',
        'Un kilométrage récent améliore les échéances et les estimations.',
        coalesce(v_last_odometer, now() - interval '90 days') + interval '90 days',
        array[7,0]::integer[], 'ACTIVE', 'LOW'
    )
    on conflict (vehicle_id, source_key)
    do update set
        due_at = excluded.due_at,
        updated_at = now();
    v_count := v_count + 1;

    update public.vehicle_reminders r
       set status = 'DONE', updated_at = now()
     where r.vehicle_id = p_vehicle_id
       and r.source_type = 'SCHEDULE'
       and r.source_id is not null
       and not exists (
           select 1
             from public.vehicle_maintenance_schedules s
            where s.id = r.source_id
              and s.status = 'ACTIVE'
       );

    return v_count;
end;
$function$;

commit;
