-- AutoClair - Litiges & demarches V1
-- Dossiers automobiles structures, RLS stricte, aucune decision juridique automatisee en base.

create table if not exists public.legal_cases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id uuid null references public.vehicles(id) on delete set null,
  category text not null check (category in (
    'professional_purchase',
    'garage_repair',
    'warranty_refusal',
    'consumer_mediation',
    'other'
  )),
  counterparty_type text not null default 'unknown' check (counterparty_type in (
    'professional',
    'garage',
    'manufacturer',
    'warranty_provider',
    'private_individual',
    'other',
    'unknown'
  )),
  status text not null default 'draft' check (status in (
    'draft',
    'collecting',
    'ready',
    'needs_information',
    'analyzed',
    'dossier_only',
    'source_verification_failed',
    'escalation_required',
    'closed'
  )),
  issue_description text not null check (char_length(issue_description) between 1 and 5000),
  event_date date null,
  amount_eur numeric(12,2) null check (amount_eur is null or amount_eur >= 0),
  written_complaint boolean not null default false,
  bodily_injury boolean not null default false,
  court_started boolean not null default false,
  criminal_issue boolean not null default false,
  cross_border boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists legal_cases_user_created_idx
  on public.legal_cases(user_id, created_at desc);
create index if not exists legal_cases_vehicle_idx
  on public.legal_cases(user_id, vehicle_id, created_at desc);

create table if not exists public.legal_case_facts (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.legal_cases(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  fact_key text not null check (char_length(fact_key) between 1 and 120),
  label text not null check (char_length(label) between 1 and 240),
  value_text text not null check (char_length(value_text) between 1 and 4000),
  source_kind text not null check (source_kind in (
    'user_confirmed',
    'autoclair_vehicle',
    'autoclair_profile',
    'document_analysis',
    'autoclair_event'
  )),
  source_id uuid null,
  confirmed boolean not null default false,
  is_critical boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists legal_case_facts_case_idx
  on public.legal_case_facts(user_id, case_id, created_at);

create table if not exists public.legal_case_documents (
  case_id uuid not null references public.legal_cases(id) on delete cascade,
  document_id uuid not null references public.documents(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'supporting_document' check (role in (
    'purchase_document',
    'diagnostic',
    'invoice',
    'repair_order',
    'warranty',
    'written_exchange',
    'supporting_document'
  )),
  created_at timestamptz not null default now(),
  primary key (case_id, document_id)
);

create index if not exists legal_case_documents_user_idx
  on public.legal_case_documents(user_id, case_id);

create table if not exists public.legal_assessments (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.legal_cases(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in (
    'ready',
    'needs_information',
    'dossier_only',
    'source_verification_failed',
    'escalation_required'
  )),
  model text null,
  prompt_version text not null,
  rules_version text not null,
  result_json jsonb not null,
  official_sources_json jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists legal_assessments_case_idx
  on public.legal_assessments(user_id, case_id, created_at desc);

create or replace function public.autoclair_legal_touch_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke all on function public.autoclair_legal_touch_updated_at()
  from public, anon, authenticated;

drop trigger if exists legal_cases_touch_updated_at on public.legal_cases;
create trigger legal_cases_touch_updated_at
before update on public.legal_cases
for each row execute function public.autoclair_legal_touch_updated_at();

drop trigger if exists legal_case_facts_touch_updated_at on public.legal_case_facts;
create trigger legal_case_facts_touch_updated_at
before update on public.legal_case_facts
for each row execute function public.autoclair_legal_touch_updated_at();

create or replace function public.autoclair_legal_validate_relation_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.legal_cases c
    where c.id = new.case_id
      and c.user_id = new.user_id
  ) then
    raise exception 'LEGAL_CASE_OWNER_MISMATCH';
  end if;

  if tg_table_name = 'legal_case_documents' then
    if not exists (
      select 1
      from public.documents d
      where d.id = new.document_id
        and d.user_id = new.user_id
    ) then
      raise exception 'LEGAL_DOCUMENT_OWNER_MISMATCH';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.autoclair_legal_validate_relation_owner()
  from public, anon, authenticated;

drop trigger if exists legal_case_facts_owner_guard on public.legal_case_facts;
create trigger legal_case_facts_owner_guard
before insert or update on public.legal_case_facts
for each row execute function public.autoclair_legal_validate_relation_owner();

drop trigger if exists legal_case_documents_owner_guard on public.legal_case_documents;
create trigger legal_case_documents_owner_guard
before insert or update on public.legal_case_documents
for each row execute function public.autoclair_legal_validate_relation_owner();

drop trigger if exists legal_assessments_owner_guard on public.legal_assessments;
create trigger legal_assessments_owner_guard
before insert or update on public.legal_assessments
for each row execute function public.autoclair_legal_validate_relation_owner();

alter table public.legal_cases enable row level security;
alter table public.legal_case_facts enable row level security;
alter table public.legal_case_documents enable row level security;
alter table public.legal_assessments enable row level security;

revoke all on public.legal_cases from anon;
revoke all on public.legal_case_facts from anon;
revoke all on public.legal_case_documents from anon;
revoke all on public.legal_assessments from anon;

revoke all on public.legal_cases from authenticated;
revoke all on public.legal_case_facts from authenticated;
revoke all on public.legal_case_documents from authenticated;
revoke all on public.legal_assessments from authenticated;

grant select, insert, update, delete on public.legal_cases to authenticated;
grant select, insert, update, delete on public.legal_case_facts to authenticated;
grant select, insert, update, delete on public.legal_case_documents to authenticated;
grant select on public.legal_assessments to authenticated;

create policy legal_cases_select_own
on public.legal_cases
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy legal_cases_insert_own
on public.legal_cases
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy legal_cases_update_own
on public.legal_cases
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy legal_cases_delete_own
on public.legal_cases
for delete
to authenticated
using ((select auth.uid()) = user_id);

create policy legal_case_facts_select_own
on public.legal_case_facts
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy legal_case_facts_insert_own
on public.legal_case_facts
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy legal_case_facts_update_own
on public.legal_case_facts
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy legal_case_facts_delete_own
on public.legal_case_facts
for delete
to authenticated
using ((select auth.uid()) = user_id);

create policy legal_case_documents_select_own
on public.legal_case_documents
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy legal_case_documents_insert_own
on public.legal_case_documents
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy legal_case_documents_update_own
on public.legal_case_documents
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy legal_case_documents_delete_own
on public.legal_case_documents
for delete
to authenticated
using ((select auth.uid()) = user_id);

create policy legal_assessments_select_own
on public.legal_assessments
for select
to authenticated
using ((select auth.uid()) = user_id);
