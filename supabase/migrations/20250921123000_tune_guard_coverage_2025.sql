-- Afinar guard_coverage_2025: aumentar limit e rodar a cada 5min

do $$
begin
  perform cron.unschedule('guard_coverage_2025');
exception when others then
  null;
end $$;

create or replace function public.ensure_coverage_2025()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  total_2025 bigint;
  p_participants bigint;
  p_scores bigint;
  p_periods bigint;
  p_lineups bigint;
  p_lineup_details bigint;
  p_weather bigint;
  p_odds bigint;
  need_backfill boolean := false;
begin
  select count(*) into total_2025 from public.fixtures where starting_at >= '2025-01-01' and starting_at < '2026-01-01';
  if total_2025 = 0 then
    return;
  end if;

  select count(*) into p_participants from public.fixtures f where starting_at >= '2025-01-01' and starting_at < '2026-01-01' and exists (select 1 from public.fixture_participants fp where fp.fixture_id = f.id);
  select count(*) into p_scores from public.fixtures f where starting_at >= '2025-01-01' and starting_at < '2026-01-01' and exists (select 1 from public.fixture_scores fs where fs.fixture_id = f.id);
  select count(*) into p_periods from public.fixtures f where starting_at >= '2025-01-01' and starting_at < '2026-01-01' and exists (select 1 from public.fixture_periods p where p.fixture_id = f.id);
  select count(*) into p_lineups from public.fixtures f where starting_at >= '2025-01-01' and starting_at < '2026-01-01' and exists (select 1 from public.fixture_lineups l where l.fixture_id = f.id);
  select count(*) into p_lineup_details from public.fixtures f where starting_at >= '2025-01-01' and starting_at < '2026-01-01' and exists (select 1 from public.fixture_lineup_details d where d.fixture_id = f.id);
  select count(*) into p_weather from public.fixtures f where starting_at >= '2025-01-01' and starting_at < '2026-01-01' and exists (select 1 from public.fixture_weather w where w.fixture_id = f.id);
  select count(*) into p_odds from public.fixtures f where starting_at >= '2025-01-01' and starting_at < '2026-01-01' and exists (select 1 from public.fixture_odds o where o.fixture_id = f.id);

  if (p_participants::numeric / total_2025) < 0.999 then need_backfill := true; end if;
  if (p_scores::numeric / total_2025) < 0.999 then need_backfill := true; end if;
  if (p_periods::numeric / total_2025) < 0.999 then need_backfill := true; end if;
  if (p_lineups::numeric / total_2025) < 0.999 then need_backfill := true; end if;
  if (p_lineup_details::numeric / total_2025) < 0.999 then need_backfill := true; end if;
  if (p_weather::numeric / total_2025) < 0.999 then need_backfill := true; end if;
  if (p_odds::numeric / total_2025) < 0.999 then need_backfill := true; end if;

  if need_backfill then
    perform net.http_post(
      url := 'https://fxydkmfvmpafbdyjuxqv.supabase.co/functions/v1/fixture-enrichment',
      body := jsonb_build_object(
        'limit', 300,
        'mode', 'missing',
        'targets', jsonb_build_array('fixture_participants','fixture_scores','fixture_periods','fixture_lineups','fixture_lineup_details','fixture_weather','fixture_odds')
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
      )
    );
  end if;
end$$;

select cron.schedule(
  'guard_coverage_2025',
  '*/5 * * * *',
  $$ select public.ensure_coverage_2025(); $$
);


