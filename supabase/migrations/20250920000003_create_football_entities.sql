-- Football domain reference entities from Sportmonks Football API
create table if not exists public.venues (
  id bigint primary key,
  country_id bigint references public.countries(id),
  city_id bigint references public.cities(id),
  name text not null,
  address text,
  zipcode text,
  latitude double precision,
  longitude double precision,
  capacity integer,
  image_path text,
  city_name text,
  surface text,
  national_team boolean default false not null,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

create index if not exists venues_country_idx on public.venues (country_id);
create index if not exists venues_city_idx on public.venues (city_id);

create table if not exists public.leagues (
  id bigint primary key,
  sport_id bigint not null,
  country_id bigint references public.countries(id),
  name text not null,
  active boolean default true not null,
  short_code text,
  image_path text,
  type text,
  sub_type text,
  last_played_at timestamp without time zone,
  category integer,
  has_jerseys boolean default false not null,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

create index if not exists leagues_country_idx on public.leagues (country_id);
create index if not exists leagues_sport_idx on public.leagues (sport_id);

create table if not exists public.seasons (
  id bigint primary key,
  sport_id bigint not null,
  league_id bigint references public.leagues(id),
  tie_breaker_rule_id bigint,
  name text not null,
  finished boolean default false not null,
  pending boolean default false not null,
  is_current boolean default false not null,
  starting_at date,
  ending_at date,
  standings_recalculated_at timestamp without time zone,
  games_in_current_week boolean default false not null,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

create index if not exists seasons_league_idx on public.seasons (league_id);

create table if not exists public.stages (
  id bigint primary key,
  sport_id bigint not null,
  league_id bigint references public.leagues(id),
  season_id bigint references public.seasons(id),
  type_id bigint references public.core_types(id),
  name text not null,
  sort_order integer,
  finished boolean default false not null,
  is_current boolean default false not null,
  starting_at date,
  ending_at date,
  games_in_current_week boolean default false not null,
  tie_breaker_rule_id bigint,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

create index if not exists stages_season_idx on public.stages (season_id);

create table if not exists public.rounds (
  id bigint primary key,
  sport_id bigint not null,
  league_id bigint references public.leagues(id),
  season_id bigint references public.seasons(id),
  stage_id bigint references public.stages(id),
  name text not null,
  finished boolean default false not null,
  is_current boolean default false not null,
  starting_at date,
  ending_at date,
  games_in_current_week boolean default false not null,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

create index if not exists rounds_stage_idx on public.rounds (stage_id);

create table if not exists public.states (
  id bigint primary key,
  state text not null,
  name text not null,
  short_name text,
  developer_name text,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

create table if not exists public.teams (
  id bigint primary key,
  sport_id bigint not null,
  country_id bigint references public.countries(id),
  venue_id bigint references public.venues(id),
  gender text,
  name text not null,
  short_code text,
  image_path text,
  founded integer,
  type text,
  placeholder boolean default false not null,
  last_played_at timestamp without time zone,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

create index if not exists teams_country_idx on public.teams (country_id);
create index if not exists teams_venue_idx on public.teams (venue_id);

create table if not exists public.standings (
  id bigint primary key,
  participant_id bigint references public.teams(id),
  sport_id bigint not null,
  league_id bigint references public.leagues(id),
  season_id bigint references public.seasons(id),
  stage_id bigint references public.stages(id),
  group_id bigint,
  round_id bigint references public.rounds(id),
  standing_rule_id bigint,
  position integer,
  result text,
  points numeric,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

create index if not exists standings_season_idx on public.standings (season_id);
create index if not exists standings_participant_idx on public.standings (participant_id);

create table if not exists public.referees (
  id bigint primary key,
  sport_id bigint not null,
  country_id bigint references public.countries(id),
  city_id bigint references public.cities(id),
  common_name text,
  firstname text,
  lastname text,
  name text,
  display_name text,
  image_path text,
  height integer,
  weight integer,
  date_of_birth date,
  gender text,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

create table if not exists public.players (
  id bigint primary key,
  sport_id bigint not null,
  country_id bigint references public.countries(id),
  nationality_id bigint references public.countries(id),
  city_id bigint references public.cities(id),
  position_id bigint,
  detailed_position_id bigint,
  type_id bigint references public.core_types(id),
  common_name text,
  firstname text,
  lastname text,
  name text,
  display_name text,
  image_path text,
  height integer,
  weight integer,
  date_of_birth date,
  gender text,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

create index if not exists players_country_idx on public.players (country_id);
create index if not exists players_nationality_idx on public.players (nationality_id);

create table if not exists public.coaches (
  id bigint primary key,
  player_id bigint references public.players(id),
  sport_id bigint not null,
  country_id bigint references public.countries(id),
  nationality_id bigint references public.countries(id),
  city_id bigint references public.cities(id),
  common_name text,
  firstname text,
  lastname text,
  name text,
  display_name text,
  image_path text,
  height integer,
  weight integer,
  date_of_birth date,
  gender text,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null
);

create index if not exists coaches_country_idx on public.coaches (country_id);
