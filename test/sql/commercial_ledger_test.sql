\set ON_ERROR_STOP on
do $security$
begin
 if has_function_privilege('anon','public.get_vehicle_report_access()','EXECUTE') then
   raise exception 'Legacy user RPC remains anonymously executable';
 end if;
 if not has_function_privilege('authenticated','public.get_vehicle_report_access()','EXECUTE') then
   raise exception 'Client access unexpectedly broken';
 end if;
 if has_function_privilege('anon','public.maintain_commercial_offers_v6()','EXECUTE')
    or has_function_privilege('authenticated','public.maintain_commercial_offers_v6()','EXECUTE') then
   raise exception 'Privileged commercial maintenance reachable by app users';
 end if;
 if not has_function_privilege('service_role','public.maintain_commercial_offers_v6()','EXECUTE') then
   raise exception 'Backend maintenance permissions removed';
 end if;
end $security$;
-- Test environment, not production. Exercise the actual same SQL functions.
update public.commercial_products
set active=true,quantity=3,price_ttc_cents=490,
    store_product_id='autoclair.qa.document3'
where code='analysis_small';

do $test$
declare
  u1 uuid := '11111111-1111-4111-8111-111111111111';
  u2 uuid := '22222222-2222-4222-8222-222222222222';
  got jsonb;
  n int;
begin
  got := public.commercial_grant_verified_purchase(
    u1,'play_store','GPA.qa.000001','analysis_small','PRODUCTION');
  if got->>'ok' <> 'true' then raise exception 'purchase not granted';end if;

  -- Repeated webhook delivery must not double allocate credits.
  perform public.commercial_grant_verified_purchase(
    u1,'play_store','GPA.qa.000001','analysis_small','PRODUCTION');
  select count(*) into n from public.commercial_credit_lots
   where user_id=u1 and source='purchase';
  if n<>1 then raise exception 'duplicate credit lot %',n;end if;

  got:=public.commercial_reserve_credit(u1,'document','request-document-one');
  if got->>'status'<>'reserved' then raise exception 'reservation failed %',got;end if;
  got:=public.commercial_reserve_credit(u1,'document','request-document-one');
  if got->>'status'<>'reserved' then raise exception 'idempotency failed %',got;end if;
  select units_reserved into n from public.commercial_credit_lots
    where user_id=u1 and source='purchase';
  if n<>1 then raise exception 'double reservation %',n;end if;

  got:=public.commercial_finish_credit(u1,'document','request-document-one',true);
  if got->>'status'<>'consumed' then raise exception 'finish failed %',got;end if;
  got:=public.commercial_finish_credit(u1,'document','request-document-one',true);
  select units_used into n from public.commercial_credit_lots
    where user_id=u1 and source='purchase';
  if n<>1 then raise exception 'double consumption %',n;end if;

  got:=public.commercial_reserve_credit(u1,'document','request-document-two');
  if got->>'status'<>'reserved' then raise exception 'second reservation failed';end if;
  perform public.commercial_finish_credit(u1,'document','request-document-two',false);
  select units_used into n from public.commercial_credit_lots
    where user_id=u1 and source='purchase';
  if n<>1 then raise exception 'failed job debited credit';end if;

  -- Fresh account: ONE free documentary trial, no second trial.
  got:=public.commercial_reserve_credit(u2,'document','request-free-trial1');
  if got->>'status'<>'reserved' then raise exception 'trial not created %',got;end if;
  perform public.commercial_finish_credit(u2,'document','request-free-trial1',true);
  got:=public.commercial_reserve_credit(u2,'document','request-free-trial2');
  if got->>'status'<>'insufficient' then raise exception 'double trial vulnerability %',got;end if;

  -- Refund event before grant: persistent tombstone blocks later purchases.
  perform public.commercial_revoke_purchase(
     u2,'analysis_small','play_store','GPA.qa.refund-first','PRODUCTION');
  begin
    perform public.commercial_grant_verified_purchase(
     u2,'play_store','GPA.qa.refund-first','analysis_small','PRODUCTION');
    raise exception 'REFUND_REGRANT_VULNERABILITY';
  exception when others then
    if sqlerrm='REFUND_REGRANT_VULNERABILITY' then raise; end if;
  end;

  -- Previously granted purchase is revoked without deleting its audit trail.
  perform public.commercial_revoke_purchase(
    u1,'analysis_small','play_store','GPA.qa.000001','PRODUCTION');
  select count(*) into n from public.commercial_credit_lots
    where user_id=u1 and source='purchase' and revoked_at is not null;
  if n<>1 then raise exception 'refund failed %',n;end if;
  got:=public.commercial_reserve_credit(u1,'document','request-after-refund');
  if got->>'status'<>'insufficient' then raise exception 'spent refunded credits %',got;end if;

  -- A receipt already owned by another user cannot be reassigned by refund.
  begin
    perform public.commercial_revoke_purchase(
      u2,'analysis_small','play_store','GPA.qa.000001','PRODUCTION');
    raise exception 'CROSS_ACCOUNT_REFUND_VULNERABILITY';
  exception when others then
    if sqlerrm='CROSS_ACCOUNT_REFUND_VULNERABILITY' then raise;end if;
  end;
end
$test$;

set role authenticated;
set request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
do $rls$
declare n int;
begin
  select count(*) into n from public.commercial_store_transactions;
  if n <> 1 then raise exception 'RLS transactions leak: %',n;end if;
  select count(*) into n from public.commercial_credit_lots;
  if n <> 1 then raise exception 'RLS credits leak: %',n;end if;
