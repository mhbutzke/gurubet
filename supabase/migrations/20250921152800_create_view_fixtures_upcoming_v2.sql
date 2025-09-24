-- Create V2 view: analytics.v_fixtures_upcoming_v2
-- Jogos do dia (BRT) nas ligas selecionadas, com métricas avançadas p/ cartões

create or replace view analytics.v_fixtures_upcoming_v2 as
with ctx as (
  select (now() at time zone 'America/Sao_Paulo')::date as d_brt
),
targets as (
  select f.id as fixture_id, f.name, f.starting_at, f.league_id, l.name as league_name,
         f.season_id, s.name as season_name, f.stage_id, f.round_id
  from public.fixtures f
  join ctx on date(((f.starting_at at time zone 'UTC') at time zone 'America/Sao_Paulo')) = ctx.d_brt
  left join public.leagues l on l.id = f.league_id
  left join public.seasons s on s.id = f.season_id
  where f.league_id in (
    648, 651, 654,
    636,
    1122, 1116,
    2, 5,
    8, 9,
    564,
    462,
    301,
    82,
    743,
    779
  )
),
stages as (
  select id, name from public.stages
),
rounds as (
  select id, name from public.rounds
),
participants as (
  select fp.fixture_id,
         fp.participant_id as team_id,
         case
           when lower(coalesce(fp.location, fp.meta->>'location')) in ('home','local','home_team') then 'home'
           when lower(coalesce(fp.location, fp.meta->>'location')) in ('away','visitor','away_team') then 'away'
           when lower(coalesce(fp.meta->>'home','')) in ('true','t','1') then 'home'
           when lower(coalesce(fp.meta->>'away','')) in ('true','t','1') then 'away'
           else null
         end as loc
  from public.fixture_participants fp
),
teams as (
  select p.fixture_id,
         max(t.name) filter (where p.loc = 'home') as home_team_name,
         max(t.name) filter (where p.loc = 'away') as away_team_name,
         max(case when p.loc = 'home' then p.team_id end) as home_team_id,
         max(case when p.loc = 'away' then p.team_id end) as away_team_id
  from participants p
  left join public.teams t on t.id = p.team_id
  group by p.fixture_id
),
card_events as (
  select fe.fixture_id,
         fe.participant_id as team_id,
         fe.minute,
         case
           when upper(coalesce(ct.developer_name, '')) in ('YELLOWCARD','YELLOW_CARD','YELLOW') then 1
           when upper(coalesce(ct.developer_name, '')) in ('REDCARD','RED_CARD','DIRECTRED','DIRECT_RED','SECONDYELLOW','SECOND_YELLOW','YELLOWREDCARD','YELLOW_RED_CARD') then 2
           else 0
         end as pts
  from public.fixture_events fe
  left join public.core_types ct on ct.id = fe.type_id
),
pts_team_fixture as (
  select ce.fixture_id, ce.team_id,
         sum(ce.pts) as pts_total,
         sum(ce.pts) filter (where coalesce(ce.minute,0) <= 45) as pts_1h,
         sum(ce.pts) filter (where coalesce(ce.minute,0) > 0 and coalesce(ce.minute,0) <= 15) as pts_0_15,
         sum(ce.pts) filter (where coalesce(ce.minute,0) > 15 and coalesce(ce.minute,0) <= 30) as pts_15_30,
         sum(ce.pts) filter (where coalesce(ce.minute,0) > 30 and coalesce(ce.minute,0) <= 45) as pts_30_45
  from card_events ce
  group by ce.fixture_id, ce.team_id
),
pts_fixture_total as (
  select fixture_id,
         sum(pts_total) as pts_total,
         sum(pts_1h) as pts_1h
  from pts_team_fixture
  group by fixture_id
),
hist_all as (
  -- histórico por time na mesma liga/temporada
  select fp.participant_id as team_id, f.id as fixture_id, f.season_id, f.league_id, f.starting_at
  from public.fixture_participants fp
  join public.fixtures f on f.id = fp.fixture_id
  where f.starting_at < now()
),
hist_with_loc as (
  select h.team_id, h.fixture_id, h.season_id, h.league_id,
         lower(coalesce(fp.location, fp.meta->>'location')) as loc
  from hist_all h
  left join public.fixture_participants fp
    on fp.fixture_id = h.fixture_id and fp.participant_id = h.team_id
),
team_avgs as (
  -- médias de cartões tomadas/provocadas + buckets e jogos
  select h.team_id, h.season_id, h.league_id,
         avg(coalesce(ptf.pts_total,0)) as it1_all,
         avg(coalesce(pft.pts_total,0) - coalesce(ptf.pts_total,0)) as it2_all,
         avg(coalesce(ptf.pts_1h,0)) as it1_1h,
         avg(coalesce(pft.pts_1h,0) - coalesce(ptf.pts_1h,0)) as it2_1h,
         avg(coalesce(ptf.pts_0_15,0)) as it1_0_15,
         avg(coalesce(ptf.pts_15_30,0)) as it1_15_30,
         avg(coalesce(ptf.pts_30_45,0)) as it1_30_45,
         count(*) as games
  from hist_all h
  left join pts_team_fixture ptf on ptf.fixture_id = h.fixture_id and ptf.team_id = h.team_id
  left join pts_fixture_total pft on pft.fixture_id = h.fixture_id
  group by h.team_id, h.season_id, h.league_id
),
team_home_away_avgs as (
  select h.team_id, h.season_id, h.league_id,
         avg(coalesce(ptf.pts_total,0)) filter (where h.loc = 'home') as it1_home,
         avg(coalesce(ptf.pts_total,0)) filter (where h.loc = 'away') as it1_away
  from hist_with_loc h
  left join pts_team_fixture ptf on ptf.fixture_id = h.fixture_id and ptf.team_id = h.team_id
  group by h.team_id, h.season_id, h.league_id
),
-- últimas 5 partidas por time (forma recente)
hist_rank as (
  select h.team_id, h.league_id, h.season_id, h.fixture_id,
         row_number() over(partition by h.team_id, h.league_id, h.season_id order by h.starting_at desc) as rn
  from hist_all h
),
recent5 as (
  select hr.team_id, hr.season_id, hr.league_id,
         avg(coalesce(ptf.pts_total,0)) as it1_recent5
  from hist_rank hr
  left join pts_team_fixture ptf on ptf.fixture_id = hr.fixture_id and hr.rn <= 5
  where hr.rn <= 5
  group by hr.team_id, hr.season_id, hr.league_id
),
-- estatísticas de faltas (time) usando analytics.v_stats_enriched
team_fouls as (
  select vse.team_id, f.season_id, f.league_id,
         avg(vse.value_numeric) filter (where lower(vse.stat_code) in ('fouls','fouls_committed')) as fouls_committed_avg,
         avg(vse.value_numeric) filter (where lower(vse.stat_code) in ('fouls_drawn','fouls_suffered','fouls_against')) as fouls_suffered_avg
  from analytics.v_stats_enriched vse
  join public.fixtures f on f.id = vse.fixture_id
  where f.starting_at < now()
  group by vse.team_id, f.season_id, f.league_id
),
-- árbitro: últimas 3 temporadas na mesma liga
league_season_rank as (
  select f.league_id, f.season_id, max(f.starting_at) as last_game,
         row_number() over(partition by f.league_id order by max(f.starting_at) desc) as rn
  from public.fixtures f
  where f.starting_at < now()
  group by f.league_id, f.season_id
),
last3 as (
  select league_id, season_id from league_season_rank where rn <= 3
),
ref_last3 as (
  select f.league_id, fr.referee_id,
         avg(pft.pts_total::numeric) as ref_t,
         avg(pft.pts_1h::numeric) as ref_t_1h,
         count(*) as games
  from public.fixture_referees fr
  join public.fixtures f on f.id = fr.fixture_id
  join last3 l3 on l3.league_id = f.league_id and l3.season_id = f.season_id
  left join pts_fixture_total pft on pft.fixture_id = f.id
  where f.starting_at < now()
  group by f.league_id, fr.referee_id
),
-- viés home/away do árbitro (cartões para mandantes vs visitantes)
ref_bias as (
  select f.league_id, fr.referee_id,
         avg(ptf.pts_total::numeric) filter (where lower(coalesce(fp.location, fp.meta->>'location')) = 'home') as ref_home_cards_avg,
         avg(ptf.pts_total::numeric) filter (where lower(coalesce(fp.location, fp.meta->>'location')) = 'away') as ref_away_cards_avg
  from public.fixture_referees fr
  join public.fixtures f on f.id = fr.fixture_id
  join public.fixture_participants fp on fp.fixture_id = f.id
  left join pts_team_fixture ptf on ptf.fixture_id = f.id and ptf.team_id = fp.participant_id
  where f.starting_at < now()
  group by f.league_id, fr.referee_id
),
-- faltas por árbitro (média por partida somando as duas equipes)
ref_fouls_match as (
  select fr.referee_id, f.league_id, f.id as fixture_id,
         sum(vse.value_numeric) as fouls_total
  from public.fixture_referees fr
  join public.fixtures f on f.id = fr.fixture_id
  join analytics.v_stats_enriched vse on vse.fixture_id = f.id
  where lower(vse.stat_code) in ('fouls','fouls_committed','fouls_against','fouls_suffered')
    and f.starting_at < now()
  group by fr.referee_id, f.league_id, f.id
),
ref_fouls as (
  select league_id, referee_id, avg(fouls_total) as fouls_per_match_avg
  from ref_fouls_match
  group by league_id, referee_id
),
-- H2H: fixtures passadas entre os dois times (mesma liga)
h2h as (
  select t.fixture_id, tm.home_team_id, tm.away_team_id
  from targets t
  join teams tm on tm.fixture_id = t.fixture_id
),
h2h_hist as (
  select x.home_team_id, x.away_team_id, f.id as fixture_id
  from h2h x
  join public.fixture_participants fp1 on fp1.participant_id = x.home_team_id
  join public.fixture_participants fp2 on fp2.participant_id = x.away_team_id and fp2.fixture_id = fp1.fixture_id
  join public.fixtures f on f.id = fp1.fixture_id
  where f.starting_at < now() and f.league_id in (select league_id from targets)
),
h2h_cards as (
  select hh.home_team_id, hh.away_team_id,
         avg(pft.pts_total::numeric) as h2h_cards_avg
  from h2h_hist hh
  left join pts_fixture_total pft on pft.fixture_id = hh.fixture_id
  group by hh.home_team_id, hh.away_team_id
),
h2h_fouls_match as (
  select hh.home_team_id, hh.away_team_id, f.id as fixture_id,
         sum(vse.value_numeric) as fouls_total
  from h2h_hist hh
  join public.fixtures f on f.id = hh.fixture_id
  join analytics.v_stats_enriched vse on vse.fixture_id = hh.fixture_id
  where lower(vse.stat_code) in ('fouls','fouls_committed','fouls_against','fouls_suffered')
  group by hh.home_team_id, hh.away_team_id, f.id
),
h2h_fouls as (
  select home_team_id, away_team_id, avg(fouls_total) as h2h_fouls_avg
  from h2h_fouls_match
  group by home_team_id, away_team_id
)
select
  -- Identificação
  tgt.fixture_id as id,
  tgt.name,
  to_char(((tgt.starting_at at time zone 'UTC') at time zone 'America/Sao_Paulo'), 'DD-MM-YYYY HH24:MI') as starting_at_brt,
  tgt.league_id,
  tgt.league_name,
  tgt.season_name,
  st.name as stage_name,
  rd.name as round_name,
  -- Times
  tm.home_team_name,
  tm.away_team_name,
  -- Estatísticas dos times (médias liga/temporada)
  coalesce(tavg_h.it1_all,0)::numeric(10,2) as home_cards_avg,
  coalesce(tavg_h.it1_1h,0)::numeric(10,2) as home_cards_1h_avg,
  coalesce(thaw.it1_home,0)::numeric(10,2) as home_cards_home_avg,
  coalesce(tfa_h.fouls_committed_avg,0)::numeric(10,2) as home_fouls_committed_avg,
  coalesce(tfa_h.fouls_suffered_avg,0)::numeric(10,2) as home_fouls_suffered_avg,
  coalesce(tavg_h.it1_0_15,0)::numeric(10,2) as home_cards_0_15_avg,
  coalesce(tavg_h.it1_15_30,0)::numeric(10,2) as home_cards_15_30_avg,
  coalesce(tavg_h.it1_30_45,0)::numeric(10,2) as home_cards_30_45_avg,
  coalesce(r5_h.it1_recent5,0)::numeric(10,2) as home_cards_recent5_avg,
  coalesce(tavg_a.it1_all,0)::numeric(10,2) as away_cards_avg,
  coalesce(tavg_a.it1_1h,0)::numeric(10,2) as away_cards_1h_avg,
  coalesce(thaw_a.it1_away,0)::numeric(10,2) as away_cards_away_avg,
  coalesce(tfa_a.fouls_committed_avg,0)::numeric(10,2) as away_fouls_committed_avg,
  coalesce(tfa_a.fouls_suffered_avg,0)::numeric(10,2) as away_fouls_suffered_avg,
  coalesce(tavg_a.it1_0_15,0)::numeric(10,2) as away_cards_0_15_avg,
  coalesce(tavg_a.it1_15_30,0)::numeric(10,2) as away_cards_15_30_avg,
  coalesce(tavg_a.it1_30_45,0)::numeric(10,2) as away_cards_30_45_avg,
  coalesce(r5_a.it1_recent5,0)::numeric(10,2) as away_cards_recent5_avg,
  -- Árbitro (últimas 3 temporadas na liga)
  mr.referee_id,
  r.display_name as referee_name,
  coalesce(ra3.ref_t,0)::numeric(10,2) as referee_cards_avg,
  coalesce(ra3.ref_t_1h,0)::numeric(10,2) as referee_cards_1h_avg,
  case when coalesce(ra3.ref_t,0) > 0 then round((ra3.ref_t_1h/ra3.ref_t)::numeric, 2) else 0 end as referee_cards_1h_share,
  coalesce(rbias.ref_home_cards_avg,0)::numeric(10,2) as referee_home_cards_avg,
  coalesce(rbias.ref_away_cards_avg,0)::numeric(10,2) as referee_away_cards_avg,
  coalesce(rf.fouls_per_match_avg,0)::numeric(10,2) as referee_fouls_avg,
  -- H2H
  coalesce(h2c.h2h_cards_avg,0)::numeric(10,2) as h2h_cards_avg,
  coalesce(h2f.h2h_fouls_avg,0)::numeric(10,2) as h2h_fouls_avg
