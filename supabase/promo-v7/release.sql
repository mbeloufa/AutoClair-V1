-- V7 release layer: explicitly gated, no mutation of legacy catalogue.
begin;
create table if not exists public.promo_v7_release_settings(
 singleton boolean primary key default true check(singleton),
 enabled boolean not null default false,
 approved_engine text not null default 'promo-v7.2',
 approved_model text not null default '',
 qa_approved boolean not null default false,
 qa_reference text not null default '',
 minimum_offers integer not null default 20 check(minimum_offers>=1),
 minimum_operators integer not null default 5 check(minimum_operators>=1),
 minimum_purchase_offers integer not null default 5 check(minimum_purchase_offers>=1),
 minimum_apv_offers integer not null default 10 check(minimum_apv_offers>=1),
 updated_at timestamptz not null default now()
);
insert into public.promo_v7_release_settings(singleton) values(true) on conflict do nothing;
alter table public.promo_v7_release_settings enable row level security;
revoke all on public.promo_v7_release_settings from public,anon,authenticated;
grant select,update on public.promo_v7_release_settings to service_role;
drop policy if exists promo_v7_release_server on public.promo_v7_release_settings;
create policy promo_v7_release_server on public.promo_v7_release_settings for all to service_role using(true) with check(true);
create table if not exists public.promo_v7_preferences(
 user_id uuid not null references auth.users(id) on delete cascade,
 vehicle_id uuid not null references public.vehicles(id) on delete cascade,
 offer_id uuid not null,
 status text not null check(status in ('SAVED','DISMISSED')),
 primary key(user_id,vehicle_id,offer_id)
);
alter table public.promo_v7_preferences enable row level security;
revoke all on public.promo_v7_preferences from public,anon,authenticated;
grant select,insert,update,delete on public.promo_v7_preferences to service_role;
drop policy if exists promo_v7_prefs_server on public.promo_v7_preferences;
create policy promo_v7_prefs_server on public.promo_v7_preferences for all to service_role using(true) with check(true);

-- Separate approved version and source freshness; reuse unchanged validated text.
create or replace view public.promo_v7_release_catalog with(security_invoker=true) as
select md5(p.identity)::uuid as id,p.*
from public.promo_v7_catalog_preview p
cross join public.promo_v7_release_settings settings
where p.engine=settings.approved_engine and p.model=settings.approved_model
and p.last_seen_at>=now()-interval '72 hours';
revoke all on public.promo_v7_release_catalog from public,anon,authenticated;
grant select on public.promo_v7_release_catalog to service_role;
create or replace function public.promo_v7_release_health()
returns jsonb language sql stable security invoker set search_path='' as $fn$
 select jsonb_build_object('enabled',s.enabled,'approved_engine',s.approved_engine,'approved_model',s.approved_model,
 'offers',q.n,'operators',q.operators,'apv',q.apv,'purchase',q.purchase,
 'qa_approved',s.qa_approved,'ready',s.qa_approved and length(trim(s.qa_reference))>0 and q.n>=s.minimum_offers and q.operators>=s.minimum_operators and q.apv>=s.minimum_apv_offers and q.purchase>=s.minimum_purchase_offers and s.approved_model<>'')
 from public.promo_v7_release_settings s
 cross join lateral(select count(*) n,count(distinct source->>'operator') operators,
 count(*) filter(where offer->>'context'='CURRENT_VEHICLE') apv,
 count(*) filter(where offer->>'context'='VEHICLE_PURCHASE') purchase
 from public.promo_v7_release_catalog)q where s.singleton
$fn$;
revoke all on function public.promo_v7_release_health() from public,anon,authenticated;
grant execute on function public.promo_v7_release_health() to service_role;
create or replace function public.promo_v7_set_enabled(p_enabled boolean)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
declare h jsonb;
begin
 if p_enabled is null then raise exception 'INVALID_RELEASE_FLAG';end if;
 perform pg_advisory_xact_lock(hashtext('promo_v7_release'));
 h:=public.promo_v7_release_health();
 if p_enabled and not coalesce((h->>'ready')::boolean,false) then raise exception 'PROMO_V7_RELEASE_NOT_READY';end if;
 update public.promo_v7_release_settings set enabled=p_enabled,updated_at=now() where singleton;
 return public.promo_v7_release_health();
end $fn$;
revoke all on function public.promo_v7_set_enabled(boolean) from public,anon,authenticated;
grant execute on function public.promo_v7_set_enabled(boolean) to service_role;

