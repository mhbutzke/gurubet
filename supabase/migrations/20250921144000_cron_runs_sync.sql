-- Tabela centralizada de execuções de cron + função de sync + agendamento

create table if not exists public.cron_runs (
  id bigserial primary key,
  jobid int not null,
  jobname text not null,
  status text not null,
  start_time timestamptz not null,
  end_time timestamptz,
  duration_ms integer,
  return_message text,
  inserted_at timestamptz not null default now(),
  unique (jobid, start_time)
);

create index if not exists cron_runs_start_time_idx on public.cron_runs using btree (start_time desc);
create index if not exists cron_runs_jobname_idx on public.cron_runs using btree (jobname, start_time desc);

create or replace function public.sync_cron_runs()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted_count integer := 0;
begin
  insert into public.cron_runs (jobid, jobname, status, start_time, end_time, duration_ms, return_message)
  select j.jobid,
         j.jobname,
         d.status,
         d.start_time,
         d.end_time,
         case when d.end_time is not null and d.start_time is not null
              then (extract(epoch from (d.end_time - d.start_time))*1000)::int
              else null end as duration_ms,
         d.return_message
  from cron.job_run_details d
  join cron.job j using(jobid)
  where d.start_time > now() - interval '7 days'
  on conflict (jobid, start_time) do nothing;

  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;

-- Agendar sync a cada 5 minutos
select cron.schedule('cron_runs_sync','*/5 * * * *', $$ select public.sync_cron_runs(); $$);


