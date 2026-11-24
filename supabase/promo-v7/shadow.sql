-- Promo V7 shadow installation ONLY. No writes to legacy commercial_offers.
-- Apply after staging approval. No automatic schedule is created.
begin;
create table if not exists public.promo_v7_shadow_jobs(
 id uuid primary key default gen_random_uuid(),
 origin_type text not null check(origin_type in ('ACTIVE_OFFER','CANDIDATE')),
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
create index if not exists promo_v7_shadow_created on public.promo_v7_shadow_jobs(created_at);
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
 select 'ACTIVE_OFFER'::text as origin_type,o.id origin_id,0 priority,o.last_verified_at as observed,
 left(coalesce(nullif(o.evidence->>'raw_offer_excerpt',''),concat_ws(E'\n',o.title,o.summary,o.evidence->>'normalized_excerpt',o.conditions_summary)),5000) txt,
 jsonb_build_object('operator',coalesce(nullif(regexp_replace(split_part(split_part(s.source_url,'://',2),'/',1),'^www[.]',''),''),nullif(s.operator_name,''),s.source_name),
 'canonical_brand',coalesce(s.canonical_brand_code,'*'),'role',s.source_role,'policy',s.publication_policy,'trust',s.trust_tier,
 'url',coalesce(o.source_page_url,o.official_url,s.source_url),'source_status',s.status,
 'evidence_level',case when nullif(o.evidence->>'raw_offer_excerpt','') is not null then 'RAW_CARD' else 'LEGACY_EXCERPT' end) src
 from public.commercial_offers o join public.commercial_offer_sources s on s.id=o.source_id where o.status='ACTIVE'
 union all
 select 'CANDIDATE',c.id,1,c.last_seen_at,
 left(coalesce(nullif(c.structured_payload->'evidence'->>'raw_offer_excerpt',''),concat_ws(E'\n',c.structured_payload->>'title',c.structured_payload->>'summary',c.structured_payload->'evidence'->>'normalized_excerpt',c.excerpt)),5000),
 jsonb_build_object('operator',coalesce(nullif(regexp_replace(split_part(split_part(s.source_url,'://',2),'/',1),'^www[.]',''),''),nullif(s.operator_name,''),s.source_name),
 'canonical_brand',coalesce(s.canonical_brand_code,'*'),'role',s.source_role,'policy',s.publication_policy,'trust',s.trust_tier,
 'url',coalesce(c.source_page_url,s.source_url),'source_status',s.status,
 'evidence_level',case when nullif(c.structured_payload->'evidence'->>'raw_offer_excerpt','') is not null then 'RAW_CARD' else 'LEGACY_EXCERPT' end)
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
commit;