create or replace function public.promo_v7_norm(p_value text)
returns text language sql immutable security invoker set search_path='' as $fn$
 select trim(regexp_replace(translate(lower(coalesce(p_value,'')),'àáâäãåçéèêëíìîïñóòôöõúùûüýÿšž','aaaaaaceeeeiiiinooooouuuuyysz'),'[^a-z0-9]+',' ','g'))
$fn$;
create or replace function public.promo_v7_brand(p_value text)
returns text language sql immutable security invoker set search_path='' as $fn$
 select case public.promo_v7_norm(p_value) when 'vw' then 'volkswagen' when 'mercedes' then 'mercedes benz' else public.promo_v7_norm(p_value) end
$fn$;

-- A missing eligibility criterion cannot be treated as a confirmed match.
-- A source brand restricts the scope even if it is absent from the card.
create or replace function public.promo_v7_match(o jsonb,src jsonb,p_brand text,p_model text,p_year integer,p_fuel text)
returns text language plpgsql stable security invoker set search_path='' as $fn$
declare brand text:=public.promo_v7_brand(p_brand); model text:=public.promo_v7_norm(p_model);
 target text:=public.promo_v7_brand(coalesce(nullif(o->>'vehicle_brand',''),nullif(src->>'canonical_brand','*')));
 fuel text:=public.normalize_offer_fuel_v6(p_fuel); age int; uncertain boolean:=false;
begin
 if o->>'context'<>'CURRENT_VEHICLE' then return 'NO';end if;
 if target<>'' and brand<>target then return 'NO';end if;
 if exists(select 1 from jsonb_array_elements_text(coalesce(o->'excluded_models','[]')) x where public.promo_v7_norm(x)=model) then return 'NO';end if;
 if jsonb_array_length(coalesce(o->'models','[]'))>0 then
   if model='' then uncertain:=true;
   elsif not exists(select 1 from jsonb_array_elements_text(o->'models') x where public.promo_v7_norm(x)=model) then return 'NO';end if;
 end if;
 if jsonb_array_length(coalesce(o->'fuel_types','[]'))>0 then
   if coalesce(fuel,'')='' or nullif(trim(p_fuel),'') is null then uncertain:=true;
   elsif not exists(select 1 from jsonb_array_elements_text(o->'fuel_types') x where public.normalize_offer_fuel_v6(x)=fuel) then return 'NO';end if;
 end if;
 if p_year is not null then age:=extract(year from current_date)::int-p_year;end if;
 if o->>'age_min' is not null or o->>'age_max' is not null then
   if age is null then uncertain:=true;
   elsif (o->>'age_min' is not null and age<(o->>'age_min')::int) or (o->>'age_max' is not null and age>(o->>'age_max')::int) then return 'NO';end if;
 end if;
 -- Geographic / network / tyre dimension / contract information cannot be confirmed
 -- from the vehicle fields. Do not claim fully compatible merely from brand.
 if uncertain or o->>'geographic_scope'='LOCAL' then return 'CHECK';end if;
 if target<>'' and brand=target then return 'LIKELY';end if;
 -- General network offers with verified applicability are relevant, but never
 -- automatically confirm tyre dimensions, local availability or contracts.
 if target='' and o->>'geographic_scope'='NATIONAL' then return 'LIKELY';end if;
 return 'CHECK';
end $fn$;

