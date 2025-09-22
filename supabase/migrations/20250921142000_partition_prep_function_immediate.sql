-- Criar/atualizar função e triggers imediatamente (DDL leve)

do $$ begin
  if not exists (select 1 from information_schema.columns where table_schema='public' and table_name='fixture_events' and column_name='fixture_year') then
    alter table public.fixture_events add column fixture_year int;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema='public' and table_name='fixture_statistics' and column_name='fixture_year') then
    alter table public.fixture_statistics add column fixture_year int;
  end if;
end $$;

create or replace function public.set_fixture_year()
returns trigger
language plpgsql as $$
declare v_year int; begin
  select extract(year from f.starting_at)::int into v_year from public.fixtures f where f.id = new.fixture_id;
  new.fixture_year := v_year; return new;
end $$;

do $$ begin
  if not exists (select 1 from pg_trigger where tgname='trg_set_fixture_year_events') then
    create trigger trg_set_fixture_year_events before insert or update of fixture_id on public.fixture_events
    for each row execute function public.set_fixture_year();
  end if;
  if not exists (select 1 from pg_trigger where tgname='trg_set_fixture_year_statistics') then
    create trigger trg_set_fixture_year_statistics before insert or update of fixture_id on public.fixture_statistics
    for each row execute function public.set_fixture_year();
  end if;
end $$;

