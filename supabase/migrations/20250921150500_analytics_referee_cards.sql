-- Analytics: referee season cards (home/away)

-- Link table for fixtures and referees
create table if not exists public.fixture_referees (
  fixture_id bigint not null references public.fixtures(id) on delete cascade,
  referee_id bigint not null references public.referees(id) on delete cascade,
  role text,
  created_at timestamptz default timezone('utc', now()) not null,
  updated_at timestamptz default timezone('utc', now()) not null,
  primary key (fixture_id, referee_id)
);
create index if not exists fixture_referees_referee_idx on public.fixture_referees (referee_id);

-- MV by referee/season/league
 drop materialized view if exists analytics.mv_referee_season_cards;
create materialized view analytics.mv_referee_season_cards as
with base as (
  select
    f.season_id,
    f.league_id,
    fr.referee_id,
    lower(coalesce(fp.location, fp.meta->>'location')) as home_away,
    fe.fixture_id,
    upper(coalesce(ct.developer_name, '')) as event_code
  from public.fixture_events fe
  join public.fixtures f on f.id = fe.fixture_id
  left join public.fixture_participants fp on fp.fixture_id = fe.fixture_id and fp.participant_id = fe.participant_id
  left join public.core_types ct on ct.id = fe.type_id
  join public.fixture_referees fr on fr.fixture_id = fe.fixture_id
), agg as (
  select
    season_id,
    league_id,
    referee_id,
    count(distinct fixture_id) as matches,
    count(*) filter (where event_code in ('YELLOWCARD','YELLOW_CARD','YELLOW')) as yellow,
    count(*) filter (where event_code in ('SECONDYELLOW','SECOND_YELLOW','YELLOWREDCARD','YELLOW_RED_CARD')) as second_yellow,
    count(*) filter (where event_code in ('REDCARD','RED_CARD','DIRECTRED','DIRECT_RED')) as red,
    count(*) filter (where event_code in ('YELLOWCARD','YELLOW_CARD','YELLOW','SECONDYELLOW','SECOND_YELLOW','YELLOWREDCARD','YELLOW_RED_CARD','REDCARD','RED_CARD','DIRECTRED','DIRECT_RED')) as total_cards,
    count(*) filter (where home_away = 'home' and event_code in ('YELLOWCARD','YELLOW_CARD','YELLOW','SECONDYELLOW','SECOND_YELLOW','YELLOWREDCARD','YELLOW_RED_CARD','REDCARD','RED_CARD','DIRECTRED','DIRECT_RED')) as total_cards_home,
    count(*) filter (where home_away = 'away' and event_code in ('YELLOWCARD','YELLOW_CARD','YELLOW','SECONDYELLOW','SECOND_YELLOW','YELLOWREDCARD','YELLOW_RED_CARD','REDCARD','RED_CARD','DIRECTRED','DIRECT_RED')) as total_cards_away
  from base
  group by season_id, league_id, referee_id
)
select
  season_id,
  league_id,
  referee_id,
  matches,
  yellow,
  second_yellow,
  red,
  total_cards,
  total_cards_home,
  total_cards_away,
  round(total_cards::numeric / nullif(matches, 0), 3) as cards_per_match,
  round(total_cards_home::numeric / nullif(matches, 0), 3) as cards_per_match_home,
  round(total_cards_away::numeric / nullif(matches, 0), 3) as cards_per_match_away
from agg;

create unique index if not exists mv_referee_season_cards_pk
  on analytics.mv_referee_season_cards (season_id, league_id, referee_id);

create or replace view analytics.referee_season_cards as
  select * from analytics.mv_referee_season_cards;

-- Include in daily refresh
create or replace function analytics.refresh_analytics()
returns void
language plpgsql
security definer
set search_path = public, analytics
as $$
begin
  refresh materialized view analytics.mv_team_season_cards;
  refresh materialized view analytics.mv_player_season_cards;
  refresh materialized view analytics.mv_team_season_stat_by_code;
  refresh materialized view analytics.mv_referee_season_cards;
end;
$$;
