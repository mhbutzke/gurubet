const fs = require('fs');
require('dotenv').config();
const { supabase } = require('../src/supabaseClient');

async function main() {
  console.log('🔎 Validando cron jobs e execuções recentes...');

  // 1) Cron jobs
  const { data: jobs, error: jobsError } = await supabase
    .from('cron.job')
    .select('jobname, schedule, active')
    .in('jobname', [
      'fixture_delta_job',
      'fixture_delta_live',
      'fixture_enrichment_daily',
      'fixture_enrichment_hourly',
      'fixture_enrichment_backfill',
    ])
    .order('jobname', { ascending: true });

  if (jobsError) {
    console.error('Erro listando cron.job:', jobsError.message);
  } else {
    console.log('\n⏰ Cron Jobs:');
    jobs?.forEach((j) => {
      console.log(`- ${j.jobname.padEnd(28)} ${j.schedule.padEnd(15)} ${j.active ? 'ATIVO' : 'INATIVO'}`);
    });
  }

  // 2) Últimos 20 runs do cron (detalhes)
  const { data: runs, error: runsError } = await supabase
    .from('cron.job_run_details')
    .select('jobid, status, return_message, start_time, end_time')
    .order('start_time', { ascending: false })
    .limit(20);

  if (runsError) {
    console.error('Erro listando cron.job_run_details:', runsError.message);
  } else {
    console.log('\n🧾 Últimos cron job runs:');
    runs?.forEach((r) => {
      const dur = r.end_time && r.start_time
        ? ((new Date(r.end_time) - new Date(r.start_time)) / 1000).toFixed(2)
        : '---';
      console.log(`- jobid=${String(r.jobid).padStart(4)} | ${String(r.status).padEnd(8)} | ${dur}s | ${r.return_message?.slice(0, 80) || ''}`);
    });
  }

  // 3) Últimos runs de ingestão (ingestion_runs)
  const { data: ing, error: ingError } = await supabase
    .from('ingestion_runs')
    .select('entity, status, processed_count, error_message, started_at')
    .order('started_at', { ascending: false })
    .limit(10);

  if (ingError) {
    console.error('Erro lendo ingestion_runs:', ingError.message);
  } else {
    console.log('\n📦 Últimos ingestion_runs:');
    ing?.forEach((row) => {
      console.log(`- ${row.started_at} | ${row.entity.padEnd(20)} | ${String(row.status).padEnd(8)} | processed=${row.processed_count} | ${row.error_message || ''}`);
    });
  }

  // 4) Amostra de métricas HTTP (se houver)
  const { data: lastSuccess, error: lastSuccessErr } = await supabase
    .from('ingestion_runs')
    .select('entity, details, started_at')
    .eq('entity', 'fixture_enrichment')
    .eq('status', 'success')
    .order('started_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (lastSuccess && lastSuccess.details) {
    try {
      const details = typeof lastSuccess.details === 'string'
        ? JSON.parse(lastSuccess.details)
        : lastSuccess.details;
      const http = details?.http ?? [];
      console.log(`\n🌐 HTTP metrics (fixture_enrichment @ ${lastSuccess.started_at}):`);
      http.slice(0, 5).forEach((m, idx) => {
        console.log(`  #${idx + 1} ${m.path} -> ${m.status} in ${m.ms}ms (attempt=${m.attempt})`);
      });
    } catch (e) {
      console.warn('Não foi possível parsear details.http');
    }
  }

  console.log('\n✅ Validação concluída.');
}

if (require.main === module) {
  main().catch((e) => {
    console.error('Erro na validação:', e.message);
    process.exit(1);
  });
}

module.exports = { main };
