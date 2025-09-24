-- Function: analytics.get_fixtures_upcoming(league_filter int default null)

create or replace function analytics.get_fixtures_upcoming(league_filter int default null)
returns table (
  id bigint,
  name text,
  starting_at_brt text,
  league_id bigint,
  league_name text,
  season_name text,
  home_team_name text,
  home_it1 numeric,
  home_it2 numeric,
  home_t numeric,
  home_it1_1h numeric,
  home_it2_1h numeric,
  home_t_1h numeric,
  home_diff text,
  home_diff_1h text,
  home_j integer,
  away_team_name text,
  away_it1 numeric,
  away_it2 numeric,
  away_t numeric,
  away_it1_1h numeric,
  away_it2_1h numeric,
  away_t_1h numeric,
  away_diff text,
  away_diff_1h text,
  away_j integer,
  referee_id bigint,
  referee_name text,
  referee_t numeric,
  referee_t_1h numeric,
  referee_j integer
)
language sql
security definer
set search_path = analytics, public
as $$
  select *
  from analytics.v_fixtures_upcoming
  where league_filter is null or league_id = league_filter
  order by starting_at_brt
$$;


