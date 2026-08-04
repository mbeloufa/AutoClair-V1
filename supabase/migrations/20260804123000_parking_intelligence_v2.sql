begin;

create table if not exists public.parking_availability_snapshots (
  id uuid primary key default gen_random_uuid(),
  provider_code text not null,
  external_id text not null,
  parking_name text not null,
  latitude double precision,
  longitude double precision,
  available_spaces integer,
  capacity integer,
  availability_status text not null default 'unknown',
  source_updated_at timestamptz not null,
  observed_at timestamptz not null default now(),
  source_hash text,
  created_at timestamptz not null default now(),
  constraint parking_availability_available_nonnegative
    check (available_spaces is null or available_spaces >= 0),
  constraint parking_availability_capacity_positive
    check (capacity is null or capacity > 0),
  constraint parking_availability_status_allowed
    check (
      availability_status in (
        'open', 'closed', 'full', 'unavailable', 'unknown'
      )
    )
);

create unique index if not exists parking_availability_snapshots_source_unique
  on public.parking_availability_snapshots (
    provider_code,
    external_id,
    source_updated_at
  );

create index if not exists parking_availability_snapshots_lookup_idx
  on public.parking_availability_snapshots (
    provider_code, external_id, observed_at desc
  );

create index if not exists parking_availability_snapshots_time_idx
  on public.parking_availability_snapshots (observed_at desc);

alter table public.parking_availability_snapshots enable row level security;

revoke all on table public.parking_availability_snapshots
  from public, anon, authenticated;

grant select, insert, update, delete
  on table public.parking_availability_snapshots
  to service_role;

comment on table public.parking_availability_snapshots is
  'Historique technique des disponibilités publiques observées par AutoClair. '
  'Aucune donnée personnelle ni position utilisateur n’est stockée.';

commit;
