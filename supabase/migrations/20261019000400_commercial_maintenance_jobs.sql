-- Back-office reconciliation. pg_cron is available in hosted Supabase.
-- This migration is also safe in a plain PostgreSQL CI test without pg_cron.
-- Calls run as the migration/owner role; API clients cannot invoke these RPCs.
do $jobs$
begin
  if exists(select 1 from pg_extension where extname='pg_cron') then
    perform cron.schedule(
      'autoclair-commercial-reservations-v1',
      '*/10 * * * *',
      'select public.commercial_release_expired();'
    );
    perform cron.schedule(
      'autoclair-commercial-rate-cleanup-v1',
      '11 3 * * *',
      'select public.commercial_cleanup_old_ai_limits();'
    );
  end if;
end;
$jobs$;

comment on function public.commercial_release_expired() is
 'Reconcile expired reservations with durable results before releasing any credit.';
