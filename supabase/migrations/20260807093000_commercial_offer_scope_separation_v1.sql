begin;

alter table if exists public.commercial_offers
  add column if not exists offer_context text not null default 'CURRENT_VEHICLE';

alter table if exists public.commercial_offer_v4_candidates
  add column if not exists offer_context text not null default 'CURRENT_VEHICLE';

create index if not exists commercial_offers_offer_context_active_idx
  on public.commercial_offers (offer_context, status, updated_at desc);

create or replace function public.classify_commercial_offer_context_v5(
  p_title text,
  p_summary text,
  p_category text,
  p_conditions text,
  p_benefit_label text
)
returns text
language plpgsql
immutable
set search_path = ''
as $function$
declare
  v_category text := upper(trim(coalesce(p_category, '')));
  v_text text := lower(concat_ws(' ', p_title, p_summary, p_conditions, p_benefit_label));
begin
  if v_category in ('NEW_VEHICLE', 'USED_VEHICLE') then
    return 'VEHICLE_PURCHASE';
  end if;

  if v_text ~ '(location longue dur[ée]e|(^|[^a-z])lld([^a-z]|$)|location avec option d.?achat|(^|[^a-z])loa([^a-z]|$)|premier loyer|1er loyer|apport|cr[ée]dit auto|financement v[ée]hicule|offre de reprise|prime reprise|reprise de votre v[ée]hicule|v[ée]hicule neuf|voiture neuve|v[ée]hicule d.?occasion|voiture d.?occasion|commandez votre|[àa] l.?achat d.?un v[ée]hicule)' then
    return 'VEHICLE_PURCHASE';
  end if;

  return 'CURRENT_VEHICLE';
end;
$function$;

-- Reclassifie uniquement les offres du collecteur V4 ; les offres V3 déjà
-- typées restent inchangées.
update public.commercial_offers o
set offer_context = public.classify_commercial_offer_context_v5(
      o.title,
      o.summary,
      o.category,
      o.conditions_summary,
      o.benefit_label
    ),
    updated_at = now()
where o.v4_source_key is not null
  and coalesce(o.is_brand_fallback, false) = false;

update public.commercial_offers o
set offer_context = 'CURRENT_VEHICLE',
    updated_at = now()
where coalesce(o.is_brand_fallback, false) = true;

