-- AutoClair V1 — tickets 29/30 : demandes d'assistance et signalements IA.
create table if not exists public.app_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  source text not null check (source in (
    'vehicle360','document','tire','trip','legal','emergency','app','other'
  )),
  source_reference text not null default '' check (length(source_reference)<=120),
  category text not null check (category in (
    'incorrect','inappropriate','dangerous','support'
  )),
  description text not null check (
    length(trim(description)) between 5 and 2000
  ),
  status text not null default 'new'
    check(status in ('new','triage','in_progress','resolved','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists app_feedback_status_idx on public.app_feedback(status,created_at);
create index if not exists app_feedback_user_idx on public.app_feedback(user_id,created_at desc);
alter table public.app_feedback enable row level security;
revoke all on public.app_feedback from public,anon,authenticated;
grant select,insert on public.app_feedback to authenticated;
grant all on public.app_feedback to service_role;
create policy app_feedback_read_own on public.app_feedback
 for select to authenticated using ((select auth.uid())=user_id);
create policy app_feedback_insert_own on public.app_feedback
 for insert to authenticated with check (
   (select auth.uid())=user_id and status='new'
 );
comment on table public.app_feedback is
 'Signalement sans envoi automatique de documents, photos, transcription ou analyse complète. Triage support obligatoire.';
