-- Split cron histórico em dois grupos (leve/pesado) e criar MV de cobertura + snapshot diário

-- 1) Unschedule antigos para evitar duplicatas
do $$
begin
  perform cron.unschedule('enrichment_historic_window');
  perform cron.unschedule('enrichment_historic_light');
  perform cron.unschedule('enrichment_historic_heavy');
exception when others then null;
end $$;

-- 2) Cron histórico leve (participants, scores, periods) – a cada 5 min na janela 04–10 UTC (01–07 BRT)
select cron.schedule(
  'enrichment_historic_light',
  '*/5 4-10 * * *',
  $$
    select net.http_post(
      url := 'https://fxydkmfvmpafbdyjuxqv.supabase.co/functions/v1/fixture-enrichment',
      body := jsonb_build_object(
        'limit', 1000,
        'mode', 'missing',
        'days_back', 6000,
        'days_forward', 0,
        'targets', jsonb_build_array('fixture_participants','fixture_scores','fixture_periods')
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
      )
    );
  $$
);

-- 3) Cron histórico pesado (lineups, lineup_details, odds, weather) – escalonado 1,6,11... min na mesma janela
select cron.schedule(
  'enrichment_historic_heavy',
  '1-59/5 4-10 * * *',
  $$
    select net.http_post(
      url := 'https://fxydkmfvmpafbdyjuxqv.supabase.co/functions/v1/fixture-enrichment',
      body := jsonb_build_object(
        'limit', 600,
        'mode', 'missing',
        'days_back', 6000,
        'days_forward', 0,
        'targets', jsonb_build_array('fixture_lineups','fixture_lineup_details','fixture_odds','fixture_weather')
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
      )
    );
  $$
);

-- 4) MV de cobertura por mês/target (2023+)
create materialized view if not exists public.mv_coverage_by_month_target as
with f as (
  select id, date_trunc('month', starting_at)::date as month
  from public.fixtures
  where starting_at >= '2023-01-01'
)
select month, 'fixture_participants'::text as target,
       count(*) as total,
       count(*) filter (where exists (select 1 from public.fixture_participants fp where fp.fixture_id = f.id)) as with_count,
       round(100.0 * count(*) filter (where exists (select 1 from public.fixture_participants fp where fp.fixture_id = f.id)) / count(*), 2) as pct
from f group by month
union all
select month, 'fixture_scores',
       count(*),
       count(*) filter (where exists (select 1 from public.fixture_scores fs where fs.fixture_id = f.id)),
       round(100.0 * count(*) filter (where exists (select 1 from public.fixture_scores fs where fs.fixture_id = f.id)) / count(*), 2)
from f group by month
union all
select month, 'fixture_periods',
       count(*),
       count(*) filter (where exists (select 1 from public.fixture_periods p where p.fixture_id = f.id)),
       round(100.0 * count(*) filter (where exists (select 1 from public.fixture_periods p where p.fixture_id = f.id)) / count(*), 2)
from f group by month
union all
select month, 'fixture_lineups',
       count(*),
       count(*) filter (where exists (select 1 from public.fixture_lineups l where l.fixture_id = f.id)),
       round(100.0 * count(*) filter (where exists (select 1 from public.fixture_lineups l where l.fixture_id = f.id)) / count(*), 2)
from f group by month
union all
select month, 'fixture_lineup_details',
       count(*),
       count(*) filter (where exists (select 1 from public.fixture_lineup_details d where d.fixture_id = f.id)),
       round(100.0 * count(*) filter (where exists (select 1 from public.fixture_lineup_details d where d.fixture_id = f.id)) / count(*), 2)
from f group by month
union all
select month, 'fixture_odds',
       count(*),
       count(*) filter (where exists (select 1 from public.fixture_odds o where o.fixture_id = f.id)),
       round(100.0 * count(*) filter (where exists (select 1 from public.fixture_odds o where o.fixture_id = f.id)) / count(*), 2)
from f group by month
union all
select month, 'fixture_weather',
       count(*),
       count(*) filter (where exists (select 1 from public.fixture_weather w where w.fixture_id = f.id)),
       round(100.0 * count(*) filter (where exists (select 1 from public.fixture_weather w where w.fixture_id = f.id)) / count(*), 2)
from f group by month
order by month, target;

-- 5) Tabela de snapshots de cobertura
create table if not exists public.coverage_snapshots (
  id bigserial primary key,
  snapshot_at timestamptz not null default now(),
  month date not null,
  target text not null,
  total integer not null,
  with_count integer not null,
  pct numeric(5,2) not null
);

-- 6) Função para refresh e snapshot
create or replace function public.snapshot_coverage()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  refresh materialized view public.mv_coverage_by_month_target;
  insert into public.coverage_snapshots (month, target, total, with_count, pct)
  select month, target, total, with_count, pct from public.mv_coverage_by_month_target;
end;
$$;

-- 7) Cron diário para snapshot (04:45 UTC)
select cron.schedule(
  'coverage_snapshot_daily',
  '45 4 * * *',
  $$ select public.snapshot_coverage(); $$
);


