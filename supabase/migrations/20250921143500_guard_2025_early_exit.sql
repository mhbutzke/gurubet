-- Early-exit no guard 2025 usando MV para evitar chamadas desnecessárias

create or replace function public.ensure_coverage_2025()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  ok boolean := false;
  need_backfill boolean := false;
begin
  -- Checagem rápida: mês corrente na MV deve estar >= 99.9% nos principais alvos
  with cur as (
    select * from public.mv_coverage_by_month_target
    where month = date_trunc('month', now())::date
  )
  select bool_and(pct >= 99.9)
  into ok
  from cur
  where target in ('fixture_participants','fixture_scores','fixture_periods');

  if ok then
    return; -- já adequado; evita net.http_post
  end if;

  -- fallback: manter a lógica existente (disparo de enrichment missing)
  perform net.http_post(
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
end;
$$;


