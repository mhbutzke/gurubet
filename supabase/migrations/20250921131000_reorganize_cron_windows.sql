-- Reorganização de cron jobs com janelas de histórico (BRT 01:00–08:00 => UTC 04:00–11:00)
-- 1) Desagendar jobs existentes para recriação
do $$
begin
  perform cron.unschedule('fixture_delta_job');
  perform cron.unschedule('fixture_delta_live');
  perform cron.unschedule('fixture_enrichment_daily');
  perform cron.unschedule('fixture_enrichment_hourly');
  perform cron.unschedule('guard_coverage_2025');
exception when others then null;
end $$;

-- 2) Janela histórica diária (UTC 04:00–11:00): prioriza enriquecimento massivo
-- Rodar a cada 5 min durante a janela
select cron.schedule(
  'enrichment_historic_window',
  '*/5 4-10 * * *',
  $$
    select net.http_post(
      url := 'https://fxydkmfvmpafbdyjuxqv.supabase.co/functions/v1/fixture-enrichment',
      body := jsonb_build_object(
        'limit', 800,
        'mode', 'missing',
        'targets', jsonb_build_array(
          'fixture_participants','fixture_scores','fixture_periods',
          'fixture_lineups','fixture_lineup_details','fixture_weather','fixture_odds'
        )
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
      )
    );
  $$
);

-- Guards por ano durante a mesma janela histórica (*/10 min) – 2025, 2024, 2023
select cron.schedule(
  'guard_coverage_2025',
  '*/10 4-10 * * *',
  $$ select public.ensure_coverage_2025(); $$
);

create or replace function public.ensure_coverage_2024()
returns void language plpgsql security definer set search_path=public as $$
declare total_yr bigint; p1 bigint; p2 bigint; p3 bigint; p4 bigint; p5 bigint; pw bigint; po bigint; need boolean := false; begin
  select count(*) into total_yr from public.fixtures where starting_at >= '2024-01-01' and starting_at < '2025-01-01';
  if total_yr = 0 then return; end if;
  select count(*) into p1 from public.fixtures f where starting_at >= '2024-01-01' and starting_at < '2025-01-01' and exists (select 1 from public.fixture_participants x where x.fixture_id=f.id);
  select count(*) into p2 from public.fixtures f where starting_at >= '2024-01-01' and starting_at < '2025-01-01' and exists (select 1 from public.fixture_scores x where x.fixture_id=f.id);
  select count(*) into p3 from public.fixtures f where starting_at >= '2024-01-01' and starting_at < '2025-01-01' and exists (select 1 from public.fixture_periods x where x.fixture_id=f.id);
  select count(*) into p4 from public.fixtures f where starting_at >= '2024-01-01' and starting_at < '2025-01-01' and exists (select 1 from public.fixture_lineups x where x.fixture_id=f.id);
  select count(*) into p5 from public.fixtures f where starting_at >= '2024-01-01' and starting_at < '2025-01-01' and exists (select 1 from public.fixture_lineup_details x where x.fixture_id=f.id);
  select count(*) into pw from public.fixtures f where starting_at >= '2024-01-01' and starting_at < '2025-01-01' and exists (select 1 from public.fixture_weather x where x.fixture_id=f.id);
  select count(*) into po from public.fixtures f where starting_at >= '2024-01-01' and starting_at < '2025-01-01' and exists (select 1 from public.fixture_odds x where x.fixture_id=f.id);
  if (p1::numeric/total_yr) < 0.999 then need := true; end if;
  if (p2::numeric/total_yr) < 0.999 then need := true; end if;
  if (p3::numeric/total_yr) < 0.999 then need := true; end if;
  if (p4::numeric/total_yr) < 0.999 then need := true; end if;
  if (p5::numeric/total_yr) < 0.999 then need := true; end if;
  if (pw::numeric/total_yr) < 0.999 then need := true; end if;
  if (po::numeric/total_yr) < 0.999 then need := true; end if;
  if need then
    perform net.http_post(
      url := 'https://fxydkmfvmpafbdyjuxqv.supabase.co/functions/v1/fixture-enrichment',
      body := jsonb_build_object(
        'limit', 800,
        'mode', 'missing',
        'targets', jsonb_build_array('fixture_participants','fixture_scores','fixture_periods','fixture_lineups','fixture_lineup_details','fixture_weather','fixture_odds')
      ),
      headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer ' || current_setting('app.settings.service_role_key', true))
    );
  end if;
