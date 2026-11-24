-- Operational queue: retain every failed attempt for budget and audit.
begin;
alter table public.promo_v7_shadow_jobs add column if not exists attempt_no integer not null default 1;
alter table public.promo_v7_shadow_jobs drop constraint if exists promo_v7_shadow_jobs_origin_type_origin_id_input_hash_engin_key;
create unique index if not exists promo_v7_attempt_identity on public.promo_v7_shadow_jobs(origin_type,origin_id,input_hash,engine,model,attempt_no);
alter table public.promo_v7_release_settings add column if not exists analysis_enabled boolean not null default false;
create or replace function public.promo_v7_claim_shadow(p_engine text,p_model text)
returns table(job_id uuid,input_text text,source jsonb)
language plpgsql security invoker set search_path='' as $fn$
declare row public.promo_v7_shadow_jobs%rowtype;
begin
 if nullif(trim(p_engine),'') is null or nullif(trim(p_model),'') is null or length(p_engine)>80 or length(p_model)>100 then raise exception 'INVALID_ENGINE';end if;
 perform pg_advisory_xact_lock(hashtext('promo_v7_shadow_global'));
 update public.promo_v7_shadow_jobs j set status='FAILED',error_code='CLAIM_TIMEOUT',finished_at=now()
 where j.status='RUNNING' and j.created_at<now()-interval '10 minutes';
 if exists(select 1 from public.promo_v7_shadow_jobs j where j.status='RUNNING') then return;end if;
 if (select count(*) from public.promo_v7_shadow_jobs j where j.created_at>=now()-interval '24 hours')>=24 then return;end if;
 -- Only original, recent, available cards; never spend paid calls on legacy summaries.
 with inputs as (
 select r.id origin_id,r.last_seen_at observed,r.raw_text txt,
 jsonb_build_object('operator',coalesce(nullif(regexp_replace(split_part(split_part(s.source_url,'://',2),'/',1),'^www[.]',''),''),s.operator_name,s.source_name),
 'canonical_brand',coalesce(s.canonical_brand_code,'*'),'role',s.source_role,'policy',s.publication_policy,'trust',s.trust_tier,
 'url',r.page_url,'source_status',s.status,'evidence_level','RAW_CARD') src
 from public.promo_v7_raw_cards r join public.commercial_offer_sources s on s.id=r.source_id
 where r.available and r.last_seen_at>=now()-interval '72 hours' and s.status='ACTIVE'
 and s.source_role in ('OFFER_HUB','OFFER_DETAIL') and s.publication_policy='AUTO_HIGH_CONFIDENCE'
 and s.trust_tier in ('PRIMARY','PROFESSIONAL')
 ), hashed as (
 select i.*,md5(i.txt||i.src::text) h from inputs i
 ), eligible as(
 select h.*,coalesce(a.last_attempt,0)+1 attempt
 from hashed h
 left join lateral(select max(j.attempt_no) last_attempt,
 bool_or(j.status='DONE') completed,max(j.finished_at) last_finished
 from public.promo_v7_shadow_jobs j where j.origin_type='RAW_CARD' and j.origin_id=h.origin_id and j.input_hash=h.h and j.engine=p_engine and j.model=p_model)a on true
 where not coalesce(a.completed,false) and coalesce(a.last_attempt,0)<3
 and (a.last_finished is null or a.last_finished<now()-interval '6 hours')
 )
 insert into public.promo_v7_shadow_jobs(origin_type,origin_id,input_hash,engine,model,input_text,source,attempt_no)
 select 'RAW_CARD',e.origin_id,e.h,p_engine,p_model,e.txt,e.src,e.attempt
 from eligible e order by e.attempt,e.observed desc,e.origin_id limit 1
 on conflict do nothing returning * into row;
 if found then return query select row.id,row.input_text,row.source;end if;
end $fn$;
revoke all on function public.promo_v7_claim_shadow(text,text) from public,anon,authenticated;
grant execute on function public.promo_v7_claim_shadow(text,text) to service_role;
-- Internal administrative status. This does not trigger a paid call.
create or replace function public.promo_v7_operations_health()
returns jsonb language sql stable security invoker set search_path='' as $fn$
 select jsonb_build_object('release',public.promo_v7_release_health(),
 'analysis_enabled',(select analysis_enabled from public.promo_v7_release_settings where singleton),
 'raw_cards',(select count(*) from public.promo_v7_raw_cards where available and last_seen_at>=now()-interval '72 hours'),
 'raw_sources',(select count(distinct source_id) from public.promo_v7_raw_cards where available and last_seen_at>=now()-interval '72 hours'),
 'attempts_24h',(select count(*) from public.promo_v7_shadow_jobs where created_at>=now()-interval '24 hours'),
 'last_error',(select error_code from public.promo_v7_shadow_jobs where status='FAILED' order by created_at desc limit 1),
 'latest_analysis',(select max(finished_at) from public.promo_v7_shadow_jobs where status='DONE'),
 'ready_preview',(select count(*) from public.promo_v7_catalog_preview))
$fn$;
revoke all on function public.promo_v7_operations_health() from public,anon,authenticated;
grant execute on function public.promo_v7_operations_health() to service_role;
commit;
