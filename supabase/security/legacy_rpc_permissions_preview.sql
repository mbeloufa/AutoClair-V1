-- AUTOCLAIR: SECURITY PREVIEW, NOT an automatically deployed migration.
-- Generated from Supabase security advisor on 19 October 2026.
-- Restricts 25 legacy public SECURITY DEFINER RPCs from being callable by anon.
-- Existing authenticated access is preserved, EXCEPT privileged maintenance
-- functions that should only be called by service_role or their owner.
-- Ship as a reviewed migration after staging/compatibility testing.
do $security$
declare item record;
begin
  for item in
    select p.oid::regprocedure as signature,p.proname
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosecdef and p.proname = any(array[
      'autoclair_user_owns_vehicle',
      'build_vehicle_analysis_snapshot',
      'capture_commercial_offer_evidence_v6',
      'commercial_offer_v4_status',
      'commercial_offer_v5_status',
      'commercial_offer_v6_status',
      'enqueue_commercial_offer_notifications_v5',
      'get_commercial_offer_notification_preferences_v5',
      'get_latest_vehicle_analysis_report',
      'get_pending_commercial_offer_notifications_v5',
      'get_vehicle_analysis_report',
      'get_vehicle_commercial_offers_v5',
      'get_vehicle_commercial_offers_v6',
      'get_vehicle_report_access',
      'get_vehicle_value_history',
      'maintain_commercial_offers_v5',
      'maintain_commercial_offers_v6',
      'mark_commercial_offer_notification_delivered_v5',
      'match_commercial_offers_v4',
      'match_commercial_offers_v5',
      'match_commercial_offers_v6',
      'search_vehicle_purchase_offers_v5',
      'search_vehicle_purchase_offers_v6',
      'set_commercial_offer_notification_preferences_v5',
      'set_vehicle_commercial_offer_preference_v5'
    ])
  loop
    execute format('revoke execute on function %s from public, anon',item.signature);
    -- These maintenance write jobs are owned by our backend, never by clients.
    if item.proname = any(array[
      'capture_commercial_offer_evidence_v6',
      'enqueue_commercial_offer_notifications_v5',
      'maintain_commercial_offers_v5',
      'maintain_commercial_offers_v6'
    ]) then
      execute format('revoke execute on function %s from authenticated',item.signature);
    else
      execute format('grant execute on function %s to authenticated',item.signature);
    end if;
    execute format('grant execute on function %s to service_role',item.signature);
  end loop;
end
$security$;
