require('dotenv').config();

const { supabase } = require('../src/supabaseClient');
const { fetchFixtureDetails } = require('../src/sportmonks');

const runTimestamp = new Date().toISOString();
const DEFAULT_PAGE_SIZE = Number(process.env.FIXTURE_DETAILS_PAGE_SIZE ?? '500');
const DEFAULT_BATCH_SIZE = Number(process.env.FIXTURE_DETAILS_BATCH_SIZE ?? '25');
const UPSERT_CHUNK = Number(process.env.SUPABASE_UPSERT_CHUNK ?? '500');

const args = process.argv.slice(2);

function getArgValue(flag) {
  const index = args.findIndex((arg) => arg === flag || arg.startsWith(`${flag}=`));
  if (index === -1) return null;
  const [key, value] = args[index].split('=');
  if (value) return value;
  return args[index + 1] ?? null;
}

function parseNumber(value, fallback) {
  if (value === null || value === undefined) return fallback;
  const num = Number(value);
  return Number.isFinite(num) ? num : fallback;
}

function chunkArray(items, size) {
  const output = [];
  for (let i = 0; i < items.length; i += size) {
    output.push(items.slice(i, i + size));
  }
  return output;
}

async function upsertRows(table, rows) {
  for (const chunk of chunkArray(rows, UPSERT_CHUNK)) {
    const { error } = await supabase
      .from(table)
      .upsert(chunk, { onConflict: 'id', returning: 'minimal' });
    if (error) {
      throw new Error(`Failed to upsert ${chunk.length} rows into ${table}: ${error.message}`);
    }
  }
}

function mapEvent(event) {
  return {
    id: event.id,
    fixture_id: event.fixture_id,
    period_id: event.period_id ?? null,
    detailed_period_id: event.detailed_period_id ?? null,
    participant_id: event.participant_id ?? null,
    type_id: event.type_id ?? null,
    sub_type_id: event.sub_type_id ?? null,
    coach_id: event.coach_id ?? null,
    player_id: event.player_id ?? null,
    related_player_id: event.related_player_id ?? null,
    player_name: event.player_name ?? null,
    related_player_name: event.related_player_name ?? null,
    result: event.result ?? null,
    info: event.info ?? null,
    addition: event.addition ?? null,
    minute: event.minute ?? null,
    extra_minute: event.extra_minute ?? null,
    injured: event.injured ?? null,
    on_bench: event.on_bench ?? null,
    rescinded: event.rescinded ?? null,
    section: event.section ?? null,
    sort_order: event.sort_order ?? null,
    updated_at: runTimestamp,
  };
}

function extractStatValue(stat) {
  if (!stat || !stat.data) return { numeric: null, text: null };
  const value = stat.data.value ?? stat.data.count ?? stat.data.total ?? null;
  if (value === null || value === undefined) {
    return { numeric: null, text: null };
  }
  if (typeof value === 'number') {
    return { numeric: value, text: String(value) };
  }
  const numeric = Number(value);
  return {
    numeric: Number.isFinite(numeric) ? numeric : null,
    text: String(value),
  };
}

function mapStatistic(stat) {
  const { numeric, text } = extractStatValue(stat);
  return {
    id: stat.id,
    fixture_id: stat.fixture_id,
    participant_id: stat.participant_id ?? null,
    player_id: stat.player_id ?? null,
    type_id: stat.type_id ?? null,
    location: stat.location ?? null,
    value_numeric: numeric,
    value_text: text,
    data: stat.data ?? null,
    type_name: stat.type?.name ?? null,
    type_code: stat.type?.code ?? null,
    stat_group: stat.type?.stat_group ?? null,
    updated_at: runTimestamp,
  };
}

async function main() {
  const limit = parseNumber(getArgValue('--limit'), Infinity);
  const startAfter = parseNumber(getArgValue('--start-after'), 0);
  const pageSize = parseNumber(getArgValue('--page-size'), DEFAULT_PAGE_SIZE);
  const batchSize = parseNumber(getArgValue('--batch-size'), DEFAULT_BATCH_SIZE);
  const includesRaw = getArgValue('--include');
  const filters = getArgValue('--filters');
  const skipEvents = args.includes('--skip-events');
  const skipStats = args.includes('--skip-stats');

  const includes = includesRaw
    ? includesRaw.split(',').map((item) => item.trim()).filter(Boolean)
    : ['events', 'statistics.type'];

  let processedFixtures = 0;
  let processedEvents = 0;
  let processedStats = 0;

  let lastId = startAfter;

  while (processedFixtures < limit) {
    const pageLimit = Math.min(pageSize, limit - processedFixtures);
    const { data, error } = await supabase
      .from('fixtures')
      .select('id')
      .gt('id', lastId)
      .order('id', { ascending: true })
      .limit(pageLimit);

    if (error) {
      throw new Error(`Failed to fetch fixture ids: ${error.message}`);
    }
    if (!data || data.length === 0) {
      console.log('No more fixtures to process.');
      break;
    }

    lastId = data[data.length - 1].id;
    const idList = data.map((row) => row.id);

    for (const batch of chunkArray(idList, batchSize)) {
      if (batch.length === 0) continue;

      const fixtures = await fetchFixtureDetails(batch, { include: includes, filters });
      const eventRows = [];
      const statRows = [];

      fixtures.forEach((fixture) => {
        processedFixtures += 1;
        if (!skipEvents && Array.isArray(fixture.events)) {
          fixture.events.forEach((event) => {
            eventRows.push(mapEvent(event));
          });
        }
        if (!skipStats && Array.isArray(fixture.statistics)) {
          fixture.statistics.forEach((stat) => {
            statRows.push(mapStatistic(stat));
          });
        }
      });

      if (eventRows.length) {
        await upsertRows('fixture_events', eventRows);
        processedEvents += eventRows.length;
      }

      if (statRows.length) {
        await upsertRows('fixture_statistics', statRows);
        processedStats += statRows.length;
      }

      console.log(
        `Processed fixtures ${processedFixtures}/${limit === Infinity ? '∞' : limit} | ` +
          `events: +${eventRows.length} (total ${processedEvents}) | ` +
          `stats: +${statRows.length} (total ${processedStats})`,
      );

      if (processedFixtures >= limit) {
        break;
      }
    }
  }

  console.log('Fixture details ingestion finished.');
  console.log(`Fixtures processed: ${processedFixtures}`);
  if (!skipEvents) console.log(`Events upserted: ${processedEvents}`);
  if (!skipStats) console.log(`Statistics upserted: ${processedStats}`);
}

main().catch((error) => {
  console.error('Fixture details ingestion failed:', error.message);
  process.exit(1);
});
