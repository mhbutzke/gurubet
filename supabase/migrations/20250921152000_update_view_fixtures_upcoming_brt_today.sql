-- Update view: analytics.v_fixtures_upcoming
-- Ajustes:
-- - Remover starting_at
-- - Manter somente jogos de HOJE (BRT)
-- - starting_at_brt formatado como texto 'DD-MM-YYYY HH24:MI'
-- - Nomes dos times com detecção robusta de home/away

drop view if exists analytics.v_fixtures_upcoming;

create or replace view analytics.v_fixtures_upcoming as
with ctx as (
  select (now() at time zone 'America/Sao_Paulo')::date as d_brt
),
targets as (
  select f.id as fixture_id, f.name, f.starting_at, f.league_id, l.name as league_name, f.season_id, s.name as season_name
  from public.fixtures f
  join ctx on date(f.starting_at at time zone 'America/Sao_Paulo') = ctx.d_brt
  left join public.leagues l on l.id = f.league_id
  left join public.seasons s on s.id = f.season_id
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
team_names as (
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
         sum(ce.pts) filter (where coalesce(ce.minute,0) <= 45) as pts_1h
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
hist_team_matches as (
  select fp.fixture_id, fp.participant_id as team_id, f.season_id, f.league_id
  from public.fixture_participants fp
  join public.fixtures f on f.id = fp.fixture_id
  where f.starting_at < now()
),
team_avgs as (
  select h.team_id, h.season_id, h.league_id,
         avg(coalesce(ptf.pts_total,0)) as it1_all,
         avg(coalesce(pft.pts_total,0) - coalesce(ptf.pts_total,0)) as it2_all,
         avg(coalesce(ptf.pts_1h,0)) as it1_1h,
         avg(coalesce(pft.pts_1h,0) - coalesce(ptf.pts_1h,0)) as it2_1h,
         count(*) as games
  from hist_team_matches h
  left join pts_team_fixture ptf on ptf.fixture_id = h.fixture_id and ptf.team_id = h.team_id
  left join pts_fixture_total pft on pft.fixture_id = h.fixture_id
  group by h.team_id, h.season_id, h.league_id
),
main_referee as (
  select distinct on (fr.fixture_id)
         fr.fixture_id, fr.referee_id
  from public.fixture_referees fr
  order by fr.fixture_id, fr.referee_id
),
ref_recent as (
  select fr.referee_id, f.id as fixture_id, f.starting_at,
         row_number() over(partition by fr.referee_id order by f.starting_at desc) as rn
  from public.fixture_referees fr
  join public.fixtures f on f.id = fr.fixture_id
  where f.starting_at < now()
),
ref_last50 as (
  select rr.referee_id,
         avg(pft.pts_total::numeric) as ref_t,
         avg(pft.pts_1h::numeric) as ref_t_1h,
         count(*) as games
  from ref_recent rr
  left join pts_fixture_total pft on pft.fixture_id = rr.fixture_id
  where rr.rn <= 50
  group by rr.referee_id
),
ref_league_season as (
  select f.season_id, f.league_id, fr.referee_id,
         avg(pft.pts_total::numeric) as ref_t,
         avg(pft.pts_1h::numeric) as ref_t_1h,
         count(*) as games
  from public.fixture_referees fr
  join public.fixtures f on f.id = fr.fixture_id
  left join pts_fixture_total pft on pft.fixture_id = f.id
  group by f.season_id, f.league_id, fr.referee_id
)
select
  tgt.fixture_id as id,
  tgt.name,
  to_char((tgt.starting_at at time zone 'America/Sao_Paulo'), 'DD-MM-YYYY HH24:MI') as starting_at_brt,
  tgt.league_id,
  tgt.league_name,
  tgt.season_name,
  -- Team names
  tn.home_team_name,
  coalesce(ta_h.it1_all,0)::numeric(10,2) as home_it1,
  coalesce(ta_h.it2_all,0)::numeric(10,2) as home_it2,
  (coalesce(ta_h.it1_all,0) + coalesce(ta_h.it2_all,0))::numeric(10,2) as home_t,
  coalesce(ta_h.it1_1h,0)::numeric(10,2) as home_it1_1h,
  coalesce(ta_h.it2_1h,0)::numeric(10,2) as home_it2_1h,
  (coalesce(ta_h.it1_1h,0) + coalesce(ta_h.it2_1h,0))::numeric(10,2) as home_t_1h,
  (to_char(coalesce(ta_h.it1_all,0)::numeric(10,2), 'FM999990.00') || ' - ' || to_char(coalesce(ta_h.it2_all,0)::numeric(10,2), 'FM999990.00')) as home_diff,
  (to_char(coalesce(ta_h.it1_1h,0)::numeric(10,2), 'FM999990.00') || ' - ' || to_char(coalesce(ta_h.it2_1h,0)::numeric(10,2), 'FM999990.00')) as home_diff_1h,
  coalesce(ta_h.games,0) as home_j,
  tn.away_team_name,
  coalesce(ta_a.it1_all,0)::numeric(10,2) as away_it1,
  coalesce(ta_a.it2_all,0)::numeric(10,2) as away_it2,
  (coalesce(ta_a.it1_all,0) + coalesce(ta_a.it2_all,0))::numeric(10,2) as away_t,
  coalesce(ta_a.it1_1h,0)::numeric(10,2) as away_it1_1h,
  coalesce(ta_a.it2_1h,0)::numeric(10,2) as away_it2_1h,
  (coalesce(ta_a.it1_1h,0) + coalesce(ta_a.it2_1h,0))::numeric(10,2) as away_t_1h,
  (to_char(coalesce(ta_a.it1_all,0)::numeric(10,2), 'FM999990.00') || ' - ' || to_char(coalesce(ta_a.it2_all,0)::numeric(10,2), 'FM999990.00')) as away_diff,
  (to_char(coalesce(ta_a.it1_1h,0)::numeric(10,2), 'FM999990.00') || ' - ' || to_char(coalesce(ta_a.it2_1h,0)::numeric(10,2), 'FM999990.00')) as away_diff_1h,
  coalesce(ta_a.games,0) as away_j,
  -- Referee
  mr.referee_id,
  r.display_name as referee_name,
  coalesce(case when coalesce(rl50.games,0) >= 10 then rl50.ref_t else rls.ref_t end,0)::numeric(10,2) as referee_t,
  coalesce(case when coalesce(rl50.games,0) >= 10 then rl50.ref_t_1h else rls.ref_t_1h end,0)::numeric(10,2) as referee_t_1h,
  coalesce(case when coalesce(rl50.games,0) >= 10 then rl50.games else rls.games end, 0) as referee_j
from targets tgt
left join team_names tn on tn.fixture_id = tgt.fixture_id
left join team_avgs ta_h on ta_h.team_id = tn.home_team_id and ta_h.season_id = tgt.season_id and ta_h.league_id = tgt.league_id
left join team_avgs ta_a on ta_a.team_id = tn.away_team_id and ta_a.season_id = tgt.season_id and ta_a.league_id = tgt.league_id
left join main_referee mr on mr.fixture_id = tgt.fixture_id
left join public.referees r on r.id = mr.referee_id
left join ref_last50 rl50 on rl50.referee_id = mr.referee_id
left join ref_league_season rls on rls.referee_id = mr.referee_id and rls.season_id = tgt.season_id and rls.league_id = tgt.league_id
order by tgt.starting_at;

comment on view analytics.v_fixtures_upcoming is 'Jogos de hoje (BRT) com horário formatado, nomes de times, médias e DIFF/DIFF 1h (exibição).';