create or replace function public.get_vehicle_after_sales_offers_v4(
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
  v_bundle jsonb;
  v_filtered jsonb := '[]'::jsonb;
  v_limit integer := greatest(1, least(coalesce(p_limit, 120), 150));
begin
  v_bundle := public.get_vehicle_commercial_offers_v4(p_vehicle_id, 150);

  select coalesce(jsonb_agg(x.item order by x.ord), '[]'::jsonb)
  into v_filtered
  from (
    select e.item, e.ord
    from jsonb_array_elements(coalesce(v_bundle->'offers', '[]'::jsonb))
      with ordinality as e(item, ord)
    where coalesce(e.item->>'offer_context', 'CURRENT_VEHICLE') <> 'VEHICLE_PURCHASE'
      and upper(coalesce(e.item->>'category', '')) not in ('NEW_VEHICLE', 'USED_VEHICLE')
    order by e.ord
    limit v_limit
  ) x;

  return jsonb_set(
    jsonb_set(v_bundle, '{offers}', v_filtered, true),
    '{active_offer_count}',
    to_jsonb(jsonb_array_length(v_filtered)),
    true
  );
end;
$function$;

create or replace function public.search_vehicle_purchase_offers_v4(
  p_brand text default null,
  p_model text default null,
  p_fuel text default null,
  p_vehicle_kind text default 'ALL',
  p_limit integer default 100
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_brand text := lower(trim(coalesce(p_brand, '')));
  v_model text := lower(trim(coalesce(p_model, '')));
  v_fuel text := lower(trim(coalesce(p_fuel, '')));
  v_kind text := upper(trim(coalesce(p_vehicle_kind, 'ALL')));
  v_limit integer := greatest(1, least(coalesce(p_limit, 100), 150));
  v_offers jsonb := '[]'::jsonb;
  v_brands jsonb := '[]'::jsonb;
  v_total integer := 0;
begin
  if v_user_id is null then
    raise exception 'COMMERCIAL_OFFERS_AUTH_REQUIRED';
  end if;

  if v_kind not in ('ALL', 'NEW', 'USED') then
    v_kind := 'ALL';
  end if;

  select coalesce(jsonb_agg(b.brand order by b.brand), '[]'::jsonb)
  into v_brands
  from (
    select distinct initcap(trim(brand_value)) as brand
    from public.commercial_offers o
    cross join lateral unnest(coalesce(o.brands, '{}'::text[])) brand_value
    where o.status = 'ACTIVE'
      and (o.starts_at is null or o.starts_at <= current_date)
      and (o.ends_at is null or o.ends_at >= current_date)
      and coalesce(o.is_brand_fallback, false) = false
      and (
        coalesce(nullif(to_jsonb(o)->>'offer_context', ''), 'CURRENT_VEHICLE') = 'VEHICLE_PURCHASE'
        or upper(coalesce(o.category, '')) in ('NEW_VEHICLE', 'USED_VEHICLE')
      )
      and trim(brand_value) <> ''
  ) b;

  with candidates as (
    select
      o.*,
      lower(concat_ws(' ', o.title, o.summary, o.conditions_summary, o.eligibility_notes)) as search_text,
      case
        when v_brand = '' then 0
        when exists (
          select 1 from unnest(coalesce(o.brands, '{}'::text[])) b
          where lower(trim(b)) = v_brand
        ) then 50
        else -1000
      end as brand_score,
      case
        when v_model = '' then 0
        when exists (
          select 1 from unnest(coalesce(o.model_patterns, '{}'::text[])) m
          where v_model like '%' || lower(trim(m)) || '%'
             or lower(trim(m)) like '%' || v_model || '%'
        ) then 35
        when lower(concat_ws(' ', o.title, o.summary)) like '%' || v_model || '%' then 30
        when coalesce(cardinality(o.model_patterns), 0) = 0 then 5
        else -200
      end as model_score,
      case
        when v_fuel = '' then 0
        when exists (
          select 1 from unnest(coalesce(o.fuel_types, '{}'::text[])) f
          where lower(trim(f)) = v_fuel
        ) then 20
        when coalesce(cardinality(o.fuel_types), 0) = 0 then 0
        else -100
      end as fuel_score,
      case
        when v_kind = 'ALL' then 0
        when v_kind = 'USED' and upper(coalesce(o.category, '')) = 'USED_VEHICLE' then 15
        when v_kind = 'NEW' and upper(coalesce(o.category, '')) = 'NEW_VEHICLE' then 15
        when v_kind = 'NEW' and upper(coalesce(o.category, '')) <> 'USED_VEHICLE' then 5
        else -100
      end as kind_score
    from public.commercial_offers o
    where o.status = 'ACTIVE'
      and (o.starts_at is null or o.starts_at <= current_date)
      and (o.ends_at is null or o.ends_at >= current_date)
      and coalesce(o.is_brand_fallback, false) = false
      and (
        coalesce(nullif(to_jsonb(o)->>'offer_context', ''), 'CURRENT_VEHICLE') = 'VEHICLE_PURCHASE'
        or upper(coalesce(o.category, '')) in ('NEW_VEHICLE', 'USED_VEHICLE')
      )
  ), eligible as (
    select c.*,
      c.brand_score + c.model_score + c.fuel_score + c.kind_score as search_score
    from candidates c
    where c.brand_score > -100
      and c.model_score > -100
      and c.fuel_score > -100
      and c.kind_score > -100
  ), ranked as (
    select
      e.*,
      row_number() over (
        order by
          e.search_score desc,
          coalesce(e.is_featured, false) desc,
          coalesce(e.updated_at, now()) desc
      ) as row_rank
    from eligible e
  )
  select
    coalesce(jsonb_agg(
      jsonb_build_object(
        'id', r.id,
        'offer_key', r.offer_key,
        'title', r.title,
        'summary', coalesce(r.summary, ''),
        'category', case
          when upper(coalesce(r.category, '')) = 'USED_VEHICLE' then 'USED_VEHICLE'
          else 'NEW_VEHICLE'
        end,
        'offer_context', 'VEHICLE_PURCHASE',
        'targeting_scope', coalesce(
          nullif(to_jsonb(r)->>'targeting_scope', ''),
          case when coalesce(cardinality(r.model_patterns), 0) > 0 then 'MODEL' else 'BRAND' end
        ),
        'benefit_kind', coalesce(r.benefit_kind, 'INFO'),
        'benefit_label', coalesce(nullif(r.benefit_label, ''), 'Conditions à consulter'),
        'benefit_value', r.benefit_value,
        'price_amount', r.price_amount,
        'original_price_amount', r.original_price_amount,
        'currency', coalesce(nullif(r.currency, ''), 'EUR'),
        'starts_at', r.starts_at,
        'ends_at', r.ends_at,
        'source_name', case
          when coalesce(cardinality(r.brands), 0) > 0 then initcap(r.brands[1]) || ' — source suivie'
          else 'Source suivie'
        end,
        'official_url', coalesce(r.official_url, ''),
        'conditions_summary', coalesce(r.conditions_summary, ''),
        'eligibility_notes', coalesce(r.eligibility_notes, ''),
        'compatibility', case
          when v_model <> '' and r.model_score >= 30 then 'COMPATIBLE'
          when v_brand <> '' and r.brand_score > 0 then 'LIKELY'
          else 'CHECK'
        end,
        'relevance_label', case
          when v_model <> '' and r.model_score >= 30 then 'Modèle correspondant'
          when v_brand <> '' and r.brand_score > 0 then 'Marque correspondante'
          else 'Offre de vente active'
        end,
        'relevance_score', greatest(0, r.search_score),
        'relevant_now', true,
        'expires_soon', (
          r.ends_at is not null
          and r.ends_at >= current_date
          and r.ends_at <= current_date + 30
        ),
        'is_saved', false,
        'why', to_jsonb(array_remove(array[
          case when v_brand <> '' and r.brand_score > 0 then 'Marque correspondante' end,
          case when v_model <> '' and r.model_score >= 30 then 'Modèle présent dans l’offre' end,
          case when v_fuel <> '' and r.fuel_score > 0 then 'Énergie correspondante' end,
          case when v_kind <> 'ALL' and r.kind_score >= 15 then 'Type de véhicule correspondant' end,
          case when v_model <> '' and r.model_score = 5 then 'Offre générale de la marque à vérifier pour ce modèle' end
        ], null)),
        'requires_manual_eligibility', true,
        'requires_network_participation', coalesce(r.requires_network_participation, false),
        'requires_existing_contract', coalesce(r.requires_existing_contract, false),
        'last_verified_at', coalesce(r.last_verified_at, r.updated_at, now()),
        'auto_extracted', coalesce((to_jsonb(r)->>'auto_extracted')::boolean, false),
        'extraction_confidence', case
          when to_jsonb(r)->>'extraction_confidence' ~ '^[0-9]+$'
            then (to_jsonb(r)->>'extraction_confidence')::integer
          when r.match_confidence between 0 and 1
            then round(r.match_confidence * 100)::integer
          else null
        end
      ) order by r.row_rank
    ), '[]'::jsonb),
    count(*)::integer
  into v_offers, v_total
  from ranked r
  where r.row_rank <= v_limit;

  return jsonb_build_object(
    'generated_at', now(),
    'total_count', v_total,
    'available_brands', v_brands,
    'offers', v_offers
  );
end;
$function$;

revoke all on function public.classify_commercial_offer_context_v5(text, text, text, text, text) from public, anon;
revoke all on function public.get_vehicle_after_sales_offers_v4(uuid, integer) from public, anon;
revoke all on function public.search_vehicle_purchase_offers_v4(text, text, text, text, integer) from public, anon;

grant execute on function public.get_vehicle_after_sales_offers_v4(uuid, integer) to authenticated;
grant execute on function public.search_vehicle_purchase_offers_v4(text, text, text, text, integer) to authenticated;
grant execute on function public.classify_commercial_offer_context_v5(text, text, text, text, text) to service_role;

commit;
