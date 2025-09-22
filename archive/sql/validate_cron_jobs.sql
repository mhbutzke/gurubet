-- Lista de cron jobs relevantes
select jobid, jobname, schedule, active
from cron.job
where jobname in (
  'fixture_delta_job',
  'fixture_delta_live',
  'fixture_enrichment_daily',
  'fixture_enrichment_hourly',
  'fixture_enrichment_backfill'
)
order by jobname;

-- Últimas execuções detalhadas
select j.jobname,
       d.status,
       d.return_message,
       d.start_time,
       d.end_time,
       round(extract(epoch from (d.end_time - d.start_time))::numeric, 3) as duration_s
from cron.job_run_details d
join cron.job j using (jobid)
where j.jobname in (
  'fixture_delta_job',
  'fixture_delta_live',
  'fixture_enrichment_daily',
  'fixture_enrichment_hourly',
  'fixture_enrichment_backfill'
)
order by d.start_time desc
limit 30;


