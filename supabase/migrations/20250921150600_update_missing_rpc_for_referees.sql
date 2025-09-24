-- Update RPC to include fixture_referees target
create or replace function public.get_fixtures_missing_enrichment(targets text[], limit_count integer DEFAULT 100, since_date timestamptz DEFAULT NULL)
returns table(id bigint)
language sql
as $$
  with base as (
    select f.id, f.starting_at
    from public.fixtures f
    where since_date is null or f.starting_at >= since_date
  )
  select b.id
  from base b
  where
    (array_position(targets, 'fixture_participants') is not null and not exists (select 1 from public.fixture_participants fp where fp.fixture_id = b.id))
    or (array_position(targets, 'fixture_scores') is not null and not exists (select 1 from public.fixture_scores fs where fs.fixture_id = b.id))
    or (array_position(targets, 'fixture_periods') is not null and not exists (select 1 from public.fixture_periods p where p.fixture_id = b.id))
    or (array_position(targets, 'fixture_lineups') is not null and not exists (select 1 from public.fixture_lineups l where l.fixture_id = b.id))
    or (array_position(targets, 'fixture_lineup_details') is not null and not exists (select 1 from public.fixture_lineup_details ld where ld.fixture_id = b.id))
    or (array_position(targets, 'fixture_odds') is not null and not exists (select 1 from public.fixture_odds o where o.fixture_id = b.id))
    or (array_position(targets, 'fixture_weather') is not null and not exists (select 1 from public.fixture_weather w where w.fixture_id = b.id))
    or (array_position(targets, 'fixture_referees') is not null and not exists (select 1 from public.fixture_referees r where r.fixture_id = b.id))
  order by b.starting_at asc, b.id asc
  limit limit_count;
$$;
