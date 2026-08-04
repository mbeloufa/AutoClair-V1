begin;

do $precheck$
begin
  if to_regclass('public.commercial_offer_crawl_targets') is null then
    raise exception 'GENERIC_COMMERCIAL_OFFERS_POST_DEPLOY_MISSING:crawl_targets';
  end if;

  if to_regprocedure(
    'public.dispatch_commercial_offer_sync(text,integer)'
  ) is null then
    raise exception 'GENERIC_COMMERCIAL_OFFERS_POST_DEPLOY_MISSING:dispatcher';
  end if;

  if to_regprocedure(
    'public.bootstrap_commercial_offer_sync_v3()'
  ) is null then
    raise exception 'GENERIC_COMMERCIAL_OFFERS_POST_DEPLOY_MISSING:bootstrap';
  end if;
end
$precheck$;

do $remove_old_jobs$
begin
  if exists (
    select 1
    from cron.job
    where jobname = 'autoclair-sync-commercial-offers'
  ) then
    perform cron.unschedule('autoclair-sync-commercial-offers');
  end if;

  if exists (
    select 1
    from cron.job
    where jobname = 'autoclair-bootstrap-commercial-offers-v3'
  ) then
    perform cron.unschedule(
      'autoclair-bootstrap-commercial-offers-v3'
    );
  end if;
end
$remove_old_jobs$;

-- Toutes les sources activées repartent immédiatement dans la file. Les
-- sources bloquées par robots.txt restent bloquées et ne sont pas réactivées.
update public.commercial_offer_crawl_targets t
set
  status = case
    when t.status = 'BLOCKED' then 'BLOCKED'
    else 'ACTIVE'
  end,
  next_check_at = case
    when t.status = 'BLOCKED' then t.next_check_at
    else now()
  end,
  updated_at = now()
from public.commercial_offer_sources s
where s.id = t.source_id
  and s.search_enabled = true;

-- File de démarrage : quatre pages toutes les cinq minutes jusqu'à ce que les
-- cibles arrivées à échéance soient épuisées. La fonction se désinscrit alors
-- elle-même ; elle ne crée donc pas une charge permanente inutile.
select cron.schedule(
  'autoclair-bootstrap-commercial-offers-v3',
  '*/5 * * * *',
  $cron$
  select public.bootstrap_commercial_offer_sync_v3();
  $cron$
);

-- Entretien courant : petit lot horaire idempotent. Chaque cible conserve sa
-- propre fréquence (24 à 72 h selon la famille de source).
select cron.schedule(
  'autoclair-sync-commercial-offers',
  '7 * * * *',
  $cron$
  select public.dispatch_commercial_offer_sync(
    'scheduled-v3',
    4
  );
  $cron$
);

-- Premier lot lancé après déploiement de la fonction V3.
select public.dispatch_commercial_offer_sync(
  'installation-v3',
  4
);

commit;
