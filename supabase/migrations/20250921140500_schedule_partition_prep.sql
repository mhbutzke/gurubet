-- Agendar preparação de particionamento (backfill e índices CONCURRENTLY)
-- Janela: 05:30–05:40 UTC (02:30–02:40 BRT)

do $$ begin
  perform cron.unschedule('partition_prep_addcols_events');
  perform cron.unschedule('partition_prep_addcols_statistics');
  perform cron.unschedule('partition_prep_backfill_events');
  perform cron.unschedule('partition_prep_backfill_statistics');
  perform cron.unschedule('partition_prep_index_events');
  perform cron.unschedule('partition_prep_index_statistics');
exception when others then null; end $$;

-- 05:35 – Backfill (pode levar tempo)
select cron.schedule('partition_prep_backfill_events','35 5 * * *', $$
  update public.fixture_events e set fixture_year = extract(year from f.starting_at)::int
  from public.fixtures f where e.fixture_id = f.id and (e.fixture_year is null or e.fixture_year <> extract(year from f.starting_at)::int);
$$);

select cron.schedule('partition_prep_backfill_statistics','36 5 * * *', $$
  update public.fixture_statistics s set fixture_year = extract(year from f.starting_at)::int
  from public.fixtures f where s.fixture_id = f.id and (s.fixture_year is null or s.fixture_year <> extract(year from f.starting_at)::int);
$$);

-- 05:38 – Índices CONCURRENTLY (não podem estar em bloco de transação)
select cron.schedule('partition_prep_index_events','38 5 * * *', $$
  create index concurrently if not exists fixture_events_year_idx on public.fixture_events (fixture_year);
$$);

select cron.schedule('partition_prep_index_statistics','39 5 * * *', $$
  create index concurrently if not exists fixture_statistics_year_idx on public.fixture_statistics (fixture_year);
$$);


