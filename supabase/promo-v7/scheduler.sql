-- The job runs every 10 minutes but dispatches NOTHING while analysis_enabled=false.
-- Keep disabled until the AI quota has been resolved and the pilot approved.
begin;
create or replace function public.promo_v7_dispatch()
returns bigint language plpgsql security invoker set search_path='' as $fn$
declare request_id bigint;
begin
 if not coalesce((select analysis_enabled from public.promo_v7_release_settings where singleton),false) then return null;end if;
 if exists(select 1 from public.promo_v7_shadow_jobs where status='RUNNING' and created_at>=now()-interval '10 minutes') then return null;end if;
 if (select count(*) from public.promo_v7_shadow_jobs where created_at>=now()-interval '24 hours')>=24 then return null;end if;
 if exists(select 1 from public.promo_v7_shadow_jobs where error_code in ('AI_QUOTA_EXHAUSTED','AI_HTTP_429','AI_RATE_LIMIT','AI_AUTH_OR_ACCESS') and created_at>=now()-interval '6 hours') then return null;end if;
 select net.http_post(
 url:=(select decrypted_secret from vault.decrypted_secrets where name='autoclair_project_url' order by created_at desc limit 1)||'/functions/v1/promo-v7',
 headers:=jsonb_build_object('Content-Type','application/json','x-sync-secret',(select decrypted_secret from vault.decrypted_secrets where name='commercial_offers_sync_secret' order by created_at desc limit 1)),
 body:='{}'::jsonb,timeout_milliseconds:=45000) into request_id;
 return request_id;
end $fn$;
revoke all on function public.promo_v7_dispatch() from public,anon,authenticated,service_role;
-- Schedule by existing name so repeated installation is idempotent.
select cron.schedule('autoclair-promo-v7-analysis','*/10 * * * *','select public.promo_v7_dispatch()');
commit;
