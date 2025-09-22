require('dotenv').config();
const { supabase } = require('../src/supabaseClient');

async function fetchFixturesSample(limit = 20) {
  const token = process.env.SPORTMONKS_API_KEY;
  if (!token) {
    throw new Error('SPORTMONKS_API_KEY not configured in .env');
  }

  const url = new URL('https://api.sportmonks.com/v3/football/fixtures');
  url.searchParams.set('api_token', token);
  url.searchParams.set('per_page', String(limit));

  const response = await fetch(url);
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Sportmonks request failed: ${response.status} ${text}`);
  }

  const payload = await response.json();
  return payload.data ?? [];
}

function mapFixtureForInsert(rawFixture) {
  const nowIso = new Date().toISOString();
  return {
    id: rawFixture.id,
    sport_id: rawFixture.sport_id,
    league_id: rawFixture.league_id,
    season_id: rawFixture.season_id,
    stage_id: rawFixture.stage_id,
    group_id: rawFixture.group_id,
    aggregate_id: rawFixture.aggregate_id,
    round_id: rawFixture.round_id,
    state_id: rawFixture.state_id,
    venue_id: rawFixture.venue_id,
    name: rawFixture.name,
    starting_at: rawFixture.starting_at,
    result_info: rawFixture.result_info,
    leg: rawFixture.leg,
    details: rawFixture.details,
    length: rawFixture.length,
    placeholder: rawFixture.placeholder,
    has_odds: rawFixture.has_odds,
    has_premium_odds: rawFixture.has_premium_odds,
    starting_at_timestamp: rawFixture.starting_at_timestamp,
    updated_at: nowIso,
  };
}

async function upsertFixtures(fixtures) {
  if (!fixtures.length) {
    console.log('Nenhum fixture retornado para inserir.');
    return { count: 0 };
  }

  const payload = fixtures.map(mapFixtureForInsert);
  const { data, error } = await supabase
    .from('fixtures')
    .upsert(payload, { onConflict: 'id' });

  if (error) {
    throw new Error(`Erro ao inserir fixtures: ${error.message}`);
  }

  return { count: data?.length ?? 0 };
}

async function main() {
  try {
    const fixtures = await fetchFixturesSample(20);
    const { count } = await upsertFixtures(fixtures);
    console.log(`Fixtures processados: ${count}`);

    const { data: stored, error: fetchError } = await supabase
      .from('fixtures')
      .select('*')
      .order('starting_at', { ascending: true })
      .limit(1);

    if (fetchError) {
      throw new Error(`Erro ao consultar fixtures inseridos: ${fetchError.message}`);
    }

    if (stored && stored.length) {
      console.log('Exemplo salvo:', JSON.stringify(stored[0], null, 2));
    } else {
      console.log('Nenhum fixture encontrado na tabela após inserção.');
    }
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
}

main();
