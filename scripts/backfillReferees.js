const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function getFixturesWithoutReferees(sinceDate, afterId = 0, limit = 10, maxRetries = 10) {
  let retryCount = 0;
  while (retryCount < maxRetries) {
    try {
      const { data, error } = await supabase.rpc('get_fixtures_missing_referees_paginated', {
        p_since_date: sinceDate,
        p_after_id: afterId,
        p_limit_count: limit
      });
      if (error) throw new Error(`RPC error: ${error.message}`);
      return data || [];
    } catch (error) {
      retryCount++;
      if (retryCount >= maxRetries) throw error;
      console.log(`Retry ${retryCount}/${maxRetries} for getFixtures: ${error.message}`);
      await new Promise(resolve => setTimeout(resolve, 10000 * Math.pow(2, retryCount / 2))); // Longer backoff for worker limit
    }
  }
}

async function enrichFixtures(fixtureIds) {
  const payload = {
    fixtureIds,
    targets: ['referees'],
    mode: 'missing'
  };
  const response = await fetch(`${supabaseUrl.replace('/rest/v1', '')}/functions/v1/fixture-enrichment`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${supabaseKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(payload)
  });
  if (!response.ok) {
    const errorText = await response.text();
    if (errorText.includes('WORKER_LIMIT')) {
      throw new Error(`HTTP ${response.status}: Worker limit exceeded - retrying...`);
    }
    throw new Error(`HTTP ${response.status}: ${errorText}`);
  }
  return await response.json();
}

async function getNewInsertsCount() {
  const { count, error } = await supabase
    .from('fixture_referees')
    .select('*', { count: 'exact', head: true });
  if (error) throw error;
  return count || 0;
}

async function backfillReferees(startYear = 2023, endYear = 2025, batchSize = 10, maxBatches = 2000) {
  const sinceDate = new Date(startYear, 0, 1).toISOString();
  let afterId = 0;
  let totalProcessed = 0;
  let totalErrors = 0;
  let batchNum = 0;
  let initialCount = await getNewInsertsCount();
  console.log(`Initial fixture_referees count: ${initialCount}`);

  while (batchNum < maxBatches) {
    const fixtureIds = await getFixturesWithoutReferees(sinceDate, afterId, batchSize);
    if (fixtureIds.length === 0) {
      console.log('No more fixtures to process.');
      break;
    }

    batchNum++;
    console.log(`Batch ${batchNum}/${maxBatches}: afterId ${afterId}, fixtures ${fixtureIds[0]} to ${fixtureIds[fixtureIds.length - 1]}`);

    let batchSuccess = false;
    let retryBatch = 0;
    while (!batchSuccess && retryBatch < 5) { // Inner retry for batch
      try {
        const result = await enrichFixtures(fixtureIds);
        console.log(`Enrich success: ${result.processed || fixtureIds.length}`);
        const newCount = await getNewInsertsCount();
        console.log(`New inserts this run: ${newCount - initialCount}, total now: ${newCount}`);
        batchSuccess = true;
        totalProcessed += fixtureIds.length;
        afterId = fixtureIds[fixtureIds.length - 1]; // Advance pagination
      } catch (error) {
        retryBatch++;
        console.error(`Batch retry ${retryBatch}/5: ${error.message}`);
        await new Promise(resolve => setTimeout(resolve, 10000)); // 10s delay
      }
    }

    if (!batchSuccess) {
      console.error(`Batch ${batchNum} failed permanently`);
      totalErrors += fixtureIds.length;
      afterId = fixtureIds[fixtureIds.length - 1]; // Still advance to avoid loop
    }

    await new Promise(resolve => setTimeout(resolve, 5000)); // 5s rate limit
  }

  const finalCount = await getNewInsertsCount();
  console.log(`Backfill complete: ${totalProcessed} processed, ${totalErrors} errors. Total fixture_referees now: ${finalCount} (added: ${finalCount - initialCount})`);
}

const [,, startYear, endYear] = process.argv;
backfillReferees(parseInt(startYear) || 2023, parseInt(endYear) || 2025);
