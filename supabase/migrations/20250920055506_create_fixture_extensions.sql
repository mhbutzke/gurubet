-- Fixture enrichment tables for participants, scores, periods, lineups, odds and weather
-- Matches the data model exposed by the Sportmonks v3 Football API

-- Views antigas podem depender das colunas abaixo; removemos para recriá-las na 0009
drop view if exists public.v_fixtures_with_participants cascade;
drop view if exists public.v_fixtures_complete cascade;
drop view if exists public.v_fixtures_today cascade;
drop view if exists public.v_fixtures_this_week cascade;

create table if not exists public.fixture_participants (
  fixture_id bigint not null references public.fixtures(id) on delete cascade,
  participant_id bigint not null,
  location text,
  winner boolean,
  position integer,
  meta jsonb,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null,
  primary key (fixture_id, participant_id)
);

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fixture_participants'
      and column_name = 'team_id'
  ) then
    begin
      execute 'alter table public.fixture_participants rename column team_id to participant_id';
    exception when duplicate_column then
      -- coluna já renomeada em ambiente paralelo
      null;
    end;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fixture_participants'
      and column_name = 'location'
  ) then
    execute 'alter table public.fixture_participants add column location text';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fixture_participants'
      and column_name = 'winner'
  ) then
    execute 'alter table public.fixture_participants add column winner boolean';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fixture_participants'
      and column_name = 'position'
  ) then
    execute 'alter table public.fixture_participants add column position integer';
  end if;

  begin
    execute 'alter table public.fixture_participants alter column meta type jsonb using meta::jsonb';
  exception when undefined_column then
    execute 'alter table public.fixture_participants add column meta jsonb';
  end;
end;
$$;

create index if not exists fixture_participants_participant_id_idx
  on public.fixture_participants (participant_id);
create index if not exists fixture_participants_location_idx
  on public.fixture_participants (location);

create table if not exists public.fixture_scores (
  id bigint primary key,
  fixture_id bigint not null references public.fixtures(id) on delete cascade,
  participant_id bigint,
  type_id bigint,
  score jsonb not null,
  description text,
  result text,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fixture_scores'
      and column_name = 'result'
  ) then
    execute 'alter table public.fixture_scores add column result text';
  end if;

  begin
    execute 'alter table public.fixture_scores alter column score type jsonb using score::jsonb';
  exception when undefined_column then
    execute 'alter table public.fixture_scores add column score jsonb';
  end;
end;
$$;

create index if not exists fixture_scores_fixture_id_idx
  on public.fixture_scores (fixture_id);
create index if not exists fixture_scores_participant_id_idx
  on public.fixture_scores (participant_id);
create index if not exists fixture_scores_type_id_idx
  on public.fixture_scores (type_id);

