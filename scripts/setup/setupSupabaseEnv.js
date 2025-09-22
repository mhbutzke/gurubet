#!/usr/bin/env node
require('dotenv').config();
const fs = require('fs');
const path = require('path');

const supabaseEnvPath = path.join(__dirname, '../supabase/.env');

const envContent = `SUPABASE_URL=${process.env.SUPABASE_URL}
SUPABASE_SERVICE_ROLE_KEY=${process.env.SUPABASE_SERVICE_ROLE_KEY}
SPORTMONKS_API_KEY=${process.env.SPORTMONKS_API_KEY}

# Configurações específicas para edge functions
SERVICE_ROLE_KEY=${process.env.SUPABASE_SERVICE_ROLE_KEY}

# Configurações opcionais para fixture-enrichment
FIXTURE_ENRICHMENT_LIMIT=100
FIXTURE_ENRICHMENT_BATCH_SIZE=20
FIXTURE_ENRICHMENT_DAYS_BACK=3
FIXTURE_ENRICHMENT_DAYS_FORWARD=1
FIXTURE_ENRICHMENT_INCLUDES=participants,lineups.player,lineups.details,scores,periods,weatherReport,odds

# Rate limiting
SPORTMONKS_RATE_THRESHOLD=50
SPORTMONKS_RATE_WAIT_MS=1000
`;

try {
  fs.writeFileSync(supabaseEnvPath, envContent);
  console.log('✅ Arquivo supabase/.env criado com sucesso!');
  console.log('📁 Localização:', supabaseEnvPath);
  console.log('🔒 Arquivo já está no .gitignore - não será versionado');
  console.log('\n💡 Agora você pode usar:');
  console.log('   source supabase/.env && curl ...');
  console.log('   ou');
  console.log('   env $(cat supabase/.env | xargs) comando...');
} catch (error) {
  console.error('❌ Erro ao criar arquivo:', error.message);
}
