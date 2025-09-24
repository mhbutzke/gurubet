-- Criar somente a MV (sem tocar na view original) e fazer primeiro refresh

create materialized view if not exists analytics.mv_fixtures_upcoming_v2 as
select * from analytics.v_fixtures_upcoming_v2;

create index if not exists mv_upc_v2_id_idx on analytics.mv_fixtures_upcoming_v2 (id);
create index if not exists mv_upc_v2_league_idx on analytics.mv_fixtures_upcoming_v2 (league_id);

-- Primeiro refresh para popular
refresh materialized view analytics.mv_fixtures_upcoming_v2;