create or replace function public.promo_v7_payload(r public.promo_v7_release_catalog,p_match text,p_saved boolean)
returns jsonb language sql stable security invoker set search_path='' as $fn$
 select jsonb_build_object(
 'id',r.id,'offer_key','promo-v7:'||r.id,'title',r.offer->>'title',
 'summary',r.offer->>'subject','category',r.offer->>'category','offer_context',r.offer->>'context',
 'targeting_scope',case when jsonb_array_length(coalesce(r.offer->'models','[]'))>0 then 'MODEL' when coalesce(nullif(r.offer->>'vehicle_brand',''),nullif(r.source->>'canonical_brand','*')) is not null then 'BRAND' else 'ALL_VEHICLES' end,
 'benefit_kind',r.offer->>'kind','benefit_label',r.offer->>'benefit_quote',
 'benefit_value',case when r.offer->>'kind' in ('PERCENT','FIXED_DISCOUNT','REIMBURSEMENT') then r.offer->'amount' end,
 'price_amount',case when r.offer->>'kind' in ('PRICE','FROM_PRICE','MONTHLY') then r.offer->'amount' end,
 'original_price_amount',null,'currency','EUR','starts_at',r.offer->>'starts_at','ends_at',r.offer->>'ends_at',
 'source_name',r.source->>'operator','official_url',r.source->>'url','conditions_summary',r.offer->>'conditions_quote',
 'eligibility_notes',case when p_match='MATCH' then 'Conditions à consulter sur le site officiel.' else 'Compatibilité et participation du réseau à vérifier.' end,
 'compatibility',case when p_match='MATCH' then 'COMPATIBLE' when p_match='LIKELY' then 'LIKELY' else 'CHECK' end,
 'relevance_label',case when p_match='MATCH' then 'Modèle et critères identifiés' when p_match='LIKELY' then 'Probablement compatible — conditions à vérifier' else 'Conditions à vérifier' end,
 'relevance_score',case when p_match='MATCH' then 100 when p_match='LIKELY' then 65 else 30 end,'relevant_now',p_match in ('MATCH','LIKELY'),
 'expires_soon',(r.offer->>'ends_at')::date<=current_date+30,'is_saved',p_saved,
 'why',jsonb_build_array(case when p_match='MATCH' then 'Critères véhicule vérifiés' else 'Éligibilité non confirmée' end),
 'requires_manual_eligibility',p_match<>'MATCH','requires_network_participation',true,'requires_existing_contract',false,
 'last_verified_at',r.last_seen_at,'auto_extracted',true,
 'brands',case when coalesce(nullif(r.offer->>'vehicle_brand',''),nullif(r.source->>'canonical_brand','*')) is not null then jsonb_build_array(coalesce(nullif(r.offer->>'vehicle_brand',''),nullif(r.source->>'canonical_brand','*'))) else '[]'::jsonb end,
 'model_patterns',r.offer->'models','fuel_types',r.offer->'fuel_types','commercial_value_score',0
 )
$fn$;

-- Internal privileged RPCs, explicit owner check, execute only for authenticated.
-- Null means intentionally disabled; client may use the existing V4 service only then.
create or replace function public.promo_v7_vehicle(p_vehicle_id uuid,p_limit integer default 120)
returns jsonb language plpgsql stable security definer set search_path='' as $fn$
declare v public.vehicles%rowtype; data jsonb; uid uuid:=auth.uid();
begin
 if uid is null then raise exception 'COMMERCIAL_OFFERS_AUTH_REQUIRED';end if;
 select * into v from public.vehicles where id=p_vehicle_id and user_id=uid;
 if not found then raise exception 'COMMERCIAL_OFFERS_VEHICLE_NOT_FOUND';end if;
 if not coalesce((select enabled from public.promo_v7_release_settings where singleton),false) then return null;end if;
 select coalesce(jsonb_agg(x.payload order by x.score desc,x.saved desc,x.last_seen_at desc,x.id),'[]'::jsonb) into data
 from (
 select public.promo_v7_payload(c,m.level,coalesce(p.status='SAVED',false)) payload,
 case when m.level='MATCH' then 100 when m.level='LIKELY' then 65 else 30 end score,coalesce(p.status='SAVED',false) saved,c.last_seen_at,c.id
 from public.promo_v7_release_catalog c
 cross join lateral(select public.promo_v7_match(c.offer,c.source,v.make,v.model,v.vehicle_year::int,v.fuel_type) level)m
 left join public.promo_v7_preferences p on p.user_id=uid and p.vehicle_id=v.id and p.offer_id=c.id
 where m.level<>'NO' and coalesce(p.status,'')<>'DISMISSED'
 order by score desc,saved desc,c.last_seen_at desc,c.id limit greatest(1,least(coalesce(p_limit,120),150))
 )x;
 return jsonb_build_object('engine','promo-v7','vehicle_id',v.id,'vehicle_name',coalesce(nullif(v.nickname,''),concat_ws(' ',v.make,v.model)),
 'generated_at',now(),'active_source_count',(select count(distinct source->>'operator') from public.promo_v7_release_catalog),
 'active_offer_count',jsonb_array_length(data),'last_successful_sync_at',(select max(last_seen_at) from public.promo_v7_release_catalog),'offers',data);
