require('dotenv').config();

async function fetchFixturesSample({ limit = 10 } = {}) {
  const token = process.env.SPORTMONKS_API_KEY;
  if (!token) throw new Error('SPORTMONKS_API_KEY not configured in .env');

  const url = new URL('https://api.sportmonks.com/v3/football/fixtures');
  url.searchParams.set('api_token', token);
  url.searchParams.set('per_page', String(limit));

  const response = await fetch(url);
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Sportmonks request failed: ${response.status} ${body}`);
  }

  const payload = await response.json();
  const fields = new Set();
  for (const fixture of payload.data ?? []) {
    Object.keys(fixture).forEach((key) => fields.add(key));
  }

  return {
    meta: payload.meta ?? null,
    fixtures: payload.data ?? [],
    fieldList: [...fields].sort(),
  };
}

(async () => {
  try {
    const { fixtures, fieldList } = await fetchFixturesSample({ limit: 5 });
    console.log('Campos detectados:', fieldList.join(', '));
    console.log('Exemplo de fixture:', JSON.stringify(fixtures[0], null, 2));
  } catch (error) {
    console.error('Erro ao consultar fixtures:', error.message);
    process.exit(1);
  }
})();