end
$rls$;
reset role;
select 'PASS: idempotency, credit lifecycle, trials, refund tombstones, RLS' as result;

-- Annual cycle, duplicate webhook and unique complimentary Bilan 360.
update public.commercial_products
 set active=true,store_product_id='autoclair.qa.annual'
 where code='premium_annual';
update public.commercial_subscription_allocations
 set enabled=true, units=2
 where product_code='premium_annual';
do $annual$
declare
 u1 uuid:='11111111-1111-4111-8111-111111111111';
 u2 uuid:='22222222-2222-4222-8222-222222222222';
 got jsonb;
 n integer;
begin
 got:=public.commercial_grant_subscription_cycle(u1,
   'autoclair.qa.annual','cycle-2026-2027',now()+interval '1 year');
 if (got->>'configured_allocations')::int<>2 then
   raise exception 'annual allocations misconfigured: %', got;
 end if;
 perform public.commercial_grant_subscription_cycle(u1,
   'autoclair.qa.annual','cycle-2026-2027',now()+interval '13 months');
 select count(*) into n from public.commercial_credit_lots
   where user_id=u1 and source='subscription';
 if n<>2 then raise exception 'annual allocated twice %',n;end if;
 select count(*) into n from public.commercial_credit_lots
 where user_id=u1 and source='subscription'
   and expires_at>now()+interval '12 months';
 if n<>2 then raise exception 'annual grace extension minted or lost units: %',n;end if;

 -- A user with a completed Bilan before launch must not requalify.
 insert into public.vehicle_analysis_reports(user_id,status)
  values(u1,'completed');
 perform set_config('request.jwt.claim.sub',u1::text,true);
 got:=public.claim_vehicle360_commercial_trial();
 if got->>'success'<>'false' then
   raise exception 'retroactive trial vulnerability: %',got;
 end if;
 perform set_config('request.jwt.claim.sub',u2::text,true);
 got:=public.claim_vehicle360_commercial_trial();
 if got->>'success'<>'true' then raise exception 'Bilan trial denied: %',got;end if;
 got:=public.claim_vehicle360_commercial_trial();
 select count(*) into n from public.commercial_credit_lots
  where user_id=u2 and source='trial' and kind='vehicle_360';
 if n<>1 then raise exception 'Bilan trial created twice: %',n;end if;

 -- A historical claim made through the OLD free credit ledger must NOT
 -- become an additional complimentary balance in the new architecture.
 perform set_config('request.jwt.claim.sub',
   '33333333-3333-4333-8333-333333333333',true);
 got:=public.claim_vehicle360_commercial_trial();
 if got->>'success'<>'false' then
   raise exception 'Legacy trial claim reissued under V1: %',got;
 end if;
 select count(*) into n from public.commercial_credit_lots
  where user_id='33333333-3333-4333-8333-333333333333'
    and source='trial' and kind='vehicle_360';
 if n<>0 then raise exception 'Legacy claimant received free double credit';end if;

 perform public.commercial_revoke_subscription(u1);
 select count(*) into n from public.commercial_credit_lots
 where user_id=u1 and source='subscription' and revoked_at is null;
 if n<>0 then raise exception 'cancelled subscription retains credits';end if;
end
$annual$;
select 'PASS: annual cycles, unique 360 discovery, revocation' as result;

update public.commercial_settings set other_credits_enabled=true where singleton=true;
do $rate$
declare
 u1 uuid:='11111111-1111-4111-8111-111111111111';
 u2 uuid:='22222222-2222-4222-8222-222222222222';
 got jsonb;
 n integer;
begin
 got:=public.commercial_try_feature(u1,'tire_ai','rate-request-000001');
 if got->>'allowed'<>'true' then raise exception 'first free AI action denied: %',got;end if;
 got:=public.commercial_try_feature(u1,'tire_ai','rate-request-000001');
 if got->>'mode'<>'duplicate' then raise exception 'request idempotency failed: %',got;end if;
 got:=public.commercial_try_feature(u1,'tire_ai','rate-request-000002');
 if got->>'allowed'<>'true' then raise exception 'second free AI action denied: %',got;end if;
 got:=public.commercial_try_feature(u1,'tire_ai','rate-request-000003');
 if got->>'allowed'<>'false' then raise exception 'daily limit bypass: %',got;end if;
 select count(*) into n from public.commercial_ai_rate_events
  where user_id=u1 and feature='tire_ai';
 if n<>2 then raise exception 'rate counter wrong: %',n;end if;
 got:=public.commercial_try_feature(u2,'tire_ai','rate-other-user001');
 if got->>'allowed'<>'true' then raise exception 'rate limits leaked between accounts';end if;
 got:=public.commercial_try_feature(u1,'not_configured','invalid-feature0001');
 if got->>'allowed'<>'false' then raise exception 'unknown service fail-open';end if;
end
$rate$;
select 'PASS: atomic daily AI rate budget and per-account isolation' as result;

do $annual_limits$
declare
 u1 uuid:='11111111-1111-4111-8111-111111111111';
 got jsonb;
begin
 -- Legal has a larger daily cap than free 365-day allowance.
 got:=public.commercial_try_feature(u1,'legal','free-legal-annual-01');
 if got->>'allowed'<>'true' then raise exception 'first annual credit declined';end if;
 got:=public.commercial_try_feature(u1,'legal','free-legal-annual-02');
 if got->>'allowed'<>'false' then raise exception 'annual budget bypass: %',got;end if;
end
$annual_limits$;
select 'PASS: 365-day cap beyond per-day limit' as result;
