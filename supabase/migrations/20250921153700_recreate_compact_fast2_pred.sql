-- Recria MV compacta com colunas necessárias, refaz v2_fast2 e v2_pred

do $$
begin
  begin execute 'drop view if exists analytics.v_fixtures_upcoming_v2_pred'; exception when others then null; end;
  begin execute 'drop view if exists analytics.v_fixtures_upcoming_v2_fast2'; exception when others then null; end;
  begin execute 'drop materialized view if exists analytics.mv_fixtures_upcoming_v2_compact'; exception when others then null; end;
end $$;

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
  tb_h.avg_full as home_cards_avg,
  tb_h.avg_1h as home_cards_1h_avg,
  tha.avg_full_home as home_cards_home_avg,
  tb_a.avg_full as away_cards_avg,
  tb_a.avg_1h as away_cards_1h_avg,
  tha_a.avg_full_away as away_cards_away_avg,
  fr.referee_id,
  r.display_name as referee_name,
  r3.cards_per_match as referee_cards_avg,
  round((r3.cards_per_match/2.0)::numeric, 3) as referee_cards_1h_avg,
  r3.cards_per_match_home as referee_home_cards_avg,
  r3.cards_per_match_away as referee_away_cards_avg,
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

create or replace view analytics.v_fixtures_upcoming_v2_fast2 as
select * from analytics.mv_fixtures_upcoming_v2_compact;

-- Pred view
create or replace view analytics.v_fixtures_upcoming_v2_pred as
with base as (
  select * from analytics.v_fixtures_upcoming_v2_fast2
),
recent_any as (
  select league_id, team_id, round(avg(avg_recent5)::numeric, 3) as avg_recent5
  from analytics.mv_team_recent5_cards
  group by league_id, team_id
),
w as (
  select b.*, 
         coalesce(w1.w_home_all, w0.w_home_all) as w_home_all,
         coalesce(w1.w_home_home, w0.w_home_home) as w_home_home,
         coalesce(w1.w_opp_all, w0.w_opp_all) as w_opp_all,
         coalesce(w1.w_recent5, w0.w_recent5) as w_recent5,
         coalesce(w1.w_h2h, w0.w_h2h) as w_h2h,
         coalesce(w1.w_ref, w0.w_ref) as w_ref,
         coalesce(w1.w_1h_team_share, w0.w_1h_team_share) as w_1h_team_share,
         coalesce(w1.w_1h_ref_share, w0.w_1h_ref_share) as w_1h_ref_share
  from base b
  left join analytics.prediction_weights w1 on w1.league_id = b.league_id
  left join analytics.prediction_weights w0 on w0.league_id = -1
),
calc as (
  select w.*,
         case when (coalesce(w.referee_home_cards_avg,0)+coalesce(w.referee_away_cards_avg,0)) > 0
              then coalesce(w.referee_home_cards_avg,0) / (coalesce(w.referee_home_cards_avg,0)+coalesce(w.referee_away_cards_avg,0))
              else 0.5 end as ref_home_share,
         case when coalesce(w.referee_cards_avg,0) > 0
              then coalesce(w.referee_cards_1h_avg,0) / w.referee_cards_avg
              else 0.5 end as ref_share
  from w
),
bases as (
  select c.*,
         (c.w_home_all*coalesce(c.home_cards_avg,0)
          + c.w_home_home*coalesce(c.home_cards_home_avg,0)
          + c.w_opp_all*coalesce(c.away_cards_avg,0)
          + c.w_recent5*coalesce(rh.avg_recent5,0)
          + c.w_h2h*coalesce(c.h2h_cards_avg,0)
          + c.w_ref*coalesce(c.referee_cards_avg,0)*c.ref_home_share) as home_base,
         (c.w_home_all*coalesce(c.away_cards_avg,0)
          + c.w_home_home*coalesce(c.away_cards_away_avg,0)
          + c.w_opp_all*coalesce(c.home_cards_avg,0)
          + c.w_recent5*coalesce(ra.avg_recent5,0)
          + c.w_h2h*coalesce(c.h2h_cards_avg,0)
          + c.w_ref*coalesce(c.referee_cards_avg,0)*(1 - c.ref_home_share)) as away_base
  from calc c
  left join recent_any rh on rh.league_id = c.league_id and rh.team_id = c.home_team_id
  left join recent_any ra on ra.league_id = c.league_id and ra.team_id = c.away_team_id
),
scaled as (
  select b.*,
         round((coalesce(b.home_base,0) * (coalesce(b.referee_cards_avg,0) / greatest(coalesce(b.home_base,0) + coalesce(b.away_base,0), 0.01)))::numeric, 2) as home_pred_full,
         round((coalesce(b.away_base,0) * (coalesce(b.referee_cards_avg,0) / greatest(coalesce(b.home_base,0) + coalesce(b.away_base,0), 0.01)))::numeric, 2) as away_pred_full
  from bases b
),
shares as (
  select s.*,
         case when coalesce(s.home_cards_avg,0) > 0.01 then least(greatest(coalesce(s.home_cards_1h_avg,0)/nullif(s.home_cards_avg,0), 0), 1) else s.ref_share end as s_home,
         case when coalesce(s.away_cards_avg,0) > 0.01 then least(greatest(coalesce(s.away_cards_1h_avg,0)/nullif(s.away_cards_avg,0), 0), 1) else s.ref_share end as s_away
  from scaled s
)
select 
  id, name, starting_at_brt, league_id, league_name, season_name,
  home_team_name, away_team_name,
  referee_id, referee_name,
  home_cards_avg, home_cards_1h_avg, home_cards_home_avg,
  away_cards_avg, away_cards_1h_avg, away_cards_away_avg,
  referee_cards_avg, referee_cards_1h_avg, referee_home_cards_avg, referee_away_cards_avg,
  h2h_cards_avg,
  home_pred_full, away_pred_full, round((home_pred_full+away_pred_full)::numeric, 2) as total_pred_full,
  round((home_pred_full * (coalesce(w_1h_team_share,0.6)*s_home + coalesce(w_1h_ref_share,0.4)*ref_share))::numeric, 2) as home_pred_1h,
  round((away_pred_full * (coalesce(w_1h_team_share,0.6)*s_away + coalesce(w_1h_ref_share,0.4)*ref_share))::numeric, 2) as away_pred_1h,
  round(((home_pred_full * (coalesce(w_1h_team_share,0.6)*s_home + coalesce(w_1h_ref_share,0.4)*ref_share))
        + (away_pred_full * (coalesce(w_1h_team_share,0.6)*s_away + coalesce(w_1h_ref_share,0.4)*ref_share)))::numeric, 2) as total_pred_1h
from shares;


