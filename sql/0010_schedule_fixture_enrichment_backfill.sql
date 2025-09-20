-- Schedule hourly backfill for fixture enrichment (runs every 3 minutes)
select cron.schedule(
  'fixture_enrichment_backfill',
  '*/3 * * * *',
  $$
    select supabase_functions.http_request(
      'https://fxydkmfvmpafbdyjuxqv.supabase.co/functions/v1/fixture-enrichment',
      jsonb_build_object(
        'headers', jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
        ),
        'body', jsonb_build_object(
          'limit', 300,
          'days_back', 6000,
          'days_forward', 0,
          'targets', array[
            'fixture_participants',
            'fixture_scores',
            'fixture_lineups',
            'fixture_lineup_details'
          ]
        )
      )
    );
  $$
);
