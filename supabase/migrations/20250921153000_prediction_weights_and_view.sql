-- Pesos de previsão por liga e view de projeções

create schema if not exists analytics;

create table if not exists analytics.prediction_weights (
  league_id int not null primary key,
  w_home_all numeric(6,4) not null default 0.35,
  w_home_home numeric(6,4) not null default 0.20,
  w_opp_all numeric(6,4) not null default 0.20,
  w_recent5 numeric(6,4) not null default 0.10,
  w_h2h numeric(6,4) not null default 0.05,
  w_ref numeric(6,4) not null default 0.10,
  m_shrink int not null default 10,
  w_1h_team_share numeric(6,4) not null default 0.60,
  w_1h_ref_share numeric(6,4) not null default 0.40,
  k_knockout numeric(6,4) not null default 0.08,
  k_classico numeric(6,4) not null default 0.05,
  k_title_relegation numeric(6,4) not null default 0.04,
  k_weather numeric(6,4) not null default 0.06,
  updated_at timestamptz not null default timezone('utc', now())
);

-- Linha default (league_id = -1)
insert into analytics.prediction_weights (league_id)
values (-1)
on conflict (league_id) do nothing;

-- View de projeções baseada na view materializada/rápida (se existir), senão cai para a v2 pesada
drop view if exists analytics.v_fixtures_upcoming_v2_pred;
create view analytics.v_fixtures_upcoming_v2_pred as
with base as (
  select * from analytics.v_fixtures_upcoming_v2_fast
  union all
  select * from analytics.v_fixtures_upcoming_v2 where false -- fallback desligado por padrão
),
weights as (
  select b.*, 
         coalesce(w1.w_home_all, w0.w_home_all) as w_home_all,
         coalesce(w1.w_home_home, w0.w_home_home) as w_home_home,
         coalesce(w1.w_opp_all, w0.w_opp_all) as w_opp_all,
         coalesce(w1.w_recent5, w0.w_recent5) as w_recent5,
         coalesce(w1.w_h2h, w0.w_h2h) as w_h2h,
         coalesce(w1.w_ref, w0.w_ref) as w_ref,
         coalesce(w1.m_shrink, w0.m_shrink) as m_shrink,
         coalesce(w1.w_1h_team_share, w0.w_1h_team_share) as w_1h_team_share,
         coalesce(w1.w_1h_ref_share, w0.w_1h_ref_share) as w_1h_ref_share,
         coalesce(w1.k_knockout, w0.k_knockout) as k_knockout,
         coalesce(w1.k_classico, w0.k_classico) as k_classico,
         coalesce(w1.k_title_relegation, w0.k_title_relegation) as k_title_relegation,
         coalesce(w1.k_weather, w0.k_weather) as k_weather
  from base b
  left join analytics.prediction_weights w1 on w1.league_id = b.league_id
  left join analytics.prediction_weights w0 on w0.league_id = -1
),
calc as (
  select w.*,
         greatest(coalesce((w.referee_home_cards_avg) / nullif(w.referee_home_cards_avg + w.referee_away_cards_avg,0), 0.5), 0.0) as ref_home_share,
         -- shrink helper
         (w.m_shrink)::numeric as m
  from weights w
),
pred_full as (
  select c.*,
         -- shrinked components
         ( (c.home_cards_avg*c.home_cards_avg) / nullif(c.home_cards_avg + c.m, 0.01) + (c.m / nullif(c.home_cards_avg + c.m,0.01)) * c.home_cards_avg ) as home_all_shrink,
         ( (c.home_cards_home_avg*c.home_cards_home_avg) / nullif(c.home_cards_home_avg + c.m, 0.01) + (c.m / nullif(c.home_cards_home_avg + c.m,0.01)) * c.home_cards_home_avg ) as home_home_shrink,
         ( (c.away_cards_avg*c.away_cards_avg) / nullif(c.away_cards_avg + c.m, 0.01) + (c.m / nullif(c.away_cards_avg + c.m,0.01)) * c.away_cards_avg ) as opp_all_shrink,
         ( (c.home_cards_recent5_avg*c.home_cards_recent5_avg) / nullif(c.home_cards_recent5_avg + 5, 0.01) + (5 / nullif(c.home_cards_recent5_avg + 5,0.01)) * c.home_cards_avg ) as recent5_shrink,
         ( (c.h2h_cards_avg*c.h2h_cards_avg) / nullif(c.h2h_cards_avg + 4, 0.01) + (4 / nullif(c.h2h_cards_avg + 4,0.01)) * (c.home_cards_avg + c.away_cards_avg) / 2 ) as h2h_shrink
  from calc c
),
pred_full2 as (
  select p.*,
         -- baseline por time
         (p.w_home_all*p.home_cards_avg + p.w_home_home*p.home_cards_home_avg + p.w_opp_all*p.away_cards_avg + p.w_recent5*p.home_cards_recent5_avg + p.w_h2h*p.h2h_cards_avg + p.w_ref*p.referee_cards_avg*p.ref_home_share) as home_base,
         (p.w_home_all*p.away_cards_avg + p.w_home_home*p.away_cards_away_avg + p.w_opp_all*p.home_cards_avg + p.w_recent5*p.away_cards_recent5_avg + p.w_h2h*p.h2h_cards_avg + p.w_ref*p.referee_cards_avg*(1 - p.ref_home_share)) as away_base
  from pred_full p
),
pred_scaled as (
  select p.*,
         (p.referee_cards_avg / nullif(p.home_base + p.away_base, 0.01)) as scale_full,
         round((p.home_base * (p.referee_cards_avg / nullif(p.home_base + p.away_base, 0.01)))::numeric, 2) as home_pred_full,
         round((p.away_base * (p.referee_cards_avg / nullif(p.home_base + p.away_base, 0.01)))::numeric, 2) as away_pred_full
  from pred_full2 p
),
pred_1h as (
  select p.*, 
         coalesce(p.home_cards_1h_avg/nullif(p.home_cards_avg,0.01), 0.5) as team_share_home,
         coalesce(p.away_cards_1h_avg/nullif(p.away_cards_avg,0.01), 0.5) as team_share_away,
         coalesce(p.referee_cards_1h_avg/nullif(p.referee_cards_avg,0.01), 0.5) as ref_share
  from pred_scaled p
),
pred_final as (
  select p.*,
         (p.w_1h_team_share*p.team_share_home + p.w_1h_ref_share*p.ref_share) as s_home,
         (p.w_1h_team_share*p.team_share_away + p.w_1h_ref_share*p.ref_share) as s_away,
         round((p.home_pred_full * (p.w_1h_team_share*p.team_share_home + p.w_1h_ref_share*p.ref_share))::numeric, 2) as home_pred_1h,
         round((p.away_pred_full * (p.w_1h_team_share*p.team_share_away + p.w_1h_ref_share*p.ref_share))::numeric, 2) as away_pred_1h
  from pred_1h p
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
from pred_final;


