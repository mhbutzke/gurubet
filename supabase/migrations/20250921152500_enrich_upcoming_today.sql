-- Função e cron para enriquecer urgentemente os jogos de hoje (ligas alvo) com todos os targets

create or replace function public.enrich_upcoming_today(
  batch_size int default 50
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  processed int := 0;
  rec record;
  got_lock boolean;
begin
  -- Evita concorrência
  got_lock := pg_try_advisory_lock(hashtext('enrich_upcoming_today'));
  if not got_lock then
    return 0;
  end if;

  begin
    for rec in
      with t as (
        select id
        from analytics.v_fixtures_upcoming
      ), ord as (
        select id, row_number() over(order by id) as rn from t
      ), grp as (
        select id, ((rn - 1) / batch_size)::int as g from ord
      )
      select array_agg(id) as ids
      from grp
      group by g
      order by g
    loop
      perform net.http_post(
        url := 'https://fxydkmfvmpafbdyjuxqv.supabase.co/functions/v1/fixture-enrichment',
        body := jsonb_build_object(
          'fixture_ids', rec.ids,
          'targets', jsonb_build_array(
            'fixture_participants','fixture_scores','fixture_periods',
            'fixture_lineups','fixture_lineup_details',
            'fixture_odds','fixture_weather','fixture_referees',
            'fixture_events','fixture_statistics'
          )
        ),
        headers := jsonb_build_object(
          'Content-Type','application/json',
          'Authorization','Bearer ' || current_setting('app.settings.service_role_key', true)
        )
      );
      processed := processed + 1;
      perform pg_sleep(0.2);
    end loop;

    return processed;
  exception when others then
    perform pg_advisory_unlock(hashtext('enrich_upcoming_today'));
    raise;
  end;

  perform pg_advisory_unlock(hashtext('enrich_upcoming_today'));
end;
$$;

-- Cron a cada 10 min durante janela de jogos (BRT ~ 09:00–23:59 => UTC 12–23,0–3)
select cron.schedule(
  'enrichment_upcoming_today_heavy',
  '*/10 12-23,0-3 * * *',
  $$ select public.enrich_upcoming_today(50); $$
);


