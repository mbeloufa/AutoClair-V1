-- Promo V7 shadow installation ONLY. No writes to legacy commercial_offers.
-- Apply after staging approval. No automatic schedule is created.
begin;
create table if not exists public.promo_v7_shadow_jobs(
 id uuid primary key default gen_random_uuid(),
 origin_type text not null check(origin_type in ('ACTIVE_OFFER','CANDIDATE','RAW_CARD')),
 origin_id uuid not null,
 input_hash text not null,
 engine text not null,
 model text not null,
 input_text text not null,
 source jsonb not null,
 status text not null default 'RUNNING' check(status in ('RUNNING','DONE','FAILED')),
 results jsonb not null default '[]'::jsonb,
 usage jsonb,
 error_code text,
 created_at timestamptz not null default now(),
 finished_at timestamptz,
 unique(origin_type,origin_id,input_hash,engine,model)
);
alter table public.promo_v7_shadow_jobs enable row level security;
revoke all on public.promo_v7_shadow_jobs from public,anon,authenticated;
grant select,insert,update on public.promo_v7_shadow_jobs to service_role;
drop policy if exists promo_v7_server_only on public.promo_v7_shadow_jobs;
create policy promo_v7_server_only on public.promo_v7_shadow_jobs for all to service_role using (true) with check (true);
create index if not exists promo_v7_shadow_created on public.promo_v7_shadow_jobs(created_at);
create table if not exists public.promo_v7_raw_cards(
 id uuid primary key default gen_random_uuid(),
 source_id uuid not null references public.commercial_offer_sources(id),
 page_url text not null,
 content_hash text not null,
 raw_text text not null check(length(raw_text) between 18 and 1900),
 first_seen_at timestamptz not null default now(),
 last_seen_at timestamptz not null default now(),
 unique(source_id,page_url,content_hash)
);
alter table public.promo_v7_raw_cards enable row level security;
revoke all on public.promo_v7_raw_cards from public,anon,authenticated;
grant select,insert,update on public.promo_v7_raw_cards to service_role;
drop policy if exists promo_v7_raw_server_only on public.promo_v7_raw_cards;
create policy promo_v7_raw_server_only on public.promo_v7_raw_cards for all to service_role using(true) with check(true);
create index if not exists promo_v7_raw_seen on public.promo_v7_raw_cards(last_seen_at);
create or replace function public.promo_v7_ingest_cards(p_source uuid,p_page text,p_cards jsonb)
returns integer language plpgsql security invoker set search_path='' as $body$
declare n integer;
begin
 if p_page is null or length(p_page)>2000 or p_page not like 'https://%' or jsonb_typeof(p_cards)<>'array' or jsonb_array_length(p_cards)>24 then raise exception 'INVALID_RAW_CAPTURE';end if;
 if not exists(select 1 from public.commercial_offer_sources s where s.id=p_source and s.source_role in ('OFFER_HUB','OFFER_DETAIL') and s.publication_policy='AUTO_HIGH_CONFIDENCE' and s.trust_tier in ('PRIMARY','PROFESSIONAL')) then return 0;end if;
 insert into public.promo_v7_raw_cards(source_id,page_url,content_hash,raw_text)
 select p_source,p_page,md5(v.txt),v.txt
 from (select distinct trim(x->>'text') txt from jsonb_array_elements(p_cards) x where jsonb_typeof(x)='object') v
 where length(v.txt) between 18 and 1900
 on conflict(source_id,page_url,content_hash) do update set last_seen_at=now();
 get diagnostics n=row_count;
 return n;
