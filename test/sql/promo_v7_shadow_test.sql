\set ON_ERROR_STOP on
-- Test doubles reproduce only columns read by the shadow job, never user data.
create table public.commercial_offer_sources(
 id uuid primary key,operator_name text,canonical_brand_code text,source_name text,source_url text,source_role text,publication_policy text,trust_tier text,status text
);
create table public.commercial_offers(
 id uuid primary key,source_id uuid references public.commercial_offer_sources(id),status text,last_verified_at timestamptz,title text,summary text,evidence jsonb,conditions_summary text,source_page_url text,official_url text
);
create table public.commercial_offer_candidates(
 id uuid primary key,source_id uuid references public.commercial_offer_sources(id),status text,last_seen_at timestamptz,structured_payload jsonb,excerpt text,source_page_url text
);
grant select on public.commercial_offer_sources,public.commercial_offers,public.commercial_offer_candidates to service_role;
\ir ../../supabase/promo-v7/shadow.sql
insert into public.commercial_offer_sources values('11111111-1111-4111-8111-111111111111','AD','*','AD Garage','https://www.ad.fr/','OFFER_HUB','AUTO_HIGH_CONFIDENCE','PROFESSIONAL','ACTIVE');
insert into public.commercial_offers values('22222222-2222-4222-8222-222222222222','11111111-1111-4111-8111-111111111111','ACTIVE',now(),'Vidange','Legacy extraction','{"raw_offer_excerpt":"Forfait vidange à partir de 92€90, centres participants."}',null,'https://www.ad.fr/promotion','https://www.ad.fr/promotion');
insert into public.commercial_offer_candidates values('33333333-3333-4333-8333-333333333333','11111111-1111-4111-8111-111111111111','PENDING_REVIEW',now(),'{"title":"Pneus","summary":"Quatre pneus, jusqu’à 80 euros de remise"}','Pneus, remise',null);
do $test$
begin
 if has_table_privilege('anon','public.promo_v7_shadow_jobs','SELECT') or has_table_privilege('authenticated','public.promo_v7_shadow_jobs','SELECT') then raise exception 'Shadow jobs exposed';end if;
 if has_function_privilege('anon','public.promo_v7_claim_shadow(text,text)','EXECUTE') or has_function_privilege('authenticated','public.promo_v7_claim_shadow(text,text)','EXECUTE') then raise exception 'Shadow AI exposed';end if;
end $test$;
set role service_role;
do $test$
declare j record; n integer; i integer;
begin
 perform public.promo_v7_ingest_cards('11111111-1111-4111-8111-111111111111','https://www.ad.fr/promotion','[{"text":"Forfait vidange à partir de 92€90, centres participants."}]'::jsonb);
 perform public.promo_v7_ingest_cards('11111111-1111-4111-8111-111111111111','https://www.ad.fr/promotion','[{"text":"Forfait vidange à partir de 92€90, centres participants."}]'::jsonb);
 if (select count(*) from public.promo_v7_raw_cards)<>1 then raise exception 'Raw capture duplicated';end if;
 select * into j from public.promo_v7_claim_shadow('v7','test-model');
 if j.job_id is null or j.source->>'evidence_level'<>'RAW_CARD' or j.source->>'operator'<>'ad.fr' then raise exception 'Active raw proof not prioritized: %',j;end if;
 if j.input_text not like '%92€90%' then raise exception 'Raw original lost';end if;
 if exists(select 1 from public.promo_v7_claim_shadow('v7','test-model')) then raise exception 'Parallel claim admitted';end if;
 perform public.promo_v7_finish_shadow(j.job_id,'[]'::jsonb,null,null);
 select * into j from public.promo_v7_claim_shadow('v7','test-model');
 if j.job_id is null or j.source->>'evidence_level'<>'LEGACY_EXCERPT' then raise exception 'Legacy candidate not flagged: %',j;end if;
 perform public.promo_v7_finish_shadow(j.job_id,'[]'::jsonb,null,'TEST_FAILURE');
 select * into j from public.promo_v7_claim_shadow('v7','test-model');
 if j.job_id is null or j.source->>'evidence_level'<>'LEGACY_EXCERPT' then raise exception 'Historical candidate missing';end if;
 perform public.promo_v7_finish_shadow(j.job_id,'[]'::jsonb,null,null);
 if exists(select 1 from public.promo_v7_claim_shadow('v7','test-model')) then raise exception 'Same input consumed twice';end if;
 -- Different model versions must still share the global daily budget.
 for i in 1..7 loop
  select * into j from public.promo_v7_claim_shadow('v7','model-'||i);
  if j.job_id is null then raise exception 'Unexpected budget exhaustion';end if;
  perform public.promo_v7_finish_shadow(j.job_id,'[]'::jsonb,null,null);
  select * into j from public.promo_v7_claim_shadow('v7','model-'||i);
  if j.job_id is null then raise exception 'Unexpected budget exhaustion';end if;
  perform public.promo_v7_finish_shadow(j.job_id,'[]'::jsonb,null,null);
  select * into j from public.promo_v7_claim_shadow('v7','model-'||i);
  if j.job_id is null then raise exception 'Unexpected budget exhaustion';end if;
  perform public.promo_v7_finish_shadow(j.job_id,'[]'::jsonb,null,null);
 end loop;
 if exists(select 1 from public.promo_v7_claim_shadow('v7','extra-model')) then raise exception 'Global 24-call budget bypass';end if;
 select count(*) into n from public.promo_v7_shadow_jobs;
 if n<>24 then raise exception 'Budget count %',n;end if;
 if (select count(*) from public.commercial_offers where status='ACTIVE')<>1 then raise exception 'Legacy catalogue modified';end if;
end $test$;
reset role;
