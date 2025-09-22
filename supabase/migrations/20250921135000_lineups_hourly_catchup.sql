-- Lineups hourly catch-up fora da janela histórica (BRT 01–08)
-- Executa de hora em hora nos períodos 00–03 e 11–23 UTC (21–24 e 08–20 BRT)

do $$
begin
  perform cron.unschedule('lineups_hourly_catchup');
exception when others then null;
end $$;

select cron.schedule(
  'lineups_hourly_catchup',
  '15 0-3,11-23 * * *',
  $$
    select net.http_post(
      url := 'https://fxydkmfvmpafbdyjuxqv.supabase.co/functions/v1/fixture-enrichment',
      body := jsonb_build_object(
        'limit', 80,
        'mode', 'missing',
        'days_back', 3,
        'days_forward', 0,
        'targets', jsonb_build_array('fixture_lineups','fixture_lineup_details')
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
      )
    );
  $$
);