from targets tgt
left join stages st on st.id = tgt.stage_id
left join rounds rd on rd.id = tgt.round_id
left join teams tm on tm.fixture_id = tgt.fixture_id
left join team_avgs tavg_h on tavg_h.team_id = tm.home_team_id and tavg_h.season_id = tgt.season_id and tavg_h.league_id = tgt.league_id
left join team_avgs tavg_a on tavg_a.team_id = tm.away_team_id and tavg_a.season_id = tgt.season_id and tavg_a.league_id = tgt.league_id
left join team_home_away_avgs thaw on thaw.team_id = tm.home_team_id and thaw.season_id = tgt.season_id and thaw.league_id = tgt.league_id
left join team_home_away_avgs thaw_a on thaw_a.team_id = tm.away_team_id and thaw_a.season_id = tgt.season_id and thaw_a.league_id = tgt.league_id
left join recent5 r5_h on r5_h.team_id = tm.home_team_id and r5_h.season_id = tgt.season_id and r5_h.league_id = tgt.league_id
left join recent5 r5_a on r5_a.team_id = tm.away_team_id and r5_a.season_id = tgt.season_id and r5_a.league_id = tgt.league_id
left join team_fouls tfa_h on tfa_h.team_id = tm.home_team_id and tfa_h.season_id = tgt.season_id and tfa_h.league_id = tgt.league_id
left join team_fouls tfa_a on tfa_a.team_id = tm.away_team_id and tfa_a.season_id = tgt.season_id and tfa_a.league_id = tgt.league_id
left join public.fixture_referees mr on mr.fixture_id = tgt.fixture_id
left join public.referees r on r.id = mr.referee_id
left join ref_last3 ra3 on ra3.league_id = tgt.league_id and ra3.referee_id = mr.referee_id
left join ref_bias rbias on rbias.league_id = tgt.league_id and rbias.referee_id = mr.referee_id
left join ref_fouls rf on rf.league_id = tgt.league_id and rf.referee_id = mr.referee_id
left join h2h_cards h2c on h2c.home_team_id = tm.home_team_id and h2c.away_team_id = tm.away_team_id
left join h2h_fouls h2f on h2f.home_team_id = tm.home_team_id and h2f.away_team_id = tm.away_team_id
order by ((tgt.starting_at at time zone 'UTC') at time zone 'America/Sao_Paulo');

comment on view analytics.v_fixtures_upcoming_v2 is 'V2: Jogos do dia (BRT) nas ligas selecionadas com métricas avançadas para cartões, faltas, árbitro, H2H e contexto.';


