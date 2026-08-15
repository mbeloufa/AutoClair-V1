-- AutoClair - Assistance immediate V1
-- Triage de securite automobile, media prives et historique d'incident.

create table public.emergency_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  category text not null check (category in (
    'warning_light',
    'noise_behavior',
    'immobilized',
    'locked_out',
    'smoke_smell_leak',
    'tire_problem',
    'power_loss',
    'other'
  )),
  status text not null default 'collecting' check (status in (
    'collecting',
    'needs_information',
    'assessed',
    'closed'
  )),
  user_stopped_safe boolean not null default false,
  road_context text not null default 'unknown' check (road_context in (
    'unknown',
    'parking',
    'city',
    'road',
    'motorway'
  )),
  description text not null default '' check (char_length(description) <= 5000),
  symptom_flags jsonb not null default '{}'::jsonb
    check (jsonb_typeof(symptom_flags) = 'object'),
  clarifications jsonb not null default '[]'::jsonb
    check (jsonb_typeof(clarifications) = 'array'),
  latitude numeric(9,6) null check (latitude is null or latitude between -90 and 90),
  longitude numeric(9,6) null check (longitude is null or longitude between -180 and 180),
  location_accuracy_m numeric(9,2) null check (
    location_accuracy_m is null or location_accuracy_m >= 0
  ),
  saved_event_id uuid null references public.vehicle_events(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index emergency_sessions_user_created_idx
  on public.emergency_sessions(user_id, created_at desc);
create index emergency_sessions_vehicle_created_idx
  on public.emergency_sessions(user_id, vehicle_id, created_at desc);

create table public.emergency_media (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.emergency_sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('photo', 'audio')),
  object_path text not null unique check (char_length(object_path) between 1 and 500),
  original_name text not null check (char_length(original_name) between 1 and 240),
  mime_type text not null check (char_length(mime_type) between 1 and 120),
  size_bytes integer not null check (size_bytes between 1 and 10485760),
  created_at timestamptz not null default now()
);

create index emergency_media_session_idx
  on public.emergency_media(user_id, session_id, created_at);

create table public.emergency_assessments (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.emergency_sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in ('ready', 'needs_information')),
  deterministic_level text not null check (deterministic_level in (
    'stop',
    'assistance',
    'prompt_check',
    'monitor'
  )),
  final_level text not null check (final_level in (
    'stop',
    'assistance',
    'prompt_check',
    'monitor'
  )),
  model text null,
  prompt_version text not null,
  rules_version text not null,
  result_json jsonb not null check (jsonb_typeof(result_json) = 'object'),
  created_at timestamptz not null default now()
);

create index emergency_assessments_session_idx
  on public.emergency_assessments(user_id, session_id, created_at desc);

create table public.assistance_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  provider_name text not null default '' check (char_length(provider_name) <= 160),
  phone_number text not null default '' check (char_length(phone_number) <= 60),
  contract_number text not null default '' check (char_length(contract_number) <= 160),
  coverage_note text not null default '' check (char_length(coverage_note) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, vehicle_id)
);

create or replace function public.touch_emergency_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger emergency_sessions_touch_updated_at
before update on public.emergency_sessions
for each row execute function public.touch_emergency_updated_at();

create trigger assistance_profiles_touch_updated_at
before update on public.assistance_profiles
for each row execute function public.touch_emergency_updated_at();

alter table public.emergency_sessions enable row level security;
alter table public.emergency_media enable row level security;
alter table public.emergency_assessments enable row level security;
alter table public.assistance_profiles enable row level security;

create policy emergency_sessions_select_own
on public.emergency_sessions
for select to authenticated
using (user_id = auth.uid());

create policy emergency_sessions_insert_own
on public.emergency_sessions
for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.vehicles v
    where v.id = vehicle_id
      and v.user_id = auth.uid()
  )
);

create policy emergency_sessions_update_own
on public.emergency_sessions
for update to authenticated
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.vehicles v
    where v.id = vehicle_id
      and v.user_id = auth.uid()
  )
  and (
    saved_event_id is null
    or exists (
      select 1
      from public.vehicle_events e
      where e.id = saved_event_id
        and e.user_id = auth.uid()
        and e.vehicle_id = vehicle_id
    )
  )
);

create policy emergency_sessions_delete_own
on public.emergency_sessions
for delete to authenticated
using (user_id = auth.uid());

create policy emergency_media_select_own
on public.emergency_media
for select to authenticated
using (user_id = auth.uid());

create policy emergency_media_insert_own
on public.emergency_media
for insert to authenticated
with check (
  user_id = auth.uid()
  and (storage.foldername(object_path))[1] = auth.uid()::text
  and (storage.foldername(object_path))[2] = session_id::text
  and exists (
    select 1
    from public.emergency_sessions s
    where s.id = session_id
      and s.user_id = auth.uid()
  )
);

create policy emergency_media_delete_own
on public.emergency_media
for delete to authenticated
using (user_id = auth.uid());

create policy emergency_assessments_select_own
on public.emergency_assessments
for select to authenticated
using (user_id = auth.uid());

create policy assistance_profiles_select_own
on public.assistance_profiles
for select to authenticated
using (user_id = auth.uid());

create policy assistance_profiles_insert_own
on public.assistance_profiles
for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.vehicles v
    where v.id = vehicle_id
      and v.user_id = auth.uid()
  )
);

create policy assistance_profiles_update_own
on public.assistance_profiles
for update to authenticated
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.vehicles v
    where v.id = vehicle_id
      and v.user_id = auth.uid()
  )
);

create policy assistance_profiles_delete_own
on public.assistance_profiles
for delete to authenticated
using (user_id = auth.uid());

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'emergency-media',
  'emergency-media',
  false,
  10485760,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'audio/mp4',
    'audio/x-m4a',
    'audio/m4a',
    'audio/aac',
    'audio/mpeg',
    'audio/wav',
    'audio/x-wav'
  ]::text[]
)
on conflict (id) do nothing;

create policy emergency_storage_select_own
on storage.objects
for select to authenticated
using (
  bucket_id = 'emergency-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy emergency_storage_insert_own
on storage.objects
for insert to authenticated
with check (
  bucket_id = 'emergency-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy emergency_storage_delete_own
on storage.objects
for delete to authenticated
using (
  bucket_id = 'emergency-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);
