-- Expandir profundidade histórica: incluir days_back amplo (6000) nos jobs de enriquecimento e guards

do $$
begin
  perform cron.unschedule('enrichment_historic_window');
  perform cron.unschedule('guard_coverage_2023');
  perform cron.unschedule('guard_coverage_2024');
  perform cron.unschedule('guard_coverage_2025');
exception when others then null;
end $$;

-- Recriar janela histórica com days_back amplo
select cron.schedule(
  'enrichment_historic_window',
  '*/5 4-10 * * *',
  $$
    select net.http_post(
      url := 'https://fxydkmfvmpafbdyjuxqv.supabase.co/functions/v1/fixture-enrichment',
      body := jsonb_build_object(
        'limit', 800,
        'mode', 'missing',
        'days_back', 6000,
        'days_forward', 0,
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

-- Recriar guards incluindo days_back amplo
select cron.schedule(
  'guard_coverage_2025',
  '*/10 4-10 * * *',
  $$
    select net.http_post(
      url := 'https://fxydkmfvmpafbdyjuxqv.supabase.co/functions/v1/fixture-enrichment',
      body := jsonb_build_object(
        'limit', 800,
        'mode', 'missing',
        'days_back', 6000,
        'days_forward', 0,
        'targets', jsonb_build_array('fixture_participants','fixture_scores','fixture_periods','fixture_lineups','fixture_lineup_details','fixture_weather','fixture_odds')
      ),
      headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer ' || current_setting('app.settings.service_role_key', true))
    );
  $$
);

select cron.schedule(
  'guard_coverage_2024',
  '*/10 4-10 * * *',
  $$
    select net.http_post(
      url := 'https://fxydkmfvmpafbdyjuxqv.supabase.co/functions/v1/fixture-enrichment',
      body := jsonb_build_object(
        'limit', 800,
        'mode', 'missing',
        'days_back', 6000,
        'days_forward', 0,
        'targets', jsonb_build_array('fixture_participants','fixture_scores','fixture_periods','fixture_lineups','fixture_lineup_details','fixture_weather','fixture_odds')
      ),
      headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer ' || current_setting('app.settings.service_role_key', true))
    );
  $$
);

select cron.schedule(
  'guard_coverage_2023',
  '*/10 4-10 * * *',
  $$
    select net.http_post(
      url := 'https://fxydkmfvmpafbdyjuxqv.supabase.co/functions/v1/fixture-enrichment',
      body := jsonb_build_object(
        'limit', 800,
        'mode', 'missing',
        'days_back', 6000,
        'days_forward', 0,
        'targets', jsonb_build_array('fixture_participants','fixture_scores','fixture_periods','fixture_lineups','fixture_lineup_details','fixture_weather','fixture_odds')
      ),
      headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer ' || current_setting('app.settings.service_role_key', true))
    );
  $$
);


