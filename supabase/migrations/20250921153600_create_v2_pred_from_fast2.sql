-- Create robust predictions view based on v2_fast2 and support MVs

create schema if not exists analytics;

drop view if exists analytics.v_fixtures_upcoming_v2_pred;
create view analytics.v_fixtures_upcoming_v2_pred as
with base as (
  select * from analytics.v_fixtures_upcoming_v2_fast2
),
recent as (
  select season_id, league_id, team_id, avg_recent5 from analytics.mv_team_recent5_cards
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
  left join recent rh on rh.season_id = c.season_id and rh.league_id = c.league_id and rh.team_id = c.home_team_id
  left join recent ra on ra.season_id = c.season_id and ra.league_id = c.league_id and ra.team_id = c.away_team_id
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
),
final as (
  select sh.*,
         round((sh.home_pred_full * (coalesce(sh.w_1h_team_share,0.6)*sh.s_home + coalesce(sh.w_1h_ref_share,0.4)*sh.ref_share))::numeric, 2) as home_pred_1h,
         round((sh.away_pred_full * (coalesce(sh.w_1h_team_share,0.6)*sh.s_away + coalesce(sh.w_1h_ref_share,0.4)*sh.ref_share))::numeric, 2) as away_pred_1h
  from shares sh
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
  home_pred_1h, away_pred_1h, round((home_pred_1h+away_pred_1h)::numeric, 2) as total_pred_1h
from final;


