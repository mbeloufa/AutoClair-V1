create role anon nologin;
create role authenticated nologin;
create role service_role nologin;
create schema auth;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable
as $$select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid$$;
grant usage on schema auth to authenticated;
grant execute on function auth.uid() to authenticated;
create table public.vehicle_analysis_reports(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id),
 status text not null default 'completed'
);
create table public.document_analyses(
  id uuid primary key default gen_random_uuid(),
  document_id uuid,
  user_id uuid not null references auth.users(id)
);
insert into auth.users(id) values
 ('11111111-1111-4111-8111-111111111111'),
 ('22222222-2222-4222-8222-222222222222');
-- First user has an existing completed document and therefore NO new trial.
insert into public.document_analyses(user_id)
 values('11111111-1111-4111-8111-111111111111');

create table public.user_entitlements(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id),
 entitlement_code text not null,
 status text not null,
 starts_at timestamptz not null default now(),
 expires_at timestamptz
);
