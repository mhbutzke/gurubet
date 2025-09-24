-- Materializar a v2 para leituras rápidas e atualizar por cron

-- 1) Cria MV a partir da view existente (cálculo pesado ocorre no refresh, leitura fica instantânea)
drop materialized view if exists analytics.mv_fixtures_upcoming_v2;
create materialized view analytics.mv_fixtures_upcoming_v2 as
select * from analytics.v_fixtures_upcoming_v2;

-- 2) Recria a view v2 como um alias leve para a MV (desabilitado para evitar dependência)
-- drop view if exists analytics.v_fixtures_upcoming_v2;
-- create view analytics.v_fixtures_upcoming_v2 as
-- select * from analytics.mv_fixtures_upcoming_v2;

-- 3) Índices úteis
create index if not exists mv_upc_v2_id_idx on analytics.mv_fixtures_upcoming_v2 (id);
create index if not exists mv_upc_v2_league_idx on analytics.mv_fixtures_upcoming_v2 (league_id);

-- 4) Função de refresh
create or replace function analytics.refresh_upcoming_v2()
returns void
language plpgsql
security definer
set search_path = public, analytics
as $$
begin
  refresh materialized view analytics.mv_fixtures_upcoming_v2;
end;
$$;

-- 5) Cron para refresh frequente durante janela de jogos (mesma janela do enriquecimento)
select cron.schedule(
  'analytics_upcoming_v2_refresh',
  '*/10 12-23,0-3 * * *',
  $$ select analytics.refresh_upcoming_v2(); $$
);
