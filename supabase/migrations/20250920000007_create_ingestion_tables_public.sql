-- Ensure ingestion metadata tables exist in the public schema for Edge Functions access
create table if not exists public.ingestion_state (
  entity text primary key,
  last_id bigint,
  last_timestamp timestamptz,
  updated_at timestamptz default timezone('utc', now()) not null
);

create table if not exists public.ingestion_runs (
  id bigserial primary key,
  entity text not null,
  started_at timestamptz default timezone('utc', now()) not null,
  finished_at timestamptz,
  status text not null,
  processed_count integer default 0,
  error_message text,
  details jsonb,
  created_at timestamptz default timezone('utc', now()) not null
);

create index if not exists ingestion_runs_entity_started_idx
  on public.ingestion_runs (entity, started_at desc);

-- Migrate data from metadata schema if it exists
insert into public.ingestion_state (entity, last_id, last_timestamp, updated_at)
select entity, last_id, last_timestamp, updated_at
from metadata.ingestion_state
on conflict (entity) do update
set last_id = excluded.last_id,
    last_timestamp = excluded.last_timestamp,
    updated_at = excluded.updated_at;

insert into public.ingestion_runs (id, entity, started_at, finished_at, status, processed_count, error_message, details, created_at)
select id, entity, started_at, finished_at, status, processed_count, error_message, details, created_at
from metadata.ingestion_runs
on conflict do nothing;
