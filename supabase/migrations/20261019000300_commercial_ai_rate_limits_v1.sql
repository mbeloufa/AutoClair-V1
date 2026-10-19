-- Metering and abuse protection for costly non-document, non-Bilan APIs.
-- All spending decisions occur in SQL with service-role RPC.
-- Master switch public.commercial_settings.other_credits_enabled defaults false.
create table if not exists public.commercial_ai_daily_limits (
 feature text primary key,
 free_per_day int not null check (free_per_day between 0 and 100),
 premium_per_day int not null check (premium_per_day between 0 and 1000),
 per_feature_global_per_day int not null check (per_feature_global_per_day between 1 and 100000),
 enabled boolean not null default false
);
insert into public.commercial_ai_daily_limits
 (feature,free_per_day,premium_per_day,per_feature_global_per_day,enabled)
values
 ('tire_ai',2,10,200,true),
 ('tire_photo',5,20,300,true),
 ('tire_offers',2,8,200,true),
 ('legal',2,10,150,true),
 ('smart_trip',2,10,250,true),
 ('smart_trip_autocomplete',40,120,500,true),
 ('emergency',3,15,300,true),
 ('maintenance',2,8,200,true),
 ('identification',3,12,300,true),
 ('valuation',2,8,150,true)
on conflict (feature) do nothing;

create table if not exists public.commercial_ai_rate_events (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 feature text not null references public.commercial_ai_daily_limits(feature),
 operation_key text not null check (length(operation_key) between 16 and 120),
 utc_day date not null default (now() at time zone 'UTC')::date,
 created_at timestamptz not null default now(),
 unique(user_id,feature,operation_key)
);
create index if not exists commercial_ai_rate_daily_index
 on public.commercial_ai_rate_events(utc_day,feature,user_id);

alter table public.commercial_ai_daily_limits enable row level security;
alter table public.commercial_ai_rate_events enable row level security;
revoke all on public.commercial_ai_daily_limits from public,anon,authenticated;
revoke all on public.commercial_ai_rate_events from public,anon,authenticated;
grant select on public.commercial_ai_daily_limits to authenticated;
grant select on public.commercial_ai_rate_events to authenticated;
grant all on public.commercial_ai_daily_limits,public.commercial_ai_rate_events to service_role;
create policy commercial_ai_limits_read on public.commercial_ai_daily_limits
 for select to authenticated using (true);
create policy commercial_ai_rate_own on public.commercial_ai_rate_events
 for select to authenticated using ((select auth.uid())=user_id);

create or replace function private.commercial_try_feature(
 p_user_id uuid,p_feature text,p_operation_key text
) returns jsonb language plpgsql security definer set search_path=''
as $fn$
declare v_policy public.commercial_ai_daily_limits%rowtype;
        v_premium boolean;
        v_day date := (now() at time zone 'UTC')::date;
        v_user_count integer;
        v_global_count integer;
        v_daily_count integer;
        v_cap integer;
        v_enabled boolean;
begin
 select other_credits_enabled into v_enabled
 from public.commercial_settings where singleton=true;
 if not found then raise exception 'COMMERCIAL_SETTINGS_UNAVAILABLE'; end if;
 if not v_enabled then
   return jsonb_build_object('allowed',true,'mode','legacy');
 end if;
 if p_user_id is null or length(coalesce(p_operation_key,''))<16 then
   raise exception 'COMMERCIAL_REQUEST_INVALID';
 end if;
 select * into v_policy from public.commercial_ai_daily_limits
 where feature=p_feature and enabled=true;
 if not found then
   return jsonb_build_object('allowed',false,'reason','FEATURE_NOT_CONFIGURED');
 end if;
 -- One global daily lock covers the whole fleet, regardless of accounts.
 perform pg_advisory_xact_lock(hashtextextended(
   'commercial-ai-global:'||v_day::text,0));
 if exists (
   select 1 from public.commercial_ai_rate_events
   where user_id=p_user_id and feature=p_feature
     and operation_key=p_operation_key
 ) then
   return jsonb_build_object('allowed',true,'mode','duplicate');
 end if;

 select exists (
   select 1 from public.user_entitlements e
   where e.user_id=p_user_id and e.entitlement_code='vehicle_360'
     and e.status='active' and e.starts_at<=now()
     and (e.expires_at is null or e.expires_at>now())
 ) into v_premium;
 v_cap:=case when v_premium then v_policy.premium_per_day
             else v_policy.free_per_day end;
 select count(*) into v_user_count
 from public.commercial_ai_rate_events
 where user_id=p_user_id and feature=p_feature and utc_day=v_day;
 select count(*) into v_global_count
 from public.commercial_ai_rate_events
 where feature=p_feature and utc_day=v_day;
 select count(*) into v_daily_count
 from public.commercial_ai_rate_events where utc_day=v_day;
 if v_user_count>=v_cap
    or v_global_count>=v_policy.per_feature_global_per_day
    or v_daily_count>=500 then
   return jsonb_build_object(
     'allowed',false,'reason','COMMERCIAL_DAILY_LIMIT',
     'feature',p_feature,'limit',v_cap
   );
 end if;
 insert into public.commercial_ai_rate_events
  (user_id,feature,operation_key,utc_day)
 values(p_user_id,p_feature,p_operation_key,v_day);
 return jsonb_build_object(
   'allowed',true,'mode','metered',
   'remaining',greatest(0,v_cap-v_user_count-1)
 );
end;
$fn$;
revoke all on function private.commercial_try_feature(uuid,text,text)
 from public,anon,authenticated;
grant execute on function private.commercial_try_feature(uuid,text,text)
 to service_role;

create or replace function public.commercial_try_feature(
 p_user_id uuid,p_feature text,p_operation_key text
) returns jsonb language sql security invoker set search_path=''
as $fn$
 select private.commercial_try_feature(p_user_id,p_feature,p_operation_key);
$fn$;
revoke all on function public.commercial_try_feature(uuid,text,text)
 from public,anon,authenticated;
grant execute on function public.commercial_try_feature(uuid,text,text)
 to service_role;

-- Keep the ledger compact while preserving recent auditability.
create or replace function public.commercial_cleanup_old_ai_limits()
returns integer language plpgsql security definer set search_path=''
as $fn$
declare v_count integer;
begin
 delete from public.commercial_ai_rate_events
 where utc_day < ((now() at time zone 'UTC')::date-120);
 get diagnostics v_count=row_count;
 return v_count;
end;
$fn$;
revoke all on function public.commercial_cleanup_old_ai_limits()
 from public,anon,authenticated;
grant execute on function public.commercial_cleanup_old_ai_limits()
 to service_role;
