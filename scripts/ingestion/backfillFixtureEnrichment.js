#!/usr/bin/env node
require('dotenv').config();
const fetch = global.fetch || require('node-fetch');
const { supabase } = require('../src/supabaseClient');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in environment.');
}

const FUNCTION_URL = `${SUPABASE_URL}/functions/v1/fixture-enrichment`;

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith('--')) continue;
    const key = arg.slice(2);
    const value = argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[i + 1] : 'true';
    args[key] = value;
    if (value !== 'true') i += 1;
  }
  return args;
}

function toISODate(value, fallback) {
  if (!value) return fallback;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new Error(`Invalid date value: ${value}`);
  }
  return date.toISOString();
}

function chunk(array, size) {
  const result = [];
  for (let i = 0; i < array.length; i += size) {
    result.push(array.slice(i, i + size));
  }
  return result;
}

function relationCount(row, relation) {
  const values = row[relation];
  if (!Array.isArray(values) || !values.length) return 0;
  const value = values[0];
  if (value && typeof value.count === 'number') return value.count;
  return 0;
}

async function fetchFixturePage({ startDate, endDate, page, pageSize, ascending }) {
  const from = page * pageSize;
  const to = from + pageSize - 1;
  const orderOpts = { ascending: ascending !== 'false' };

  const query = supabase
    .from('fixtures')
    .select(
      `id, starting_at,
       fixture_participants(count),
       fixture_scores(count),
       fixture_periods(count),
       fixture_lineups(count),
       fixture_lineup_details(count),
       fixture_odds(count),
       fixture_weather(count)`
    )
    .order('starting_at', orderOpts)
    .range(from, to);

  if (startDate) query.gte('starting_at', startDate);
  if (endDate) query.lt('starting_at', endDate);

  const { data, error } = await query;
  if (error) {
    throw new Error(`Failed to fetch fixtures (page ${page}): ${error.message}`);
  }
  return data || [];
}

function needsEnrichment(row, targets) {
  return targets.some((relation) => relationCount(row, relation) === 0);
}

async function invokeEnrichment(ids, targets) {
  const response = await fetch(FUNCTION_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    },
    body: JSON.stringify({ fixture_ids: ids, targets }),
  });

  let body;
  try {
    body = await response.json();
  } catch (error) {
    body = { error: `Failed to parse response: ${error.message}` };
  }

  if (!response.ok) {
    const message = body?.error || response.statusText;
    throw new Error(`Enrichment call failed (${response.status}): ${message}`);
  }
  return body;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const pageSize = Number(args['page-size'] || args.pageSize || 500);
  const chunkSize = Number(args['chunk-size'] || args.chunkSize || 25);
  const sleepMs = Number(args['sleep-ms'] || args.sleepMs || 10000);
  const sleepNoopMs = Number(args['sleep-noop-ms'] || args.sleepNoopMs || Math.max(sleepMs, 10000));
  const maxPages = args['max-pages'] ? Number(args['max-pages']) : Infinity;
  const maxFixtures = args['max-fixtures'] ? Number(args['max-fixtures']) : Infinity;
  const startDate = toISODate(args['start-date'], undefined);
  const endDate = toISODate(args['end-date'], undefined);
  const ascending = args.ascending !== 'false';

  const targets = (args.targets ? args.targets.split(',') : [
    'fixture_participants',
    'fixture_scores',
    'fixture_periods',
    'fixture_lineups',
    'fixture_lineup_details',
    'fixture_weather',
    'fixture_odds',
  ]).map((name) => name.trim()).filter(Boolean);

  console.log('Backfill configuration:', {
    FUNCTION_URL,
    pageSize,
    chunkSize,
    sleepMs,
    maxPages,
    maxFixtures,
    startDate,
    endDate,
    ascending,
    targets,
  });

  let page = 0;
  let totalExamined = 0;
  let totalQueued = 0;
  let totalProcessed = 0;

  while (page < maxPages && totalProcessed < maxFixtures) {
    const batch = await fetchFixturePage({ startDate, endDate, page, pageSize, ascending });
    if (!batch.length) {
      console.log(`No more fixtures in page ${page} — stopping.`);
      break;
    }

    totalExamined += batch.length;
    const toProcess = batch.filter((row) => needsEnrichment(row, targets)).map((row) => row.id);

    if (toProcess.length) {
      totalQueued += toProcess.length;
      console.log(`Page ${page}: ${toProcess.length} fixtures need enrichment.`);

      for (const chunkIds of chunk(toProcess, chunkSize)) {
        if (totalProcessed >= maxFixtures) break;
        const remainingCapacity = maxFixtures - totalProcessed;
        const idsToProcess = remainingCapacity < chunkIds.length
          ? chunkIds.slice(0, remainingCapacity)
          : chunkIds;

        let completed = false;
        let attempts = 0;
        while (!completed) {
          attempts += 1;
          try {
            const result = await invokeEnrichment(idsToProcess, targets);
            if (result && typeof result.message === 'string' && result.message.includes('Already running')) {
              console.log(`  ↺ Concurrency (noop). Waiting ${sleepNoopMs}ms and retrying same chunk (attempt ${attempts})...`);
              await new Promise((r) => setTimeout(r, sleepNoopMs));
              continue;
            }
            totalProcessed += idsToProcess.length;
            console.log(`  → Enriched ${idsToProcess.length} fixtures`, result);
            completed = true;
          } catch (error) {
            console.error(`  ✖ Failed enrichment for fixtures ${idsToProcess.join(', ')}:`, error.message);
            // Pequena espera antes de prosseguir para evitar hot loop em caso de erro transitório
            await new Promise((r) => setTimeout(r, Math.max(2000, sleepMs)));
            completed = true; // não re-tenta automaticamente erros não concorrenciais
          }
        }
        if (sleepMs > 0) {
          await new Promise((resolve) => setTimeout(resolve, sleepMs));
        }
        if (totalProcessed >= maxFixtures) break;
      }
    } else {
      console.log(`Page ${page}: no fixtures missing data.`);
    }

    if (batch.length < pageSize) {
      console.log(`Last page reached (size ${batch.length}).`);
      break;
    }

    page += 1;
  }

  console.log('Backfill finished:', {
    totalExamined,
    totalQueued,
    totalProcessed,
  });
}

main().catch((error) => {
  console.error('Backfill failed:', error);
  process.exit(1);
});
