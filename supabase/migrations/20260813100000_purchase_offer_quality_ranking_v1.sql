begin;

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
      case
        when v_brand = '' then 0
        when exists (
          select 1
          from unnest(coalesce(o.brands, '{}'::text[])) b
          where lower(trim(b)) = v_brand
        ) then 50
        else -1000
      end as brand_score,
      case
        when v_model = '' then 0
        when exists (
          select 1
          from unnest(coalesce(o.model_patterns, '{}'::text[])) m
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
          select 1
          from unnest(coalesce(o.fuel_types, '{}'::text[])) f
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
      end as kind_score,
      case
        when o.original_price_amount is not null
          and o.price_amount is not null
          and o.original_price_amount > 0
          and o.original_price_amount > o.price_amount
          then least(
            1.0,
            greatest(
              0.0,
              (o.original_price_amount - o.price_amount) / o.original_price_amount
            )
          )
        when upper(coalesce(o.benefit_kind, '')) like '%PERCENT%'
          and coalesce(o.benefit_value, 0) > 0
          then least(1.0, greatest(0.0, o.benefit_value / 100.0))
        when upper(coalesce(o.benefit_kind, '')) in (
          'DISCOUNT', 'CASH_DISCOUNT', 'FIXED', 'FIXED_AMOUNT', 'AMOUNT'
        )
          and coalesce(o.benefit_value, 0) > 0
          and coalesce(o.price_amount, 0) > 0
          then least(
            1.0,
            greatest(
              0.0,
              o.benefit_value / (o.price_amount + o.benefit_value)
            )
          )
        else 0.0
      end as commercial_value_ratio,
      (
        case when nullif(trim(coalesce(o.official_url, '')), '') is not null then 25 else 0 end
        + case when nullif(trim(coalesce(o.conditions_summary, '')), '') is not null then 20 else 0 end
        + case when o.price_amount is not null or o.benefit_value is not null then 20 else 0 end
        + case
            when coalesce(o.last_verified_at, o.updated_at, now()) >= now() - interval '45 days'
              then 20
            else 0
          end
        + case
            when to_jsonb(o)->>'extraction_confidence' ~ '^[0-9]+$'
              and (to_jsonb(o)->>'extraction_confidence')::integer >= 70
              then 15
            when o.match_confidence between 0.70 and 1 then 15
            else 0
          end
      ) as quality_score
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
    select
      c.*,
      c.brand_score + c.model_score + c.fuel_score + c.kind_score as search_score,
      round(c.commercial_value_ratio * 10000)::integer as commercial_value_score
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
          e.commercial_value_score desc,
          e.quality_score desc,
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
        'brands', to_jsonb(coalesce(r.brands, '{}'::text[])),
        'model_patterns', to_jsonb(coalesce(r.model_patterns, '{}'::text[])),
        'fuel_types', to_jsonb(coalesce(r.fuel_types, '{}'::text[])),
        'commercial_value_score', r.commercial_value_score,
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
          case when v_kind <> 'ALL' and r.kind_score >= 15 then 'Type de véhicule correspondant' end
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

revoke all on function public.search_vehicle_purchase_offers_v4(text, text, text, text, integer)
from public, anon;
grant execute on function public.search_vehicle_purchase_offers_v4(text, text, text, text, integer)
to authenticated, service_role;

commit;