end $fn$;
revoke all on function public.promo_v7_vehicle(uuid,integer) from public,anon,authenticated;
grant execute on function public.promo_v7_vehicle(uuid,integer) to authenticated;
create or replace function public.promo_v7_purchase(p_brand text default null,p_model text default null,p_fuel text default null,p_vehicle_kind text default 'ALL',p_limit int default 100)
returns jsonb language plpgsql stable security definer set search_path='' as $fn$
declare data jsonb;
begin
 if auth.uid() is null then raise exception 'COMMERCIAL_OFFERS_AUTH_REQUIRED';end if;
 if not coalesce((select enabled from public.promo_v7_release_settings where singleton),false) then return null;end if;
 select coalesce(jsonb_agg(x.payload order by x.last_seen_at desc,x.id),'[]'::jsonb) into data from(
 select public.promo_v7_payload(c,'CHECK',false) payload,c.last_seen_at,c.id
 from public.promo_v7_release_catalog c where c.offer->>'context'='VEHICLE_PURCHASE'
 and (nullif(trim(p_brand),'') is null or public.promo_v7_brand(p_brand)=public.promo_v7_brand(coalesce(nullif(c.offer->>'vehicle_brand',''),c.source->>'canonical_brand')))
 and (nullif(trim(p_model),'') is null or exists(select 1 from jsonb_array_elements_text(c.offer->'models') x where public.promo_v7_norm(x)=public.promo_v7_norm(p_model)))
 and (nullif(trim(p_fuel),'') is null or exists(select 1 from jsonb_array_elements_text(c.offer->'fuel_types') x where public.normalize_offer_fuel_v6(x)=public.normalize_offer_fuel_v6(p_fuel)))
 and (coalesce(p_vehicle_kind,'ALL')='ALL' or (p_vehicle_kind='NEW' and c.offer->>'category'='NEW_VEHICLE') or (p_vehicle_kind='USED' and c.offer->>'category'='USED_VEHICLE'))
 order by c.last_seen_at desc,c.id limit greatest(1,least(coalesce(p_limit,100),150)))x;
 return jsonb_build_object('engine','promo-v7','generated_at',now(),'offers',data,'total_count',jsonb_array_length(data),'available_brands',
 (select coalesce(jsonb_agg(distinct coalesce(nullif(offer->>'vehicle_brand',''),source->>'canonical_brand')),'[]'::jsonb) from public.promo_v7_release_catalog where offer->>'context'='VEHICLE_PURCHASE'));
end $fn$;
revoke all on function public.promo_v7_purchase(text,text,text,text,integer) from public,anon,authenticated;
grant execute on function public.promo_v7_purchase(text,text,text,text,integer) to authenticated;
create or replace function public.promo_v7_preference(p_vehicle_id uuid,p_offer_id uuid,p_status text)
returns boolean language plpgsql security definer set search_path='' as $fn$
declare uid uuid:=auth.uid();
begin
 if uid is null then raise exception 'COMMERCIAL_OFFERS_AUTH_REQUIRED';end if;
 if not exists(select 1 from public.vehicles where id=p_vehicle_id and user_id=uid) then raise exception 'COMMERCIAL_OFFERS_VEHICLE_NOT_FOUND';end if;
 if not (select enabled from public.promo_v7_release_settings where singleton) then return false;end if;
 if p_status='RESET' then delete from public.promo_v7_preferences where user_id=uid and vehicle_id=p_vehicle_id and status='DISMISSED';return true;end if;
 if p_status not in ('SAVED','DISMISSED','NONE') or p_status is null then raise exception 'COMMERCIAL_OFFERS_STATUS_INVALID';end if;
 if p_status='NONE' then delete from public.promo_v7_preferences where user_id=uid and vehicle_id=p_vehicle_id and offer_id=p_offer_id;return true;end if;
 if not exists(select 1 from public.promo_v7_release_catalog c join public.vehicles v on v.id=p_vehicle_id where c.id=p_offer_id and public.promo_v7_match(c.offer,c.source,v.make,v.model,v.vehicle_year::int,v.fuel_type)<>'NO') then raise exception 'COMMERCIAL_OFFERS_OFFER_NOT_FOUND';end if;
 insert into public.promo_v7_preferences(user_id,vehicle_id,offer_id,status) values(uid,p_vehicle_id,p_offer_id,p_status)
 on conflict(user_id,vehicle_id,offer_id) do update set status=excluded.status;
 return true;
end $fn$;
revoke all on function public.promo_v7_preference(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.promo_v7_preference(uuid,uuid,text) to authenticated;
-- Private helpers are not API endpoints.
revoke execute on function public.promo_v7_norm(text),public.promo_v7_brand(text),public.promo_v7_match(jsonb,jsonb,text,text,integer,text),public.promo_v7_payload(public.promo_v7_release_catalog,text,boolean) from public,anon,authenticated;
grant execute on function public.promo_v7_norm(text),public.promo_v7_brand(text),public.promo_v7_match(jsonb,jsonb,text,text,integer,text),public.promo_v7_payload(public.promo_v7_release_catalog,text,boolean) to service_role;
commit;