end $body$;
revoke all on function public.promo_v7_ingest_cards(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.promo_v7_ingest_cards(uuid,text,jsonb) to service_role;
create or replace function public.promo_v7_claim_shadow(p_engine text,p_model text)
returns table(job_id uuid,input_text text,source jsonb)
language plpgsql security invoker set search_path='' as $body$
declare row public.promo_v7_shadow_jobs%rowtype;
begin
 if p_engine is null or p_model is null or length(p_engine)>80 or length(p_model)>100 then raise exception 'INVALID_ENGINE';end if;
 -- All worker invocations share this lock: a hard global cap, even across retries.
 perform pg_advisory_xact_lock(hashtext('promo_v7_shadow_global'));
 update public.promo_v7_shadow_jobs j set status='FAILED',error_code='CLAIM_TIMEOUT',finished_at=now()
 where j.status='RUNNING' and j.created_at<now()-interval '10 minutes';
 if exists(select 1 from public.promo_v7_shadow_jobs j where j.status='RUNNING') then return;end if;
 if (select count(*) from public.promo_v7_shadow_jobs j where j.created_at>=now()-interval '24 hours')>=24 then return;end if;
 -- Existing verified snippets first, then recent eligible candidates. No personal data sent.
 -- Evidence is a limited excerpt, not proof of full current page; READY remains shadow only.
 with inputs as (
 select 'RAW_CARD'::text as origin_type,r.id origin_id,0 priority,r.last_seen_at as observed,r.raw_text txt,
 jsonb_build_object('operator',coalesce(nullif(regexp_replace(split_part(split_part(s.source_url,'://',2),'/',1),'^www[.]',''),''),s.operator_name,s.source_name),
 'canonical_brand',coalesce(s.canonical_brand_code,'*'),'role',s.source_role,'policy',s.publication_policy,'trust',s.trust_tier,
 'url',r.page_url,'source_status',s.status,'evidence_level','RAW_CARD') src
 from public.promo_v7_raw_cards r join public.commercial_offer_sources s on s.id=r.source_id
 where r.last_seen_at>=now()-interval '7 days' and s.status='ACTIVE'
 union all
 select 'ACTIVE_OFFER',o.id,1,o.last_verified_at,
 left(coalesce(nullif(o.evidence->>'raw_offer_excerpt',''),concat_ws(E'\n',o.title,o.summary,o.evidence->>'normalized_excerpt',o.conditions_summary)),5000) txt,
 jsonb_build_object('operator',coalesce(nullif(regexp_replace(split_part(split_part(s.source_url,'://',2),'/',1),'^www[.]',''),''),nullif(s.operator_name,''),s.source_name),
 'canonical_brand',coalesce(s.canonical_brand_code,'*'),'role',s.source_role,'policy',s.publication_policy,'trust',s.trust_tier,
 'url',coalesce(o.source_page_url,o.official_url,s.source_url),'source_status',s.status,
 'evidence_level','LEGACY_EXCERPT') src
 from public.commercial_offers o join public.commercial_offer_sources s on s.id=o.source_id where o.status='ACTIVE'
 union all
 select 'CANDIDATE',c.id,2,c.last_seen_at,
 left(coalesce(nullif(c.structured_payload->'evidence'->>'raw_offer_excerpt',''),concat_ws(E'\n',c.structured_payload->>'title',c.structured_payload->>'summary',c.structured_payload->'evidence'->>'normalized_excerpt',c.excerpt)),5000),
 jsonb_build_object('operator',coalesce(nullif(regexp_replace(split_part(split_part(s.source_url,'://',2),'/',1),'^www[.]',''),''),nullif(s.operator_name,''),s.source_name),
 'canonical_brand',coalesce(s.canonical_brand_code,'*'),'role',s.source_role,'policy',s.publication_policy,'trust',s.trust_tier,
 'url',coalesce(c.source_page_url,s.source_url),'source_status',s.status,
 'evidence_level','LEGACY_EXCERPT')
 from public.commercial_offer_candidates c join public.commercial_offer_sources s on s.id=c.source_id
 where c.status='PENDING_REVIEW' and s.source_role in ('OFFER_HUB','OFFER_DETAIL') and s.status='ACTIVE'
 ), hashed as (
 select i.*,md5(i.txt||i.src::text) h from inputs i where length(i.txt)>=25
 )
 insert into public.promo_v7_shadow_jobs(origin_type,origin_id,input_hash,engine,model,input_text,source)
 select h.origin_type,h.origin_id,h.h,p_engine,p_model,h.txt,h.src from hashed h
 where not exists(select 1 from public.promo_v7_shadow_jobs j where j.origin_type=h.origin_type and j.origin_id=h.origin_id and j.input_hash=h.h and j.engine=p_engine and j.model=p_model)
 order by h.priority,h.observed desc nulls last,h.origin_id limit 1
 on conflict do nothing returning * into row;
 if found then return query select row.id,row.input_text,row.source;end if;
end $body$;
revoke all on function public.promo_v7_claim_shadow(text,text) from public,anon,authenticated;
grant execute on function public.promo_v7_claim_shadow(text,text) to service_role;
create or replace function public.promo_v7_finish_shadow(p_job uuid,p_results jsonb,p_usage jsonb,p_error text)
returns void language plpgsql security invoker set search_path='' as $body$
begin
 if jsonb_typeof(p_results)<>'array' or jsonb_array_length(p_results)>6 then raise exception 'INVALID_RESULT';end if;
 update public.promo_v7_shadow_jobs j set status=case when p_error is null then 'DONE' else 'FAILED' end,
 results=p_results,usage=p_usage,error_code=left(p_error,100),finished_at=now()
 where j.id=p_job and j.status='RUNNING';
 if not found then raise exception 'CLAIM_NOT_RUNNING';end if;
end $body$;
revoke all on function public.promo_v7_finish_shadow(uuid,jsonb,jsonb,text) from public,anon,authenticated;
grant execute on function public.promo_v7_finish_shadow(uuid,jsonb,jsonb,text) to service_role;
-- Only raw-card results currently verified and not expired. No access for app users.
-- Identity grouping is deliberately conservative: different scope, eligibility or
-- prices are never collapsed. A human must review near-duplicate groups.
create or replace view public.promo_v7_catalog_preview with (security_invoker=true) as
with candidates as (
 select j.id job_id,j.origin_id,j.finished_at,j.source,j.model,j.engine,r.last_seen_at,v.item
 from public.promo_v7_shadow_jobs j
 join public.promo_v7_raw_cards r on j.origin_type='RAW_CARD' and r.id=j.origin_id
 join public.commercial_offer_sources s on s.id=r.source_id
 cross join lateral jsonb_array_elements(j.results) v(item)
 where j.status='DONE' and v.item->>'state'='READY'
 and nullif(v.item->>'identity','') is not null
 and r.last_seen_at>=now()-interval '7 days' and j.finished_at>=now()-interval '7 days'
 and s.status='ACTIVE' and s.source_role in ('OFFER_HUB','OFFER_DETAIL') and s.publication_policy='AUTO_HIGH_CONFIDENCE'
 and v.item->'offer'->>'ends_at'>=current_date::text
 and coalesce(v.item->'offer'->>'starts_at','0001-01-01')<=current_date::text
 and not exists(select 1 from public.promo_v7_shadow_jobs newer
 where newer.origin_type=j.origin_type and newer.origin_id=j.origin_id and newer.created_at>j.created_at)
)
select distinct on (item->>'identity') item->>'identity' as identity,item->'offer' as offer,
 source,engine,model,job_id,origin_id,last_seen_at,finished_at
from candidates order by item->>'identity',last_seen_at desc,finished_at desc,job_id;
revoke all on public.promo_v7_catalog_preview from public,anon,authenticated;
grant select on public.promo_v7_catalog_preview to service_role;
commit;
