const { Pool } = require('pg');
const fetch = require('node-fetch');

const pool = new Pool({
  connectionString: process.env.SUPABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function getFixturesWithoutEventsStats(startYear, endYear, limit = 50, offset = 0) {
  const startDate = new Date(startYear, 0, 1).toISOString();
  const endDate = new Date(endYear + 1, 0, 1).toISOString();
  const query = `
    SELECT id FROM public.fixtures f
    WHERE starting_at >= $1 AND starting_at < $2
      AND (NOT EXISTS (SELECT 1 FROM public.fixture_events WHERE fixture_id = f.id)
           OR NOT EXISTS (SELECT 1 FROM public.fixture_statistics WHERE fixture_id = f.id))
    ORDER BY starting_at ASC
    LIMIT $3 OFFSET $4
  `;
  const { rows } = await pool.query(query, [startDate, endDate, limit, offset]);
  return rows.map(r => r.id);
}

async function enrichFixtures(fixtureIds) {
  const payload = {
    fixtureIds,
    targets: ['events', 'statistics'],
    mode: 'missing'
  };
  const response = await fetch(`${process.env.SUPABASE_URL.replace('/rest/v1', '')}/functions/v1/fixture-enrichment`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(payload)
  });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${await response.text()}`);
  }
  return await response.json();
}

async function backfillEventsStats(startYear = 2023, endYear = 2025, batchSize = 50) {
  let offset = 0;
  let totalProcessed = 0;
  let totalErrors = 0;

  while (true) {
    const fixtureIds = await getFixturesWithoutEventsStats(startYear, endYear, batchSize, offset);
    if (fixtureIds.length === 0) break;

    console.log(`Processing batch ${offset / batchSize + 1}: fixtures ${fixtureIds[0]} to ${fixtureIds[fixtureIds.length - 1]}`);

    try {
      const result = await enrichFixtures(fixtureIds);
      console.log(`Success: ${result.processed || fixtureIds.length} enriched`);
      totalProcessed += fixtureIds.length;
    } catch (error) {
      console.error(`Batch failed: ${error.message}`);
      totalErrors += fixtureIds.length;
    }

    offset += batchSize;
    await new Promise(resolve => setTimeout(resolve, 1000)); // Rate limit
  }

  console.log(`Backfill complete: ${totalProcessed} processed, ${totalErrors} errors`);
  await pool.end();
}

const [,, startYear, endYear] = process.argv;
backfillEventsStats(parseInt(startYear) || 2023, parseInt(endYear) || 2025);
