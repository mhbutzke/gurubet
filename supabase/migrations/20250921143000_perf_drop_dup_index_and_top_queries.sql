-- Remover índice duplicado em fixture_weather e criar visão de top queries

-- 1) Remover UNIQUE duplicado (mantemos a PK fixture_weather_fixture_id_key)
alter table if exists public.fixture_weather drop constraint if exists unique_fixture_weather;

-- 2) pg_stat_statements e visão de top queries
create extension if not exists pg_stat_statements;

create or replace view public.v_top_queries as
select
  queryid,
  calls,
  round(total_exec_time::numeric, 2) as total_ms,
  round(mean_exec_time::numeric, 2)  as mean_ms,
  rows,
  left(query, 1000) as query
from extensions.pg_stat_statements
order by total_exec_time desc
limit 50;


