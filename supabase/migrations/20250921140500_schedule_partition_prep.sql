-- Agendar preparação de particionamento (coluna fixture_year, triggers, backfill e índices CONCURRENTLY)
-- Janela: 05:30–05:40 UTC (02:30–02:40 BRT)

do $$ begin
  perform cron.unschedule('partition_prep_addcols_events');
  perform cron.unschedule('partition_prep_addcols_statistics');
  perform cron.unschedule('partition_prep_function');
  perform cron.unschedule('partition_prep_trigger_events');
  perform cron.unschedule('partition_prep_trigger_statistics');
  perform cron.unschedule('partition_prep_backfill_events');
  perform cron.unschedule('partition_prep_backfill_statistics');
  perform cron.unschedule('partition_prep_index_events');
  perform cron.unschedule('partition_prep_index_statistics');
exception when others then null; end $$;

-- 05:30 – Add columns (idempotente)
select cron.schedule('partition_prep_addcols_events','30 5 * * *', $$
  alter table if exists public.fixture_events add column if not exists fixture_year int;
$$);

select cron.schedule('partition_prep_addcols_statistics','31 5 * * *', $$
  alter table if exists public.fixture_statistics add column if not exists fixture_year int;
$$);

-- 05:32 – Criar/atualizar função (idempotente)
select cron.schedule('partition_prep_function','32 5 * * *', $$
  create or replace function public.set_fixture_year()
  returns trigger
  language plpgsql as $$
  declare v_year int; begin
    select extract(year from f.starting_at)::int into v_year from public.fixtures f where f.id = new.fixture_id;
    new.fixture_year := v_year; return new;
  end $$;
$$);

-- 05:33 – Triggers (idempotente via DO)
select cron.schedule('partition_prep_trigger_events','33 5 * * *', $$
  do $$ begin
    if not exists (select 1 from pg_trigger where tgname='trg_set_fixture_year_events') then
      create trigger trg_set_fixture_year_events before insert or update of fixture_id on public.fixture_events
      for each row execute function public.set_fixture_year();
    end if; end $$;
$$);

select cron.schedule('partition_prep_trigger_statistics','34 5 * * *', $$
  do $$ begin
    if not exists (select 1 from pg_trigger where tgname='trg_set_fixture_year_statistics') then
      create trigger trg_set_fixture_year_statistics before insert or update of fixture_id on public.fixture_statistics
      for each row execute function public.set_fixture_year();
    end if; end $$;
$$);

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


