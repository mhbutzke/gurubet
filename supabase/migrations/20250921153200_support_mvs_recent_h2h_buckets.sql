-- Support MVs: team buckets (cards), recent5, and H2H (cards & fouls)

create schema if not exists analytics;

-- 1) Team season card buckets (averages per match)
drop materialized view if exists analytics.mv_team_season_card_buckets;
create materialized view analytics.mv_team_season_card_buckets as
with ev as (
  select f.season_id, f.league_id, fe.fixture_id, fe.participant_id as team_id, fe.minute,
         case
           when upper(coalesce(ct.developer_name, '')) in ('YELLOWCARD','YELLOW_CARD','YELLOW') then 1
           when upper(coalesce(ct.developer_name, '')) in ('SECONDYELLOW','SECOND_YELLOW','YELLOWREDCARD','YELLOW_RED_CARD') then 2
           when upper(coalesce(ct.developer_name, '')) in ('REDCARD','RED_CARD','DIRECTRED','DIRECT_RED') then 2
           else 0
         end as pts
  from public.fixture_events fe
  join public.fixtures f on f.id = fe.fixture_id
  left join public.core_types ct on ct.id = fe.type_id
), agg_fixture as (
  select season_id, league_id, fixture_id, team_id,
         sum(pts) filter (where coalesce(minute,0) <= 15) as pts_0_15,
         sum(pts) filter (where coalesce(minute,0) > 15 and coalesce(minute,0) <= 30) as pts_15_30,
         sum(pts) filter (where coalesce(minute,0) > 30 and coalesce(minute,0) <= 45) as pts_30_45,
         sum(pts) filter (where coalesce(minute,0) <= 45) as pts_1h,
         sum(pts) as pts_full
  from ev
  group by season_id, league_id, fixture_id, team_id
), team_agg as (
  select season_id, league_id, team_id,
         count(distinct fixture_id) as matches,
         coalesce(sum(pts_0_15),0) as pts_0_15,
         coalesce(sum(pts_15_30),0) as pts_15_30,
         coalesce(sum(pts_30_45),0) as pts_30_45,
         coalesce(sum(pts_1h),0) as pts_1h,
         coalesce(sum(pts_full),0) as pts_full
  from agg_fixture
  group by season_id, league_id, team_id
)
select season_id, league_id, team_id, matches,
       round(pts_0_15::numeric / nullif(matches,0), 3) as avg_0_15,
       round(pts_15_30::numeric / nullif(matches,0), 3) as avg_15_30,
       round(pts_30_45::numeric / nullif(matches,0), 3) as avg_30_45,
       round(pts_1h::numeric / nullif(matches,0), 3) as avg_1h,
       round(pts_full::numeric / nullif(matches,0), 3) as avg_full
from team_agg;

create unique index if not exists mv_team_season_card_buckets_pk
  on analytics.mv_team_season_card_buckets (season_id, league_id, team_id);

-- 2) Team recent 5 cards (avg per match)
drop materialized view if exists analytics.mv_team_recent5_cards;
create materialized view analytics.mv_team_recent5_cards as
with ev as (
  select f.season_id, f.league_id, f.id as fixture_id, fp.participant_id as team_id, f.starting_at,
         sum(case
           when upper(coalesce(ct.developer_name, '')) in ('YELLOWCARD','YELLOW_CARD','YELLOW') then 1
           when upper(coalesce(ct.developer_name, '')) in ('SECONDYELLOW','SECOND_YELLOW','YELLOWREDCARD','YELLOW_RED_CARD') then 2
           when upper(coalesce(ct.developer_name, '')) in ('REDCARD','RED_CARD','DIRECTRED','DIRECT_RED') then 2
           else 0
         end) as pts_full
  from public.fixtures f
  join public.fixture_participants fp on fp.fixture_id = f.id
  left join public.fixture_events fe on fe.fixture_id = f.id and fe.participant_id = fp.participant_id
  left join public.core_types ct on ct.id = fe.type_id
  where f.starting_at < now()
  group by f.season_id, f.league_id, f.id, fp.participant_id, f.starting_at
), ranked as (
  select ev.*, row_number() over(partition by league_id, season_id, team_id order by starting_at desc) as rn
  from ev
)
select season_id, league_id, team_id,
       round(avg(pts_full) filter (where rn <= 5), 3) as avg_recent5
from ranked
group by season_id, league_id, team_id;

create unique index if not exists mv_team_recent5_cards_pk
  on analytics.mv_team_recent5_cards (season_id, league_id, team_id);

-- 3) H2H cards & fouls (avg per match) using canonical pair (team_min, team_max)
drop materialized view if exists analytics.mv_h2h_cards_fouls;
create materialized view analytics.mv_h2h_cards_fouls as
with teams as (
  select f.id as fixture_id, f.league_id,
         min(fp.participant_id) as team_min,
         max(fp.participant_id) as team_max
  from public.fixtures f
  join public.fixture_participants fp on fp.fixture_id = f.id
  where f.starting_at < now()
  group by f.id, f.league_id
  having count(*) >= 2
), cards as (
  select t.league_id, t.team_min, t.team_max, t.fixture_id,
         sum(case
           when upper(coalesce(ct.developer_name, '')) in ('YELLOWCARD','YELLOW_CARD','YELLOW') then 1
           when upper(coalesce(ct.developer_name, '')) in ('SECONDYELLOW','SECOND_YELLOW','YELLOWREDCARD','YELLOW_RED_CARD') then 2
           when upper(coalesce(ct.developer_name, '')) in ('REDCARD','RED_CARD','DIRECTRED','DIRECT_RED') then 2
           else 0
         end) as cards_total
  from teams t
  left join public.fixture_events fe on fe.fixture_id = t.fixture_id
  left join public.core_types ct on ct.id = fe.type_id
  group by t.league_id, t.team_min, t.team_max, t.fixture_id
), fouls_fixture as (
  select f.id as fixture_id,
         sum(vse.value_numeric) filter (where lower(vse.stat_code) in ('fouls','fouls_committed','fouls_against','fouls_suffered')) as fouls_total
  from public.fixtures f
  left join analytics.v_stats_enriched vse on vse.fixture_id = f.id
  group by f.id
), agg as (
  select c.league_id, c.team_min, c.team_max,
         count(*) as matches,
         avg(c.cards_total::numeric) as cards_avg,
         avg(coalesce(ff.fouls_total,0)::numeric) as fouls_avg
  from cards c
  left join fouls_fixture ff on ff.fixture_id = c.fixture_id
  group by c.league_id, c.team_min, c.team_max
)
select * from agg;

create unique index if not exists mv_h2h_cards_fouls_pk
  on analytics.mv_h2h_cards_fouls (league_id, team_min, team_max);

-- 4) Refresh helper and cron (light cadence)
create or replace function analytics.refresh_support_mvs()
returns void
language plpgsql
security definer
set search_path = public, analytics
as $$
begin
  refresh materialized view analytics.mv_team_season_card_buckets;
  refresh materialized view analytics.mv_team_recent5_cards;
  refresh materialized view analytics.mv_h2h_cards_fouls;
end;
$$;

do $$
begin
  begin
    perform cron.unschedule('analytics_support_mvs_refresh');
  exception when others then
    null;
  end;
  perform cron.schedule(
    'analytics_support_mvs_refresh',
    '15,45 12-23,0-3 * * *',
    'select analytics.refresh_support_mvs();'
  );
end $$;
