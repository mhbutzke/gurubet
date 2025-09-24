-- Refactor: criar MVs compactas e apontar v2_fast para MV leve

create schema if not exists analytics;

-- A) Home/Away por time (1h e full)
drop materialized view if exists analytics.mv_team_season_card_home_away;
create materialized view analytics.mv_team_season_card_home_away as
with ev as (
  select f.season_id, f.league_id, fe.fixture_id, fe.participant_id as team_id,
         lower(coalesce(fp.location, fp.meta->>'location')) as home_away,
         fe.minute,
         case
           when upper(coalesce(ct.developer_name, '')) in ('YELLOWCARD','YELLOW_CARD','YELLOW') then 1
           when upper(coalesce(ct.developer_name, '')) in ('SECONDYELLOW','SECOND_YELLOW','YELLOWREDCARD','YELLOW_RED_CARD') then 2
           when upper(coalesce(ct.developer_name, '')) in ('REDCARD','RED_CARD','DIRECTRED','DIRECT_RED') then 2
           else 0
         end as pts
  from public.fixture_events fe
  join public.fixtures f on f.id = fe.fixture_id
  left join public.fixture_participants fp on fp.fixture_id = fe.fixture_id and fp.participant_id = fe.participant_id
  left join public.core_types ct on ct.id = fe.type_id
), agg_fixture as (
  select season_id, league_id, team_id, home_away, fixture_id,
         sum(pts) filter (where coalesce(minute,0) <= 45) as pts_1h,
         sum(pts) as pts_full
  from ev
  group by season_id, league_id, team_id, home_away, fixture_id
), team_agg as (
  select season_id, league_id, team_id,
         count(distinct case when home_away='home' then fixture_id end) as m_home,
         count(distinct case when home_away='away' then fixture_id end) as m_away,
         sum(case when home_away='home' then pts_1h else 0 end) as pts_1h_home,
         sum(case when home_away='away' then pts_1h else 0 end) as pts_1h_away,
         sum(case when home_away='home' then pts_full else 0 end) as pts_full_home,
         sum(case when home_away='away' then pts_full else 0 end) as pts_full_away
  from agg_fixture
  group by season_id, league_id, team_id
)
select season_id, league_id, team_id,
       round(pts_full_home::numeric / nullif(m_home,0), 3) as avg_full_home,
       round(pts_full_away::numeric / nullif(m_away,0), 3) as avg_full_away,
       round(pts_1h_home::numeric / nullif(m_home,0), 3) as avg_1h_home,
       round(pts_1h_away::numeric / nullif(m_away,0), 3) as avg_1h_away
from team_agg;

create unique index if not exists mv_team_season_card_home_away_pk
  on analytics.mv_team_season_card_home_away (season_id, league_id, team_id);

-- B) Últimas 3 temporadas por liga
drop materialized view if exists analytics.mv_league_last3_seasons;
create materialized view analytics.mv_league_last3_seasons as
with ranked as (
  select f.league_id, f.season_id, max(f.starting_at) as last_game,
         row_number() over(partition by f.league_id order by max(f.starting_at) desc) as rn
  from public.fixtures f
  where f.starting_at < now()
  group by f.league_id, f.season_id
)
select league_id, season_id from ranked where rn <= 3;

create index if not exists mv_last3_league_idx on analytics.mv_league_last3_seasons (league_id);

-- C) Árbitro por liga nas últimas 3 temporadas (usa MV existente por temporada)
drop materialized view if exists analytics.mv_referee_league_last3_avg;
create materialized view analytics.mv_referee_league_last3_avg as
select l3.league_id, rsc.referee_id,
       round(avg(rsc.cards_per_match)::numeric, 3) as cards_per_match,
       round(avg(rsc.cards_per_match_home)::numeric, 3) as cards_per_match_home,
       round(avg(rsc.cards_per_match_away)::numeric, 3) as cards_per_match_away
from analytics.mv_referee_season_cards rsc
join analytics.mv_league_last3_seasons l3 on l3.league_id = rsc.league_id and l3.season_id = rsc.season_id
group by l3.league_id, rsc.referee_id;

create unique index if not exists mv_ref_league_last3_pk
  on analytics.mv_referee_league_last3_avg (league_id, referee_id);

-- D) MV compacta de hoje (BRT) unindo somente fontes materializadas
drop materialized view if exists analytics.mv_fixtures_upcoming_v2_compact;
create materialized view analytics.mv_fixtures_upcoming_v2_compact as
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
  -- Referee from last3
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
join public.fixtures t on t.id = f.fixture_id
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

-- E) Reapontar view rápida para a MV compacta (desabilitado; usaremos v2_fast2 em migração separada)
-- create or replace view analytics.v_fixtures_upcoming_v2_fast as
-- select * from analytics.mv_fixtures_upcoming_v2_compact;

-- F) Refresh helper
create or replace function analytics.refresh_upcoming_v2()
returns void
language plpgsql
security definer
set search_path = public, analytics
as $$
begin
  refresh materialized view analytics.mv_fixtures_upcoming_v2_compact;
end;
$$;
