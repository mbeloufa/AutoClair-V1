\set ON_ERROR_STOP on
-- This file follows promo_v7_shadow_test.sql in an ephemeral PostgreSQL DB.
create table public.vehicles(id uuid primary key,user_id uuid not null references auth.users(id),make text,model text,nickname text,vehicle_year smallint,fuel_type text,mileage int);
create function public.normalize_offer_fuel_v6(p_value text) returns text language sql immutable as $fn$
 select case lower(coalesce(p_value,'')) when 'essence' then 'petrol' when 'électrique' then 'electric' else lower(coalesce(p_value,'')) end
$fn$;
\ir ../../supabase/promo-v7/freshness.sql
\ir ../../supabase/promo-v7/release.sql
insert into public.vehicles values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','Renault','Zoe','Test Zoe',2022,'electric',35000),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','Renault','Clio','Test Clio',2022,'diesel',50000);
do $test$
begin
 if has_function_privilege('anon','public.promo_v7_vehicle(uuid,integer)','EXECUTE') then raise exception 'Anonymous vehicle lookup';end if;
 if has_table_privilege('authenticated','public.promo_v7_preferences','SELECT') then raise exception 'Preferences direct access';end if;
 if has_function_privilege('authenticated','public.promo_v7_set_enabled(boolean)','EXECUTE') then raise exception 'Release toggle exposed';end if;
 begin
  perform public.promo_v7_set_enabled(true);
  raise exception 'Release gate not enforced';
 exception when others then
  if sqlerrm<>'PROMO_V7_RELEASE_NOT_READY' then raise;end if;
 end;
end $test$;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
set role authenticated;
do $test$
begin
 if public.promo_v7_vehicle('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',120) is not null then raise exception 'Disabled V7 not null';end if;
 begin
  perform public.promo_v7_vehicle('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',120);
  raise exception 'Other account access allowed';
 exception when others then
  if sqlerrm<>'COMMERCIAL_OFFERS_VEHICLE_NOT_FOUND' then raise;end if;
 end;
end $test$;
reset role;
-- Deterministic fixture: actual worker output is separately validated by Deno.
insert into public.promo_v7_raw_cards(source_id,page_url,content_hash,raw_text)
values('11111111-1111-4111-8111-111111111111','https://www.ad.fr/promo-ev','fixture-release','Entretien électrique 89 € jusqu''au 31 décembre 2099');
insert into public.promo_v7_shadow_jobs(origin_type,origin_id,input_hash,engine,model,input_text,source,status,results,finished_at)
select 'RAW_CARD',r.id,'release','promo-v7.2','test-model',r.raw_text,
 '{"operator":"ad.fr","canonical_brand":"*","url":"https://www.ad.fr/promo-ev"}',
 'DONE',jsonb_build_array(jsonb_build_object('state','READY','identity','fixture-ev',
 'offer',jsonb_build_object('title','Entretien électrique','subject','entretien','category','MAINTENANCE','context','CURRENT_VEHICLE','kind','PRICE','benefit_quote','89 €','amount',89,
 'models','[]'::jsonb,'excluded_models','[]'::jsonb,'fuel_types','["electric"]'::jsonb,'geographic_scope','NATIONAL','ends_at','2099-12-31','conditions_quote','Centres participants','eligibility_uncertain',true))),now()
from public.promo_v7_raw_cards r where r.content_hash='fixture-release';
-- Explicit test-only bypass of minimum catalog thresholds to exercise the API.
update public.promo_v7_release_settings set approved_model='test-model',enabled=true;
do $test$
declare j jsonb; o jsonb; src jsonb;
begin
 select offer,source into o,src from public.promo_v7_release_catalog where identity='fixture-ev';
 if o is null then raise exception 'Release fixture missing';end if;
 if public.promo_v7_match(o,src,'Renault','Clio',2022,'diesel')<>'NO' then raise exception 'Diesel accepted electric offer';end if;
 if public.promo_v7_match(o,src,'Renault','Zoe',2022,null)<>'CHECK' then raise exception 'Unknown fuel treated as compatible';end if;
 if public.promo_v7_match(o,src,'Renault','Zoe',2022,'electric')<>'LIKELY' then raise exception 'Electric offer missing';end if;
