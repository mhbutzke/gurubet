-- Backfill multi-IDs for fixture_referees (2023–2025) using fixtures/multi with include referees

-- Ensure helpful index
create index if not exists fixture_referees_fixture_idx on public.fixture_referees (fixture_id);

create or replace function public.backfill_referees_multi(
  year_from int,
  year_to int,
  batch_size int default 10,
  max_batches int default 500
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  processed int := 0;
  rec record;
  d1 date := make_date(year_from, 1, 1);
  d2 date := make_date(year_to + 1, 1, 1);
begin
  for rec in
    with f as (
      select id
      from public.fixtures
      where starting_at >= d1 and starting_at < d2
      except
      select fixture_id from public.fixture_referees
    ), ord as (
      select id, row_number() over(order by id) as rn from f
    ), grp as (
      select id, ((rn - 1) / batch_size)::int as g from ord
    )
    select array_agg(id) as ids
    from grp
    group by g
    order by g
    limit max_batches
  loop
    perform net.http_post(
      url := 'https://fxydkmfvmpafbdyjuxqv.supabase.co/functions/v1/fixture-enrichment',
      body := jsonb_build_object(
        'fixture_ids', rec.ids,
        'targets', jsonb_build_array('fixture_referees')
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
end;
$$;