end $$;

select cron.schedule('guard_coverage_2024','*/10 4-10 * * *', $$ select public.ensure_coverage_2024(); $$);

create or replace function public.ensure_coverage_2023()
returns void language plpgsql security definer set search_path=public as $$
declare total_yr bigint; p1 bigint; p2 bigint; p3 bigint; p4 bigint; p5 bigint; pw bigint; po bigint; need boolean := false; begin
  select count(*) into total_yr from public.fixtures where starting_at >= '2023-01-01' and starting_at < '2024-01-01';
  if total_yr = 0 then return; end if;
  select count(*) into p1 from public.fixtures f where starting_at >= '2023-01-01' and starting_at < '2024-01-01' and exists (select 1 from public.fixture_participants x where x.fixture_id=f.id);
  select count(*) into p2 from public.fixtures f where starting_at >= '2023-01-01' and starting_at < '2024-01-01' and exists (select 1 from public.fixture_scores x where x.fixture_id=f.id);
  select count(*) into p3 from public.fixtures f where starting_at >= '2023-01-01' and starting_at < '2024-01-01' and exists (select 1 from public.fixture_periods x where x.fixture_id=f.id);
  select count(*) into p4 from public.fixtures f where starting_at >= '2023-01-01' and starting_at < '2024-01-01' and exists (select 1 from public.fixture_lineups x where x.fixture_id=f.id);
  select count(*) into p5 from public.fixtures f where starting_at >= '2023-01-01' and starting_at < '2024-01-01' and exists (select 1 from public.fixture_lineup_details x where x.fixture_id=f.id);
  select count(*) into pw from public.fixtures f where starting_at >= '2023-01-01' and starting_at < '2024-01-01' and exists (select 1 from public.fixture_weather x where x.fixture_id=f.id);
  select count(*) into po from public.fixtures f where starting_at >= '2023-01-01' and starting_at < '2024-01-01' and exists (select 1 from public.fixture_odds x where x.fixture_id=f.id);
  if (p1::numeric/total_yr) < 0.999 then need := true; end if;
  if (p2::numeric/total_yr) < 0.999 then need := true; end if;
  if (p3::numeric/total_yr) < 0.999 then need := true; end if;
  if (p4::numeric/total_yr) < 0.999 then need := true; end if;
  if (p5::numeric/total_yr) < 0.999 then need := true; end if;
  if (pw::numeric/total_yr) < 0.999 then need := true; end if;
  if (po::numeric/total_yr) < 0.999 then need := true; end if;
  if need then
    perform net.http_post(
      url := 'https://fxydkmfvmpafbdyjuxqv.supabase.co/functions/v1/fixture-enrichment',
      body := jsonb_build_object(
        'limit', 800,
        'mode', 'missing',
        'targets', jsonb_build_array('fixture_participants','fixture_scores','fixture_periods','fixture_lineups','fixture_lineup_details','fixture_weather','fixture_odds')
      ),
      headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer ' || current_setting('app.settings.service_role_key', true))
    );
  end if;
end $$;

select cron.schedule('guard_coverage_2023','*/10 4-10 * * *', $$ select public.ensure_coverage_2023(); $$);

-- 3) Fora da janela histórica, manter delta/live mais leves
select cron.schedule(
  'fixture_delta_job',
  '*/15 0-3,11-23 * * *',
  $$
    select net.http_post(
      url := 'https://fxydkmfvmpafbdyjuxqv.supabase.co/functions/v1/fixture-delta',
      body := jsonb_build_object('limit', 3000, 'daysBack', 1),
      headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer ' || current_setting('app.settings.service_role_key', true))
    );
  $$
);

select cron.schedule(
  'fixture_delta_live',
  '*/5 0-3,11-23 * * *',
  $$
    select net.http_post(
      url := 'https://fxydkmfvmpafbdyjuxqv.supabase.co/functions/v1/fixture-delta',
      body := jsonb_build_object('limit', 800, 'daysBack', 0, 'daysForward', 1),
      headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer ' || current_setting('app.settings.service_role_key', true))
    );
  $$
);


