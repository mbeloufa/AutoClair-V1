-- Revalidation is tied to an unchanged original card, not an old AI timestamp.
begin;
alter table public.promo_v7_raw_cards add column if not exists available boolean not null default true;
create or replace function public.promo_v7_ingest_cards(p_source uuid,p_page text,p_cards jsonb)
returns integer language plpgsql security invoker set search_path='' as $fn$
declare n integer;
begin
 if p_page is null or length(p_page)>2000 or p_page not like 'https://%' or jsonb_typeof(p_cards)<>'array' or jsonb_array_length(p_cards)>24 then raise exception 'INVALID_RAW_CAPTURE';end if;
 if not exists(select 1 from public.commercial_offer_sources s where s.id=p_source and s.source_role in ('OFFER_HUB','OFFER_DETAIL') and s.publication_policy='AUTO_HIGH_CONFIDENCE' and s.trust_tier in ('PRIMARY','PROFESSIONAL')) then return 0;end if;
 perform pg_advisory_xact_lock(hashtext('promo_v7_capture:'||p_source::text||':'||p_page));
 insert into public.promo_v7_raw_cards(source_id,page_url,content_hash,raw_text,available)
 select p_source,p_page,md5(v.txt),v.txt,true
 from (select distinct trim(x->>'text') txt from jsonb_array_elements(p_cards) x where jsonb_typeof(x)='object') v
 where length(v.txt) between 18 and 1900
 on conflict(source_id,page_url,content_hash) do update set last_seen_at=now(),available=true;
 get diagnostics n=row_count;
 -- A nonempty, nontruncated snapshot that no longer contains a previous card
 -- withdraws it immediately; an empty/unreadable page does not fake a success.
 if n>0 and jsonb_array_length(p_cards)<24 then
 update public.promo_v7_raw_cards r set available=false
 where r.source_id=p_source and r.page_url=p_page and r.available
 and not exists(select 1 from jsonb_array_elements(p_cards) x where md5(trim(x->>'text'))=r.content_hash);
 end if;
 return n;
end $fn$;
revoke all on function public.promo_v7_ingest_cards(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.promo_v7_ingest_cards(uuid,text,jsonb) to service_role;
create or replace view public.promo_v7_catalog_preview with(security_invoker=true) as
with candidates as(
 select j.id job_id,j.origin_id,j.finished_at,j.source,j.model,j.engine,r.last_seen_at,v.item
 from public.promo_v7_shadow_jobs j
 join public.promo_v7_raw_cards r on j.origin_type='RAW_CARD' and r.id=j.origin_id
 join public.commercial_offer_sources s on s.id=r.source_id
 cross join lateral jsonb_array_elements(j.results) v(item)
 where j.status='DONE' and v.item->>'state'='READY'
 and nullif(v.item->>'identity','') is not null
 and r.available and r.last_seen_at>=now()-interval '72 hours'
 and s.status='ACTIVE' and s.source_role in ('OFFER_HUB','OFFER_DETAIL') and s.publication_policy='AUTO_HIGH_CONFIDENCE'
 and s.trust_tier in ('PRIMARY','PROFESSIONAL')
 and v.item->'offer'->>'ends_at'>=current_date::text
 and coalesce(v.item->'offer'->>'starts_at','0001-01-01')<=current_date::text
 and not exists(select 1 from public.promo_v7_shadow_jobs newer
 where newer.origin_type=j.origin_type and newer.origin_id=j.origin_id and newer.engine=j.engine and newer.model=j.model and newer.created_at>j.created_at)
)
select distinct on (item->>'identity',engine,model) item->>'identity' identity,item->'offer' offer,
 source,engine,model,job_id,origin_id,last_seen_at,finished_at
from candidates order by item->>'identity',engine,model,last_seen_at desc,finished_at desc,job_id;
revoke all on public.promo_v7_catalog_preview from public,anon,authenticated;
grant select on public.promo_v7_catalog_preview to service_role;
commit;
