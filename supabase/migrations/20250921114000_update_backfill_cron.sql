-- Update backfill cron to use net.http_post and include full targets (including weather/odds/periods)

do $$
begin
  perform cron.unschedule('fixture_enrichment_backfill');
exception when others then
  -- ignore if not exists
  null;
end $$;

select cron.schedule(
  'fixture_enrichment_backfill',
  '*/3 * * * *',
  $$
    select net.http_post(
      url := 'https://fxydkmfvmpafbdyjuxqv.supabase.co/functions/v1/fixture-enrichment',
      body := jsonb_build_object(
        'limit', 30,
        'mode', 'missing',
        'targets', jsonb_build_array(
          'fixture_participants',
          'fixture_scores',
          'fixture_periods',
          'fixture_lineups',
          'fixture_lineup_details',
          'fixture_weather',
          'fixture_odds'
        )
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
      )
    );
  $$
);


