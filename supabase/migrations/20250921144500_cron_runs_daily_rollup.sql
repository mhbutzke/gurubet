-- Agregação diária de cron_runs + limpeza de raw

create table if not exists public.cron_runs_daily (
  day date not null,
  jobname text not null,
  runs int not null,
  succeeded int not null,
  failed int not null,
  mean_duration_ms numeric,
  p95_duration_ms numeric,
  last_start_time timestamptz,
  last_status text,
  inserted_at timestamptz not null default now(),
  primary key (day, jobname)
);

create index if not exists cron_runs_daily_job_day_idx on public.cron_runs_daily using btree (jobname, day desc);

create or replace function public.rollup_cron_runs(target_day date default current_date - 1)
returns integer
language sql
security definer
set search_path = public
as $$
with src as (
  select jobname, status, start_time, coalesce(duration_ms,0) as dur
  from public.cron_runs
  where start_time >= target_day
    and start_time < target_day + 1
), agg as (
  select
    target_day as day,
    jobname,
    count(*) as runs,
    count(*) filter (where status ilike 'succeed%') as succeeded,
    count(*) filter (where status not ilike 'succeed%') as failed,
    avg(dur)::numeric as mean_duration_ms,
    percentile_cont(0.95) within group (order by dur)::numeric as p95_duration_ms,
    max(start_time) as last_start_time,
    (array_agg(status order by start_time desc))[1] as last_status
  from src
  group by jobname
)
insert into public.cron_runs_daily (day, jobname, runs, succeeded, failed, mean_duration_ms, p95_duration_ms, last_start_time, last_status)
select * from agg
on conflict (day, jobname) do update set
  runs = excluded.runs,
  succeeded = excluded.succeeded,
  failed = excluded.failed,
  mean_duration_ms = excluded.mean_duration_ms,
  p95_duration_ms = excluded.p95_duration_ms,
  last_start_time = excluded.last_start_time,
  last_status = excluded.last_status
returning 1;
$$;

create or replace function public.cleanup_cron_runs(retain_days integer default 7)
returns integer
language sql
security definer
set search_path = public
as $$
delete from public.cron_runs
where start_time < now() - make_interval(days => retain_days)
returning 1;
$$;

-- Agendamentos diários
select cron.schedule('cron_runs_rollup_daily','5 0 * * *', $$ select public.rollup_cron_runs(current_date - 1); $$);
select cron.schedule('cron_runs_cleanup_daily','10 0 * * *', $$ select public.cleanup_cron_runs(7); $$);