create table if not exists public.fixture_periods (
  id bigint primary key,
  fixture_id bigint not null references public.fixtures(id) on delete cascade,
  type_id bigint,
  started boolean default false,
  ended boolean default false,
  counts_from integer,
  ticking boolean default false,
  sort_order integer,
  description text,
  time_added integer,
  period_length integer,
  minutes integer,
  seconds integer,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

create index if not exists fixture_periods_fixture_id_idx
  on public.fixture_periods (fixture_id);
create index if not exists fixture_periods_type_id_idx
  on public.fixture_periods (type_id);

create table if not exists public.fixture_lineups (
  id bigint primary key,
  fixture_id bigint not null references public.fixtures(id) on delete cascade,
  participant_id bigint,
  player_id bigint,
  position_id bigint,
  jersey_number integer,
  player_name text,
  formation_field integer,
  formation_position integer,
  posx integer,
  posy integer,
  captain boolean default false,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fixture_lineups'
      and column_name = 'team_id'
  ) then
    begin
      execute 'alter table public.fixture_lineups rename column team_id to participant_id';
    exception when duplicate_column then null;
    end;
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fixture_lineups'
      and column_name = 'type_id'
  ) then
    begin
      execute 'alter table public.fixture_lineups rename column type_id to position_id';
    exception when duplicate_column then null;
    end;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fixture_lineups'
      and column_name = 'formation_field'
  ) then
    execute 'alter table public.fixture_lineups add column formation_field integer';
  else
    begin
      execute 'alter table public.fixture_lineups alter column formation_field type integer using nullif(formation_field::text, '''')::integer';
    exception when invalid_text_representation then null;
    end;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fixture_lineups'
      and column_name = 'formation_position'
  ) then
    execute 'alter table public.fixture_lineups add column formation_position integer';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fixture_lineups'
      and column_name = 'posx'
  ) then
    execute 'alter table public.fixture_lineups add column posx integer';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fixture_lineups'
      and column_name = 'posy'
  ) then
    execute 'alter table public.fixture_lineups add column posy integer';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fixture_lineups'
      and column_name = 'captain'
  ) then
    execute 'alter table public.fixture_lineups add column captain boolean default false';
  end if;
end;
$$;

create index if not exists fixture_lineups_fixture_id_idx
  on public.fixture_lineups (fixture_id);
create index if not exists fixture_lineups_participant_id_idx
  on public.fixture_lineups (participant_id);
create index if not exists fixture_lineups_player_id_idx
  on public.fixture_lineups (player_id);

create table if not exists public.fixture_lineup_details (
  id bigint primary key,
  fixture_id bigint not null references public.fixtures(id) on delete cascade,
  lineup_id bigint not null references public.fixture_lineups(id) on delete cascade,
  participant_id bigint,
  player_id bigint,
  related_player_id bigint,
  type_id bigint,
  formation_field integer,
  formation_position integer,
  minute integer,
  additional_position_id bigint,
  jersey_number integer,
  player_name text,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fixture_lineup_details'
      and column_name = 'team_id'
  ) then
    begin
      execute 'alter table public.fixture_lineup_details rename column team_id to participant_id';
    exception when duplicate_column then null;
    end;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fixture_lineup_details'
      and column_name = 'related_player_id'
  ) then
    execute 'alter table public.fixture_lineup_details add column related_player_id bigint';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fixture_lineup_details'
      and column_name = 'minute'
  ) then
    execute 'alter table public.fixture_lineup_details add column minute integer';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fixture_lineup_details'
      and column_name = 'additional_position_id'
  ) then
    execute 'alter table public.fixture_lineup_details add column additional_position_id bigint';
  end if;
end;
$$;

create index if not exists fixture_lineup_details_fixture_id_idx
  on public.fixture_lineup_details (fixture_id);
create index if not exists fixture_lineup_details_lineup_id_idx
  on public.fixture_lineup_details (lineup_id);
create index if not exists fixture_lineup_details_player_id_idx
  on public.fixture_lineup_details (player_id);
create index if not exists fixture_lineup_details_participant_id_idx
  on public.fixture_lineup_details (participant_id);

create table if not exists public.fixture_odds (
  id bigint primary key,
  fixture_id bigint not null references public.fixtures(id) on delete cascade,
  bookmaker_id bigint,
  market_id bigint,
  label text,
  value numeric,
  probability numeric,
  dp3 text,
  fractional text,
  american text,
  winning boolean,
  stopped boolean,
  handicap numeric,
  participant text,
  latest_bookmaker_update timestamptz,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fixture_odds'
      and column_name = 'result'
  ) then
    -- older estruturas podem não ter coluna result; ignoramos caso não usada
    null;
  end if;

  begin
    execute 'alter table public.fixture_odds alter column value type numeric using nullif(value::text, '''')::numeric';
  exception when undefined_column then
    execute 'alter table public.fixture_odds add column value numeric';
  when invalid_text_representation then
    -- mantém texto se não puder converter
    null;
  end;

  begin
    execute 'alter table public.fixture_odds alter column probability type numeric using nullif(probability::text, '''')::numeric';
  exception when undefined_column then
    execute 'alter table public.fixture_odds add column probability numeric';
  when invalid_text_representation then null;
  end;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fixture_odds'
      and column_name = 'handicap'
  ) then
    execute 'alter table public.fixture_odds add column handicap numeric';
  end if;
end;
$$;

create index if not exists fixture_odds_fixture_id_idx
  on public.fixture_odds (fixture_id);
create index if not exists fixture_odds_market_id_idx
  on public.fixture_odds (market_id);
create index if not exists fixture_odds_bookmaker_id_idx
  on public.fixture_odds (bookmaker_id);

create table if not exists public.fixture_weather (
  fixture_id bigint primary key references public.fixtures(id) on delete cascade,
  temperature_celsius numeric,
  temperature_fahrenheit numeric,
  humidity integer,
  pressure numeric,
  wind_speed numeric,
  wind_direction integer,
  clouds integer,
  condition_code text,
  condition_description text,
  condition_icon text,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

do $$
declare
  pk_name text;
begin
  select conname
    into pk_name
  from pg_constraint
  where conrelid = 'public.fixture_weather'::regclass
    and contype = 'p'
  limit 1;

  if pk_name is not null then
    execute 'alter table public.fixture_weather drop constraint ' || quote_ident(pk_name);
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'fixture_weather'
      and column_name = 'id'
  ) then
    execute 'alter table public.fixture_weather drop column id';
  end if;

  begin
    execute 'alter table public.fixture_weather add constraint fixture_weather_fixture_id_key primary key (fixture_id)';
  exception when duplicate_object then
    null;
  end;
end;
$$;

create index if not exists fixture_weather_wind_direction_idx
  on public.fixture_weather (wind_direction);

comment on table public.fixture_participants is 'Participants (teams) for fixtures enriched from Sportmonks includes.';
comment on table public.fixture_scores is 'Score breakdown per fixture, period type and participant.';
comment on table public.fixture_periods is 'Detailed period timeline for fixtures (regular time, extra time, penalties).';
comment on table public.fixture_lineups is 'Starting lineup data for fixtures including formation coordinates.';
comment on table public.fixture_lineup_details is 'Additional lineup details such as substitutions and bench information.';
comment on table public.fixture_odds is 'Basic betting odds returned by Sportmonks bookmakers feed.';
comment on table public.fixture_weather is 'Weather report captured alongside fixtures.';
