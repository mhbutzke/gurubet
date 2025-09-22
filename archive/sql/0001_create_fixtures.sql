-- Create fixtures table based on Sportmonks football fixtures response
create table if not exists public.fixtures (
  id bigint primary key,
  sport_id bigint not null,
  league_id bigint not null,
  season_id bigint not null,
  stage_id bigint,
  group_id bigint,
  aggregate_id bigint,
  round_id bigint,
  state_id bigint,
  venue_id bigint,
  name text not null,
  starting_at timestamp without time zone,
  result_info text,
  leg text,
  details jsonb,
  length smallint,
  placeholder boolean default false not null,
  has_odds boolean default false not null,
  has_premium_odds boolean default false not null,
  starting_at_timestamp bigint,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

create index if not exists fixtures_league_season_idx on public.fixtures (league_id, season_id);
create index if not exists fixtures_starting_at_idx on public.fixtures (starting_at);
create index if not exists fixtures_state_idx on public.fixtures (state_id);
