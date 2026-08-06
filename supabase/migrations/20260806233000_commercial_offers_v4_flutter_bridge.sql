begin;

create table if not exists public.commercial_offer_v4_preferences (
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  offer_id uuid not null references public.commercial_offers(id) on delete cascade,
  status text not null check (status in ('SAVED','DISMISSED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, vehicle_id, offer_id)
);

create index if not exists commercial_offer_v4_preferences_vehicle_idx
  on public.commercial_offer_v4_preferences (user_id, vehicle_id, status, updated_at desc);

alter table public.commercial_offer_v4_preferences enable row level security;

drop policy if exists commercial_offer_v4_preferences_select_own
  on public.commercial_offer_v4_preferences;
create policy commercial_offer_v4_preferences_select_own
  on public.commercial_offer_v4_preferences
  for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists commercial_offer_v4_preferences_insert_own
  on public.commercial_offer_v4_preferences;
create policy commercial_offer_v4_preferences_insert_own
  on public.commercial_offer_v4_preferences
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1
      from public.vehicles v
      where v.id = vehicle_id
        and v.user_id = auth.uid()
    )
  );

drop policy if exists commercial_offer_v4_preferences_update_own
  on public.commercial_offer_v4_preferences;
create policy commercial_offer_v4_preferences_update_own
  on public.commercial_offer_v4_preferences
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists commercial_offer_v4_preferences_delete_own
  on public.commercial_offer_v4_preferences;
create policy commercial_offer_v4_preferences_delete_own
  on public.commercial_offer_v4_preferences
  for delete
  to authenticated
  using (user_id = auth.uid());

revoke all on public.commercial_offer_v4_preferences from anon;
grant select, insert, update, delete on public.commercial_offer_v4_preferences to authenticated;
grant all on public.commercial_offer_v4_preferences to service_role;

