-- Cria view leve apontando para a MV e agenda refresh frequente

-- 1) View alias
create or replace view analytics.v_fixtures_upcoming_v2_fast as
select * from analytics.mv_fixtures_upcoming_v2;

-- 2) Índices (se MV já existir)
create index if not exists mv_upc_v2_id_idx on analytics.mv_fixtures_upcoming_v2 (id);
create index if not exists mv_upc_v2_league_idx on analytics.mv_fixtures_upcoming_v2 (league_id);

-- 3) Função de refresh
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

-- 4) Reagenda cron
do $$
begin
  begin
    perform cron.unschedule('analytics_upcoming_v2_refresh');
  exception when others then
    null;
  end;
  perform cron.schedule(
    'analytics_upcoming_v2_refresh',
    '*/10 12-23,0-3 * * *',
    'select analytics.refresh_upcoming_v2();'
  );
end $$;
