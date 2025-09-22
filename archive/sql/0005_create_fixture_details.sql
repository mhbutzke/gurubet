-- Detailed fixture data: events and statistics
create table if not exists public.fixture_events (
  id bigint primary key,
  fixture_id bigint not null references public.fixtures(id) on delete cascade,
  period_id bigint,
  detailed_period_id bigint,
  participant_id bigint,
  type_id bigint,
  sub_type_id bigint,
  coach_id bigint,
  player_id bigint,
  related_player_id bigint,
  player_name text,
  related_player_name text,
  result text,
  info text,
  addition text,
  minute smallint,
  extra_minute smallint,
  injured boolean,
  on_bench boolean,
  rescinded boolean,
  section text,
  sort_order integer,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

create index if not exists fixture_events_fixture_idx on public.fixture_events (fixture_id);
create index if not exists fixture_events_participant_idx on public.fixture_events (participant_id);
create index if not exists fixture_events_type_idx on public.fixture_events (type_id);

create table if not exists public.fixture_statistics (
  id bigint primary key,
  fixture_id bigint not null references public.fixtures(id) on delete cascade,
  participant_id bigint,
  player_id bigint,
  type_id bigint,
  location text,
  value_numeric numeric,
  value_text text,
  data jsonb,
  type_name text,
  type_code text,
  stat_group text,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

create index if not exists fixture_statistics_fixture_idx on public.fixture_statistics (fixture_id);
create index if not exists fixture_statistics_participant_idx on public.fixture_statistics (participant_id);
create index if not exists fixture_statistics_type_idx on public.fixture_statistics (type_id);
