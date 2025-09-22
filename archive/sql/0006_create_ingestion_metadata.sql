-- Metadata tables to track incremental ingestion state and run history
create schema if not exists metadata;

create table if not exists metadata.ingestion_state (
  entity text primary key,
  last_id bigint,
  last_timestamp timestamptz,
  updated_at timestamptz default timezone('utc', now()) not null
);

create table if not exists metadata.ingestion_runs (
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
  on metadata.ingestion_runs (entity, started_at desc);
