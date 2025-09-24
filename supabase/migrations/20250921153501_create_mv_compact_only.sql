-- Minimal: create MV compact for upcoming v2 (today BRT) using only materialized sources

create schema if not exists analytics;

create materialized view if not exists analytics.mv_fixtures_upcoming_v2_compact as
with ctx as (
  select (now() at time zone 'America/Sao_Paulo')::date as d_brt
),
targets as (
  select f.id as fixture_id, f.name, f.starting_at, f.league_id, l.name as league_name, f.season_id, s.name as season_name
  from public.fixtures f
  join ctx on date(((f.starting_at at time zone 'UTC') at time zone 'America/Sao_Paulo')) = ctx.d_brt
  left join public.leagues l on l.id = f.league_id
  left join public.seasons s on s.id = f.season_id
  where f.league_id in (648,651,654,636,1122,1116,2,5,8,9,564,462,301,82,743,779)
),
teams as (
  select p.fixture_id,
         max(t.name) filter (where loc = 'home') as home_team_name,
         max(t.name) filter (where loc = 'away') as away_team_name,
         max(case when loc='home' then team_id end) as home_team_id,
         max(case when loc='away' then team_id end) as away_team_id
  from (
    select fp.fixture_id, fp.participant_id as team_id, lower(coalesce(fp.location, fp.meta->>'location')) as loc
    from public.fixture_participants fp
  ) p
  left join public.teams t on t.id = p.team_id
  group by p.fixture_id
)
select
  f.fixture_id as id,
  f.name,
  to_char(((f.starting_at at time zone 'UTC') at time zone 'America/Sao_Paulo'), 'DD-MM-YYYY HH24:MI') as starting_at_brt,
  f.league_id,
  f.league_name,
  f.season_name,
  f.season_id,
  tm.home_team_name,
  tm.away_team_name,
  tm.home_team_id,
  tm.away_team_id,
  -- Team averages from buckets MV
  tb_h.avg_full as home_cards_avg,
  tb_h.avg_1h as home_cards_1h_avg,
  tha.avg_full_home as home_cards_home_avg,
  tb_a.avg_full as away_cards_avg,
  tb_a.avg_1h as away_cards_1h_avg,
  tha_a.avg_full_away as away_cards_away_avg,
  -- Referee from last3 (precomputed)
  fr.referee_id,
  r.display_name as referee_name,
  r3.cards_per_match as referee_cards_avg,
  round((r3.cards_per_match/2.0)::numeric, 3) as referee_cards_1h_avg,
  r3.cards_per_match_home as referee_home_cards_avg,
  r3.cards_per_match_away as referee_away_cards_avg,
  -- H2H
  h2h.cards_avg as h2h_cards_avg
from targets f
join teams tm on tm.fixture_id = f.fixture_id
left join analytics.mv_team_season_card_buckets tb_h on tb_h.season_id = f.season_id and tb_h.league_id = f.league_id and tb_h.team_id = tm.home_team_id
left join analytics.mv_team_season_card_buckets tb_a on tb_a.season_id = f.season_id and tb_a.league_id = f.league_id and tb_a.team_id = tm.away_team_id
left join analytics.mv_team_season_card_home_away tha on tha.season_id = f.season_id and tha.league_id = f.league_id and tha.team_id = tm.home_team_id
left join analytics.mv_team_season_card_home_away tha_a on tha_a.season_id = f.season_id and tha_a.league_id = f.league_id and tha_a.team_id = tm.away_team_id
left join public.fixture_referees fr on fr.fixture_id = f.fixture_id
left join public.referees r on r.id = fr.referee_id
left join analytics.mv_referee_league_last3_avg r3 on r3.league_id = f.league_id and r3.referee_id = fr.referee_id
left join (
  select league_id, team_min, team_max, cards_avg from analytics.mv_h2h_cards_fouls
) h2h on h2h.league_id = f.league_id
      and h2h.team_min = least(tm.home_team_id, tm.away_team_id)
      and h2h.team_max = greatest(tm.home_team_id, tm.away_team_id);

create index if not exists mv_upc_v2_compact_league_idx on analytics.mv_fixtures_upcoming_v2_compact (league_id);
create index if not exists mv_upc_v2_compact_id_idx on analytics.mv_fixtures_upcoming_v2_compact (id);


