-- Analytics module: base enriched views, materialized aggregates and daily refresh

-- 1) Schema
create schema if not exists analytics;

-- 2) Helpers
create or replace function analytics.get_opponent_id(fixture_id bigint, team_id bigint)
returns bigint
language sql
stable
set search_path = public, analytics
as $$
  select fp2.participant_id
  from public.fixture_participants fp2
  where fp2.fixture_id = fixture_id
    and fp2.participant_id is not null
    and fp2.participant_id <> team_id
  order by coalesce(fp2.position,
           case lower(coalesce(fp2.location, '')) when 'home' then 1 when 'away' then 2 else 99 end)
  limit 1;
$$;

-- 3) Base views
create or replace view analytics.v_events_enriched as
select
  fe.id as event_id,
  fe.fixture_id,
  f.season_id,
  f.league_id,
  f.starting_at,
  fe.participant_id as team_id,
  analytics.get_opponent_id(fe.fixture_id, fe.participant_id) as opponent_id,
  lower(coalesce(fp.location, fp.meta->>'location')) as home_away,
  fe.player_id,
  fe.minute,
  fe.extra_minute,
  upper(coalesce(ct.developer_name, '')) as event_code,
  ct.name as event_name
from public.fixture_events fe
join public.fixtures f on f.id = fe.fixture_id
left join public.fixture_participants fp on fp.fixture_id = fe.fixture_id and fp.participant_id = fe.participant_id
left join public.core_types ct on ct.id = fe.type_id;

create or replace view analytics.v_stats_enriched as
select
  fs.id as stat_id,
  fs.fixture_id,
  f.season_id,
  f.league_id,
  f.starting_at,
  fs.participant_id as team_id,
  analytics.get_opponent_id(fs.fixture_id, fs.participant_id) as opponent_id,
  lower(coalesce(fp.location, fp.meta->>'location')) as home_away,
  upper(coalesce(fs.type_code, fs.type_name)) as stat_code,
  fs.type_name,
  fs.stat_group,
  fs.value_numeric
from public.fixture_statistics fs
join public.fixtures f on f.id = fs.fixture_id
left join public.fixture_participants fp on fp.fixture_id = fs.fixture_id and fp.participant_id = fs.participant_id;

-- 4) Aggregates (materialized)
drop materialized view if exists analytics.mv_team_season_cards;
create materialized view analytics.mv_team_season_cards as
select
  season_id,
  league_id,
  team_id,
  matches,
  yellow_cards,
  second_yellow_cards,
  red_cards_direct,
  card_events,
  yellow_total,
  red_total,
  round(card_events::numeric / nullif(matches, 0), 3) as cards_per_match
from (
  select
    season_id,
    league_id,
    team_id,
    count(distinct fixture_id) as matches,
    count(*) filter (where event_code in ('YELLOWCARD','YELLOW_CARD','YELLOW')) as yellow_cards,
    count(*) filter (where event_code in ('SECONDYELLOW','SECOND_YELLOW','YELLOWREDCARD','YELLOW_RED_CARD')) as second_yellow_cards,
    count(*) filter (where event_code in ('REDCARD','RED_CARD','DIRECTRED','DIRECT_RED')) as red_cards_direct,
    count(*) filter (where event_code in ('YELLOWCARD','YELLOW_CARD','YELLOW','SECONDYELLOW','SECOND_YELLOW','YELLOWREDCARD','YELLOW_RED_CARD','REDCARD','RED_CARD','DIRECTRED','DIRECT_RED')) as card_events,
    (count(*) filter (where event_code in ('YELLOWCARD','YELLOW_CARD','YELLOW'))
     + count(*) filter (where event_code in ('SECONDYELLOW','SECOND_YELLOW','YELLOWREDCARD','YELLOW_RED_CARD'))) as yellow_total,
    (count(*) filter (where event_code in ('REDCARD','RED_CARD','DIRECTRED','DIRECT_RED'))
     + count(*) filter (where event_code in ('SECONDYELLOW','SECOND_YELLOW','YELLOWREDCARD','YELLOW_RED_CARD'))) as red_total
  from analytics.v_events_enriched
  group by season_id, league_id, team_id
) s;

create unique index if not exists mv_team_season_cards_pk
  on analytics.mv_team_season_cards (season_id, league_id, team_id);

drop materialized view if exists analytics.mv_player_season_cards;
create materialized view analytics.mv_player_season_cards as
select
  season_id,
  league_id,
  player_id,
  matches,
  yellow_cards,
  second_yellow_cards,
  red_cards_direct,
  card_events,
  round(card_events::numeric / nullif(matches, 0), 3) as cards_per_match
from (
  select
    season_id,
    league_id,
    player_id,
    count(distinct fixture_id) as matches,
    count(*) filter (where event_code in ('YELLOWCARD','YELLOW_CARD','YELLOW')) as yellow_cards,
    count(*) filter (where event_code in ('SECONDYELLOW','SECOND_YELLOW','YELLOWREDCARD','YELLOW_RED_CARD')) as second_yellow_cards,
    count(*) filter (where event_code in ('REDCARD','RED_CARD','DIRECTRED','DIRECT_RED')) as red_cards_direct,
    count(*) filter (where event_code in ('YELLOWCARD','YELLOW_CARD','YELLOW','SECONDYELLOW','SECOND_YELLOW','YELLOWREDCARD','YELLOW_RED_CARD','REDCARD','RED_CARD','DIRECTRED','DIRECT_RED')) as card_events
  from analytics.v_events_enriched
  where player_id is not null
  group by season_id, league_id, player_id
) s;

create unique index if not exists mv_player_season_cards_pk
  on analytics.mv_player_season_cards (season_id, league_id, player_id);

drop materialized view if exists analytics.mv_team_season_stat_by_code;
create materialized view analytics.mv_team_season_stat_by_code as
select
  season_id,
  league_id,
  team_id,
  stat_code,
  count(distinct fixture_id) as matches,
  sum(coalesce(value_numeric, 0)) as total_value,
  round(sum(coalesce(value_numeric, 0)) / nullif(count(distinct fixture_id), 0), 3) as avg_per_match
from analytics.v_stats_enriched
group by season_id, league_id, team_id, stat_code;

create unique index if not exists mv_team_season_stat_by_code_pk
  on analytics.mv_team_season_stat_by_code (season_id, league_id, team_id, stat_code);

-- 5) Public thin views (stable names for consumers)
create or replace view analytics.team_season_cards as select * from analytics.mv_team_season_cards;
create or replace view analytics.player_season_cards as select * from analytics.mv_player_season_cards;
create or replace view analytics.team_season_stat_by_code as select * from analytics.mv_team_season_stat_by_code;

-- 6) Refresh orchestration
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
end;
$$;

-- Daily refresh at 04:50 UTC
select cron.schedule(
  'analytics_refresh_daily',
  '50 4 * * *',
  $$ select analytics.refresh_analytics(); $$
);

-- Initial populate
refresh materialized view analytics.mv_team_season_cards;
refresh materialized view analytics.mv_player_season_cards;
refresh materialized view analytics.mv_team_season_stat_by_code;