end $test$;
set role authenticated;
do $test$
declare j jsonb; oid uuid;
begin
 j:=public.promo_v7_vehicle('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',120);
 if j->>'engine'<>'promo-v7' or jsonb_array_length(j->'offers')<>1 then raise exception 'V7 vehicle bundle invalid %',j;end if;
 if j->'offers'->0->>'benefit_label'<>'89 €' then raise exception 'Benefit proof lost';end if;
 oid:=(j->'offers'->0->>'id')::uuid;
 perform public.promo_v7_preference('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',oid,'SAVED');
 j:=public.promo_v7_vehicle('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',120);
 if j->'offers'->0->>'is_saved'<>'true' then raise exception 'Save not persisted';end if;
 perform public.promo_v7_preference('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',oid,'DISMISSED');
 if jsonb_array_length(public.promo_v7_vehicle('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',120)->'offers')<>0 then raise exception 'Dismiss not persisted';end if;
 perform public.promo_v7_preference('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',null,'RESET');
 if jsonb_array_length(public.promo_v7_vehicle('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',120)->'offers')<>1 then raise exception 'Reset not persisted';end if;
end $test$;
reset role;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
set role authenticated;
do $test$
begin
 if jsonb_array_length(public.promo_v7_vehicle('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',120)->'offers')<>0 then raise exception 'Electric offer leaked to diesel';end if;
end $test$;
reset role;
select public.promo_v7_set_enabled(false);

-- Revalidation must be based on the current card, even if AI analyzed it weeks ago.
update public.promo_v7_shadow_jobs set finished_at=now()-interval '20 days'
where input_hash='release';
do $test$
begin
 if not exists(select 1 from public.promo_v7_release_catalog where identity='fixture-ev') then raise exception 'Fresh proof lost due to old analysis';end if;
 perform public.promo_v7_ingest_cards('11111111-1111-4111-8111-111111111111','https://www.ad.fr/promo-ev','[{"text":"Autre offre entretien 120 euros du 1 au 31 décembre."}]'::jsonb);
 if exists(select 1 from public.promo_v7_release_catalog where identity='fixture-ev') then raise exception 'Disappeared campaign still public';end if;
end $test$;

\ir ../../supabase/promo-v7/operations.sql
-- Time-shift the prior synthetic jobs so the new raw-only queue can be exercised.
update public.promo_v7_shadow_jobs set created_at=now()-interval '25 hours' where created_at>now()-interval '24 hours';
set role service_role;
do $test$
declare j record; first_id uuid;
begin
 select * into j from public.promo_v7_claim_shadow('promo-v7.2','retry-test');
 if j.job_id is null or j.source->>'evidence_level'<>'RAW_CARD' then raise exception 'No raw queue';end if;
 first_id:=j.job_id;
 perform public.promo_v7_finish_shadow(first_id,'[]'::jsonb,null,'AI_HTTP_429');
 -- Other cards may be processed, but never the same failed card before cooldown.
 if exists(select 1 from public.promo_v7_shadow_jobs where origin_id=(select origin_id from public.promo_v7_shadow_jobs where id=first_id) and model='retry-test' and attempt_no>1) then raise exception 'Unexpected immediate retry';end if;
 update public.promo_v7_shadow_jobs set finished_at=now()-interval '7 hours' where id=first_id;
 -- Worker prioritizes fresh cards before retries; check retry using a separate input after exhausting fresh items.
 perform public.promo_v7_claim_shadow('promo-v7.2','retry-test');
 if (select analysis_enabled from public.promo_v7_release_settings where singleton) then raise exception 'Paid automation enabled by default';end if;
end $test$;
reset role;