create or replace function public.get_vehicle_commercial_offers_v4(
  p_vehicle_id uuid,
  p_limit integer default 120
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_vehicle record;
  v_vehicle_json jsonb;
  v_make text;
  v_model text;
  v_nickname text;
  v_vehicle_name text;
  v_fuel text;
  v_year integer;
  v_mileage integer;
  v_limit integer := greatest(1, least(coalesce(p_limit, 120), 150));
  v_offers jsonb := '[]'::jsonb;
  v_active_source_count integer := 0;
  v_active_offer_count integer := 0;
  v_last_successful_sync_at timestamptz;
begin
  if v_user_id is null then
    raise exception 'COMMERCIAL_OFFERS_AUTH_REQUIRED';
  end if;

  select v.*
  into v_vehicle
  from public.vehicles v
  where v.id = p_vehicle_id
    and v.user_id = v_user_id;

  if not found then
    raise exception 'COMMERCIAL_OFFERS_VEHICLE_NOT_FOUND';
  end if;

  v_vehicle_json := to_jsonb(v_vehicle);
  v_make := trim(coalesce(v_vehicle_json->>'make', ''));
  v_model := trim(coalesce(v_vehicle_json->>'model', ''));
  v_nickname := nullif(trim(coalesce(v_vehicle_json->>'nickname', '')), '');
  v_fuel := nullif(trim(coalesce(v_vehicle_json->>'fuel_type', '')), '');

  v_year := case
    when coalesce(v_vehicle_json->>'vehicle_year', '') ~ '^[0-9]{4}$'
      then (v_vehicle_json->>'vehicle_year')::integer
    when coalesce(v_vehicle_json->>'year', '') ~ '^[0-9]{4}$'
      then (v_vehicle_json->>'year')::integer
    else null
  end;

  v_mileage := case
    when coalesce(v_vehicle_json->>'mileage', '') ~ '^[0-9]+$'
      then (v_vehicle_json->>'mileage')::integer
    else null
  end;

  v_vehicle_name := coalesce(
    v_nickname,
    nullif(trim(concat_ws(' ', v_make, v_model)), ''),
    'Mon véhicule'
  );

  select coalesce(jsonb_agg(r.offer_payload order by
      r.sort_brand_fallback asc,
      r.sort_match_score desc,
      r.sort_featured desc,
      r.sort_updated_at desc
    ), '[]'::jsonb)
  into v_offers
  from (
    select
      jsonb_build_object(
        'id', o.id,
        'offer_key', o.offer_key,
        'title', o.title,
        'summary', coalesce(o.summary, ''),
        'category', coalesce(o.category, 'OTHER'),
        'offer_context', coalesce(nullif(to_jsonb(o)->>'offer_context', ''), 'CURRENT_VEHICLE'),
        'targeting_scope', coalesce(
          nullif(to_jsonb(o)->>'targeting_scope', ''),
          case
            when coalesce(cardinality(o.model_patterns), 0) > 0 then 'MODEL'
            else 'BRAND'
          end
        ),
        'benefit_kind', coalesce(o.benefit_kind, 'INFO'),
        'benefit_label', coalesce(nullif(o.benefit_label, ''), 'Avantage à vérifier'),
        'benefit_value', o.benefit_value,
        'price_amount', o.price_amount,
        'original_price_amount', o.original_price_amount,
        'currency', coalesce(nullif(o.currency, ''), 'EUR'),
        'starts_at', o.starts_at,
        'ends_at', o.ends_at,
        'source_name', coalesce(
          nullif(to_jsonb(s)->>'source_name', ''),
          nullif(to_jsonb(s)->>'name', ''),
          nullif(to_jsonb(s)->>'label', ''),
          case
            when coalesce(cardinality(o.brands), 0) > 0
              then initcap(o.brands[1]) || ' — source officielle'
            else 'Source officielle'
          end
        ),
        'official_url', coalesce(o.official_url, ''),
        'conditions_summary', coalesce(o.conditions_summary, ''),
        'eligibility_notes', coalesce(o.eligibility_notes, ''),
        'compatibility', case m.match_level
          when 'CONFIRMED' then 'COMPATIBLE'
          when 'LIKELY' then 'LIKELY'
          else 'CHECK'
        end,
        'relevance_label', case m.match_level
          when 'CONFIRMED' then 'Très pertinente'
          when 'LIKELY' then 'Probablement compatible'
          else 'Conditions à vérifier'
        end,
        'relevance_score', m.match_score,
        'relevant_now', (
          not coalesce(o.is_brand_fallback, false)
          and m.match_level in ('CONFIRMED','LIKELY')
        ),
        'expires_soon', (
          o.ends_at is not null
          and o.ends_at >= current_date
          and o.ends_at <= current_date + 30
        ),
        'is_saved', coalesce(pref.status = 'SAVED', false),
        'why', to_jsonb(coalesce(m.matched_rules, '{}'::text[]) || coalesce(m.unknown_rules, '{}'::text[])),
        'requires_manual_eligibility', coalesce(o.requires_manual_eligibility, false),
        'requires_network_participation', coalesce(o.requires_network_participation, false),
        'requires_existing_contract', coalesce(o.requires_existing_contract, false),
        'last_verified_at', coalesce(o.last_verified_at, o.updated_at, now()),
        'auto_extracted', coalesce((to_jsonb(o)->>'auto_extracted')::boolean, false),
        'extraction_confidence', case
          when to_jsonb(o)->>'extraction_confidence' ~ '^[0-9]+$'
            then (to_jsonb(o)->>'extraction_confidence')::integer
          when o.match_confidence between 0 and 1
            then round(o.match_confidence * 100)::integer
          else null
        end,
        'match_level', m.match_level,
        'match_score', m.match_score,
        'matched_rules', to_jsonb(coalesce(m.matched_rules, '{}'::text[])),
        'unknown_rules', to_jsonb(coalesce(m.unknown_rules, '{}'::text[])),
        'is_brand_fallback', coalesce(o.is_brand_fallback, false)
      ) as offer_payload,
      coalesce(o.is_brand_fallback, false) as sort_brand_fallback,
      m.match_score as sort_match_score,
      coalesce(o.is_featured, false) as sort_featured,
      coalesce(o.updated_at, now()) as sort_updated_at
    from public.match_commercial_offers_v4(
      v_make,
      v_model,
      v_year,
      v_fuel,
      v_mileage
    ) m
    join public.commercial_offers o
      on o.id = m.offer_id
    left join public.commercial_offer_sources s
      on s.id = o.source_id
    left join public.commercial_offer_v4_preferences pref
      on pref.user_id = v_user_id
     and pref.vehicle_id = p_vehicle_id
     and pref.offer_id = o.id
    where coalesce(pref.status, 'NONE') <> 'DISMISSED'
    order by
      coalesce(o.is_brand_fallback, false) asc,
      m.match_score desc,
      coalesce(o.is_featured, false) desc,
      coalesce(o.updated_at, now()) desc
    limit v_limit
  ) r;

  select count(*)::integer
  into v_active_source_count
  from public.commercial_offer_sources;

  select count(*)::integer
  into v_active_offer_count
  from public.commercial_offers o
  where o.status = 'ACTIVE'
    and (o.starts_at is null or o.starts_at <= current_date)
    and (o.ends_at is null or o.ends_at >= current_date);

  select max(r.finished_at)
  into v_last_successful_sync_at
  from public.commercial_offer_v4_runs r
  where r.status = 'SUCCESS';

  return jsonb_build_object(
    'vehicle_id', p_vehicle_id,
    'vehicle_name', v_vehicle_name,
    'generated_at', now(),
    'active_source_count', v_active_source_count,
    'active_offer_count', v_active_offer_count,
    'last_successful_sync_at', v_last_successful_sync_at,
    'offers', v_offers
  );
end;
$function$;

create or replace function public.set_vehicle_commercial_offer_preference_v4(
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
  v_user_id uuid := auth.uid();
  v_status text := upper(trim(coalesce(p_status, '')));
begin
  if v_user_id is null then
    raise exception 'COMMERCIAL_OFFERS_AUTH_REQUIRED';
  end if;

  if not exists (
    select 1
    from public.vehicles v
    where v.id = p_vehicle_id
      and v.user_id = v_user_id
  ) then
    raise exception 'COMMERCIAL_OFFERS_VEHICLE_NOT_FOUND';
  end if;

  if not exists (
    select 1
    from public.commercial_offers o
    where o.id = p_offer_id
      and o.status = 'ACTIVE'
  ) then
    raise exception 'COMMERCIAL_OFFERS_OFFER_NOT_FOUND';
  end if;

  if v_status not in ('NONE','SAVED','DISMISSED') then
    raise exception 'COMMERCIAL_OFFERS_STATUS_INVALID';
  end if;

  if v_status = 'NONE' then
    delete from public.commercial_offer_v4_preferences p
    where p.user_id = v_user_id
      and p.vehicle_id = p_vehicle_id
      and p.offer_id = p_offer_id;
    return;
  end if;

  insert into public.commercial_offer_v4_preferences (
    user_id,
    vehicle_id,
    offer_id,
    status,
    updated_at
  ) values (
    v_user_id,
    p_vehicle_id,
    p_offer_id,
    v_status,
    now()
  )
  on conflict (user_id, vehicle_id, offer_id)
  do update set
    status = excluded.status,
    updated_at = now();
end;
$function$;

create or replace function public.reset_vehicle_offer_dismissals_v4(
  p_vehicle_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'COMMERCIAL_OFFERS_AUTH_REQUIRED';
  end if;

  if not exists (
    select 1
    from public.vehicles v
    where v.id = p_vehicle_id
      and v.user_id = v_user_id
  ) then
    raise exception 'COMMERCIAL_OFFERS_VEHICLE_NOT_FOUND';
  end if;

  delete from public.commercial_offer_v4_preferences p
  where p.user_id = v_user_id
    and p.vehicle_id = p_vehicle_id
    and p.status = 'DISMISSED';
end;
$function$;

revoke all on function public.get_vehicle_commercial_offers_v4(uuid, integer) from public, anon;
revoke all on function public.set_vehicle_commercial_offer_preference_v4(uuid, uuid, text) from public, anon;
revoke all on function public.reset_vehicle_offer_dismissals_v4(uuid) from public, anon;

grant execute on function public.get_vehicle_commercial_offers_v4(uuid, integer) to authenticated;
grant execute on function public.set_vehicle_commercial_offer_preference_v4(uuid, uuid, text) to authenticated;
grant execute on function public.reset_vehicle_offer_dismissals_v4(uuid) to authenticated;

commit;
