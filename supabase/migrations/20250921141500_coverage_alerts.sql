-- Alertas de cobertura por ano/target

create table if not exists public.coverage_alerts (
  id bigserial primary key,
  created_at timestamptz not null default now(),
  year int not null,
  target text not null,
  pct numeric(5,2) not null,
  threshold numeric(5,2) not null,
  status text not null default 'under',
  meta jsonb
);

create or replace function public.check_coverage_thresholds()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  rec record;
  -- thresholds por ano
  thresh_2025 numeric := 99.9;
  thresh_2024 numeric := 99.0;
  thresh_2023 numeric := 95.0;
  yr int;
  th numeric;
begin
  for yr in select unnest(array[2023,2024,2025]) loop
    th := case yr when 2025 then thresh_2025 when 2024 then thresh_2024 else thresh_2023 end;

    for rec in
      with f as (
        select id from public.fixtures where starting_at >= make_date(yr,1,1) and starting_at < make_date(yr+1,1,1)
      )
      select 'fixture_participants' as target,
             round(100.0 * count(*) filter (where exists (select 1 from public.fixture_participants fp where fp.fixture_id=f.id)) / nullif(count(*),0), 2) as pct
      from f
      union all
      select 'fixture_scores', round(100.0 * count(*) filter (where exists (select 1 from public.fixture_scores s where s.fixture_id=f.id)) / nullif(count(*),0), 2) from f
      union all
      select 'fixture_periods', round(100.0 * count(*) filter (where exists (select 1 from public.fixture_periods p where p.fixture_id=f.id)) / nullif(count(*),0), 2) from f
      union all
      select 'fixture_lineups', round(100.0 * count(*) filter (where exists (select 1 from public.fixture_lineups l where l.fixture_id=f.id)) / nullif(count(*),0), 2) from f
      union all
      select 'fixture_lineup_details', round(100.0 * count(*) filter (where exists (select 1 from public.fixture_lineup_details d where d.fixture_id=f.id)) / nullif(count(*),0), 2) from f
      union all
      select 'fixture_odds', round(100.0 * count(*) filter (where exists (select 1 from public.fixture_odds o where o.fixture_id=f.id)) / nullif(count(*),0), 2) from f
      union all
      select 'fixture_weather', round(100.0 * count(*) filter (where exists (select 1 from public.fixture_weather w where w.fixture_id=f.id)) / nullif(count(*),0), 2) from f
    loop
      if rec.pct is not null and rec.pct < th then
        insert into public.coverage_alerts(year, target, pct, threshold, status, meta)
        values (yr, rec.target, rec.pct, th, 'under', jsonb_build_object('note','below threshold'));
      end if;
    end loop;
  end loop;

  -- notificação opcional via webhook
  begin
    perform net.http_post(
      url := current_setting('app.settings.alert_webhook', true),
      body := jsonb_build_object('text','Coverage alerts generated', 'time', now()),
      headers := jsonb_build_object('Content-Type','application/json')
    );
  exception when others then
    -- ignore se não configurado
    null;
  end;
end;
$$;

-- Cron diário após snapshot: 05:00 UTC
select cron.schedule('coverage_alerts_daily','0 5 * * *', $$ select public.check_coverage_thresholds(); $$);


