begin;

create table if not exists public.tire_ai_inspections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  status text not null default 'DRAFT',
  global_status text,
  summary text,
  analysis_json jsonb not null default '{}'::jsonb,
  front_dimension text,
  rear_dimension text,
  replacement_recommended boolean not null default false,
  offers_json jsonb not null default '[]'::jsonb,
  offers_researched_at timestamptz,
  model_id text,
  analyzed_at timestamptz,
  error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tire_ai_inspections_status_check
    check (status in ('DRAFT','ANALYZING','NEEDS_RETAKE','READY','FAILED')),
  constraint tire_ai_inspections_global_status_check
    check (global_status is null or global_status in (
      'OK','WATCH','REPLACE_SOON','REPLACE_NOW','URGENT_PROFESSIONAL_CHECK','UNKNOWN'
    ))
);

create table if not exists public.tire_ai_photos (
  id uuid primary key default gen_random_uuid(),
  inspection_id uuid not null references public.tire_ai_inspections(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  slot text not null,
  storage_path text not null,
  content_type text not null default 'image/jpeg',
  created_at timestamptz not null default now(),
  constraint tire_ai_photos_slot_check check (slot in (
    'FRONT_LEFT_TREAD','FRONT_RIGHT_TREAD','REAR_LEFT_TREAD','REAR_RIGHT_TREAD',
    'FRONT_SIDEWALL','REAR_SIDEWALL'
  )),
  constraint tire_ai_photos_unique_slot unique (inspection_id, slot)
);

create index if not exists tire_ai_inspections_vehicle_created_idx
  on public.tire_ai_inspections(vehicle_id, created_at desc);
create index if not exists tire_ai_photos_inspection_idx
  on public.tire_ai_photos(inspection_id);

alter table public.tire_ai_inspections enable row level security;
alter table public.tire_ai_photos enable row level security;

drop policy if exists tire_ai_inspections_select_own on public.tire_ai_inspections;
create policy tire_ai_inspections_select_own
  on public.tire_ai_inspections for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists tire_ai_inspections_insert_own on public.tire_ai_inspections;
create policy tire_ai_inspections_insert_own
  on public.tire_ai_inspections for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists tire_ai_inspections_update_own on public.tire_ai_inspections;
create policy tire_ai_inspections_update_own
  on public.tire_ai_inspections for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists tire_ai_inspections_delete_own on public.tire_ai_inspections;
create policy tire_ai_inspections_delete_own
  on public.tire_ai_inspections for delete to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists tire_ai_photos_select_own on public.tire_ai_photos;
create policy tire_ai_photos_select_own
  on public.tire_ai_photos for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists tire_ai_photos_insert_own on public.tire_ai_photos;
create policy tire_ai_photos_insert_own
  on public.tire_ai_photos for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.tire_ai_inspections inspection
      where inspection.id = inspection_id
        and inspection.user_id = (select auth.uid())
        and inspection.vehicle_id = tire_ai_photos.vehicle_id
    )
  );

drop policy if exists tire_ai_photos_update_own on public.tire_ai_photos;
create policy tire_ai_photos_update_own
  on public.tire_ai_photos for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists tire_ai_photos_delete_own on public.tire_ai_photos;
create policy tire_ai_photos_delete_own
  on public.tire_ai_photos for delete to authenticated
  using ((select auth.uid()) = user_id);

grant select, insert, update, delete on public.tire_ai_inspections to authenticated;
grant select, insert, update, delete on public.tire_ai_photos to authenticated;
grant all on public.tire_ai_inspections to service_role;
grant all on public.tire_ai_photos to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'tire-inspections',
  'tire-inspections',
  false,
  8388608,
  array['image/jpeg','image/png','image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists tire_inspection_objects_select_own on storage.objects;
create policy tire_inspection_objects_select_own
  on storage.objects for select to authenticated
  using (
    bucket_id = 'tire-inspections'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists tire_inspection_objects_insert_own on storage.objects;
create policy tire_inspection_objects_insert_own
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'tire-inspections'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists tire_inspection_objects_update_own on storage.objects;
create policy tire_inspection_objects_update_own
  on storage.objects for update to authenticated
  using (
    bucket_id = 'tire-inspections'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'tire-inspections'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists tire_inspection_objects_delete_own on storage.objects;
create policy tire_inspection_objects_delete_own
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'tire-inspections'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create or replace function public.create_tire_ai_inspection(p_vehicle_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid;
  v_inspection_id uuid;
begin
  v_user_id := private.require_vehicle_owner(p_vehicle_id);
  insert into public.tire_ai_inspections(user_id, vehicle_id)
  values (v_user_id, p_vehicle_id)
  returning id into v_inspection_id;
  return v_inspection_id;
end;
$function$;

revoke all on function public.create_tire_ai_inspection(uuid) from public, anon;
grant execute on function public.create_tire_ai_inspection(uuid) to authenticated, service_role;

commit;
