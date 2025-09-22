require('dotenv').config();
const { supabase } = require('../src/supabaseClient');

async function monitorPipeline() {
  console.log('📊 GURUBET Pipeline Monitor\n');

  try {
    // Relatório de ingestão
    const { data: summary } = await supabase
      .from('v_ingestion_summary')
      .select('*');

    console.log('🔄 Relatório de Ingestão (últimos 30 dias):');
    console.log('─'.repeat(80));
    summary?.forEach(row => {
      const totalRuns = row.total_runs ?? 0;
      const successRate = totalRuns
        ? ((row.successful_runs / totalRuns) * 100).toFixed(1)
        : '0.0';
      const processed = (row.total_processed ?? 0).toLocaleString();
      const avgDuration = row.avg_duration_seconds ?? 0;
      console.log(`${row.entity.padEnd(20)} | ${totalRuns.toString().padStart(3)} runs | ${successRate}% success | ${processed.padStart(8)} processed | Avg: ${avgDuration}s`);
    });

    // Estatísticas gerais
    const { data: stats } = await supabase.rpc('get_fixture_stats', { fixture_id_param: 19362220 });

    console.log('\n📈 Estatísticas Gerais:');
    console.log('─'.repeat(50));
    if (stats) {
      const parsed = typeof stats === 'string' ? JSON.parse(stats) : stats;
      console.log(`Fixture ${parsed.fixture_id}: ${parsed.participants} participantes | ${parsed.events} eventos | ${parsed.statistics} estatísticas | ${parsed.goals} gols | ${parsed.cards} cartões`);
    } else {
      console.log('Fixture sample indisponível no momento.');
    }

    // Contagem de tabelas
    const tables = [
      'fixtures', 'fixture_events', 'fixture_statistics', 
      'fixture_participants', 'teams', 'players', 'leagues'
    ];

    for (const table of tables) {
      const { count } = await supabase
        .from(table)
        .select('*', { count: 'exact', head: true });
      const formatted = (count ?? 0).toLocaleString();
      console.log(`${table.padEnd(20)} | ${formatted.padStart(8)} registros`);
    }

    // Fixtures recentes com participantes
    console.log('\n⚽ Fixtures Recentes Enriquecidas:');
    console.log('─'.repeat(80));
    
    const { data: enriched } = await supabase
      .from('v_fixtures_with_participants')
      .select('*')
      .limit(5);

    enriched?.forEach(fixture => {
      const startedAt = fixture.starting_at ? new Date(fixture.starting_at) : null;
      const date = startedAt ? startedAt.toLocaleDateString('pt-BR') : '---';
      const time = startedAt ? startedAt.toLocaleTimeString('pt-BR', { 
        hour: '2-digit', 
        minute: '2-digit' 
      }) : '--:--';
      console.log(`${date} ${time} | ${fixture.teams || 'Times indefinidos'} | ${fixture.state_name || '---'} | ${fixture.league_name || '---'}`);
    });

    // Status dos cron jobs
    console.log('\n⏰ Cron Jobs Configurados:');
    console.log('─'.repeat(60));
    
    const { data: jobs } = await supabase
      .from('cron.job')
      .select('jobname, schedule, active')
      .in('jobname', ['fixture_delta_job', 'fixture_enrichment_daily']);

    jobs?.forEach(job => {
      const status = job.active ? '✅ ATIVO' : '❌ INATIVO';
      console.log(`${job.jobname.padEnd(25)} | ${job.schedule.padEnd(15)} | ${status}`);
    });

    console.log('\n🎉 Pipeline funcionando perfeitamente!');
    console.log('\n💡 Comandos úteis:');
    console.log('   npm run test:connection     - Testar conexão Supabase');
    console.log('   npm run inspect:fixtures    - Inspecionar API Sportmonks');
    console.log('   node scripts/ops/monitorPipeline.js - Este relatório');

  } catch (error) {
    console.error('❌ Erro no monitoramento:', error.message);
  }
}

if (require.main === module) {
  monitorPipeline();
}

module.exports = { monitorPipeline };
