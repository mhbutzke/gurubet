require('dotenv').config();
const { supabase } = require('../src/supabaseClient');
const { fetchEntities } = require('../src/sportmonks');

const args = process.argv.slice(2);
let onlyParam = null;
for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  if (arg === '--only' && args[index + 1]) {
    onlyParam = args[index + 1];
    break;
  }
  if (arg.startsWith('--only=')) {
    onlyParam = arg.slice('--only='.length);
    break;
  }
}

const requestedTasks = onlyParam
  ? onlyParam
      .split(',')
      .map((name) => name.trim())
      .filter(Boolean)
  : null;

const CHUNK_SIZE = Number(process.env.SUPABASE_UPSERT_CHUNK ?? '500');
const runTimestamp = new Date().toISOString();

const toFloat = (value) => {
  if (value === null || value === undefined || value === '') return null;
  const num = typeof value === 'number' ? value : parseFloat(value);
  return Number.isFinite(num) ? num : null;
};

const toInt = (value) => {
  if (value === null || value === undefined || value === '') return null;
  const num = typeof value === 'number' ? value : parseInt(value, 10);
  return Number.isFinite(num) ? num : null;
};

const toBool = (value) => {
  if (value === null || value === undefined) return null;
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (['true', 't', '1', 'yes', 'y'].includes(normalized)) return true;
    if (['false', 'f', '0', 'no', 'n'].includes(normalized)) return false;
  }
  return null;
};

const ensure = (set, value) => {
  if (value === null || value === undefined) return null;
  if (!set) return value;
  return set.has(value) ? value : null;
};

function chunkArray(items, size) {
  const chunks = [];
  for (let i = 0; i < items.length; i += size) {
    chunks.push(items.slice(i, i + size));
  }
  return chunks;
}

async function upsert(table, rows) {
  for (const chunk of chunkArray(rows, CHUNK_SIZE)) {
    const { error } = await supabase
      .from(table)
      .upsert(chunk, { onConflict: 'id', returning: 'minimal' });
    if (error) {
      throw new Error(`Upsert failed for table ${table}: ${error.message}`);
    }
  }
}

async function selectSample(table, id) {
  if (id === undefined || id === null) return null;
  const { data, error } = await supabase
    .from(table)
    .select('*')
    .eq('id', id)
    .maybeSingle();
  if (error) {
    throw new Error(`Failed to fetch sample from ${table}: ${error.message}`);
  }
  return data;
}

const context = {
  sets: {},
  register(name, items) {
    this.sets[name] = new Set(items.map((item) => item.id));
  },
  getSet(name) {
    return this.sets[name];
  },
};

const tasks = [
  {
    name: 'continents',
    dependencies: [],
    table: 'continents',
    path: 'core/continents',
    perPage: 50,
    map: (item) => ({
      id: item.id,
      name: item.name,
      code: item.code ?? null,
      updated_at: runTimestamp,
    }),
    after: (items) => context.register('continents', items),
  },
  {
    name: 'countries',
    dependencies: ['continents'],
    table: 'countries',
    path: 'core/countries',
    populate: true,
    perPage: 1000,
    map: (item) => ({
      id: item.id,
      continent_id: ensure(context.getSet('continents'), item.continent_id),
      name: item.name,
      official_name: item.official_name ?? null,
      fifa_name: item.fifa_name ?? null,
      iso2: item.iso2 ?? null,
      iso3: item.iso3 ?? null,
      latitude: toFloat(item.latitude),
      longitude: toFloat(item.longitude),
      borders: Array.isArray(item.borders) ? item.borders : null,
      image_path: item.image_path ?? null,
      updated_at: runTimestamp,
    }),
    after: (items) => context.register('countries', items),
  },
  {
    name: 'regions',
    dependencies: ['countries'],
    table: 'regions',
    path: 'core/regions',
    populate: true,
    perPage: 1000,
    map: (item) => ({
      id: item.id,
      country_id: ensure(context.getSet('countries'), item.country_id),
      name: item.name,
      updated_at: runTimestamp,
    }),
    after: (items) => context.register('regions', items),
  },
  {
    name: 'cities',
    dependencies: ['countries', 'regions'],
    table: 'cities',
    path: 'core/cities',
    populate: true,
    perPage: 1000,
    map: (item) => ({
      id: item.id,
      country_id: ensure(context.getSet('countries'), item.country_id),
      region_id: ensure(context.getSet('regions'), item.region_id),
      name: item.name,
      latitude: toFloat(item.latitude),
      longitude: toFloat(item.longitude),
      updated_at: runTimestamp,
    }),
    after: (items) => context.register('cities', items),
  },
  {
    name: 'core_types',
    dependencies: [],
    table: 'core_types',
    path: 'core/types',
    map: (item) => ({
      id: item.id,
      name: item.name,
      code: item.code ?? null,
      developer_name: item.developer_name ?? null,
      model_type: item.model_type ?? null,
      stat_group: item.stat_group ?? null,
      updated_at: runTimestamp,
    }),
    after: (items) => context.register('core_types', items),
  },
  {
    name: 'venues',
    dependencies: ['countries', 'cities'],
    table: 'venues',
    path: 'football/venues',
    populate: true,
    perPage: 1000,
    map: (item) => ({
      id: item.id,
      country_id: ensure(context.getSet('countries'), item.country_id),
      city_id: ensure(context.getSet('cities'), item.city_id),
      name: item.name,
      address: item.address ?? null,
      zipcode: item.zipcode ?? null,
      latitude: toFloat(item.latitude),
      longitude: toFloat(item.longitude),
      capacity: toInt(item.capacity),
      image_path: item.image_path ?? null,
      city_name: item.city_name ?? null,
      surface: item.surface ?? null,
      national_team: !!toBool(item.national_team),
      updated_at: runTimestamp,
    }),
    after: (items) => context.register('venues', items),
  },
  {
    name: 'leagues',
    dependencies: ['countries'],
    table: 'leagues',
    path: 'football/leagues',
    populate: true,
    perPage: 1000,
    map: (item) => ({
      id: item.id,
      sport_id: item.sport_id,
      country_id: ensure(context.getSet('countries'), item.country_id),
      name: item.name,
      active: !!toBool(item.active ?? true),
      short_code: item.short_code ?? null,
      image_path: item.image_path ?? null,
      type: item.type ?? null,
      sub_type: item.sub_type ?? null,
      last_played_at: item.last_played_at ?? null,
      category: toInt(item.category),
      has_jerseys: !!toBool(item.has_jerseys),
      updated_at: runTimestamp,
    }),
    after: (items) => context.register('leagues', items),
  },
  {
    name: 'seasons',
    dependencies: ['leagues'],
    table: 'seasons',
    path: 'football/seasons',
    populate: true,
    perPage: 1000,
    map: (item) => ({
      id: item.id,
      sport_id: item.sport_id,
      league_id: ensure(context.getSet('leagues'), item.league_id),
      tie_breaker_rule_id: item.tie_breaker_rule_id ?? null,
      name: item.name,
      finished: !!toBool(item.finished),
      pending: !!toBool(item.pending),
      is_current: !!toBool(item.is_current),
      starting_at: item.starting_at ?? null,
      ending_at: item.ending_at ?? null,
      standings_recalculated_at: item.standings_recalculated_at ?? null,
      games_in_current_week: !!toBool(item.games_in_current_week),
      updated_at: runTimestamp,
    }),
    after: (items) => context.register('seasons', items),
  },
  {
    name: 'states',
    dependencies: [],
    table: 'states',
    path: 'football/states',
    map: (item) => ({
      id: item.id,
      state: item.state,
      name: item.name,
      short_name: item.short_name ?? null,
      developer_name: item.developer_name ?? null,
      updated_at: runTimestamp,
    }),
    after: (items) => context.register('states', items),
  },
  {
    name: 'stages',
    dependencies: ['leagues', 'seasons', 'core_types'],
    table: 'stages',
    path: 'football/stages',
    populate: true,
    perPage: 1000,
    map: (item) => ({
      id: item.id,
      sport_id: item.sport_id,
      league_id: ensure(context.getSet('leagues'), item.league_id),
      season_id: ensure(context.getSet('seasons'), item.season_id),
      type_id: ensure(context.getSet('core_types'), item.type_id),
      name: item.name,
      sort_order: toInt(item.sort_order),
      finished: !!toBool(item.finished),
      is_current: !!toBool(item.is_current),
      starting_at: item.starting_at ?? null,
      ending_at: item.ending_at ?? null,
      games_in_current_week: !!toBool(item.games_in_current_week),
      tie_breaker_rule_id: item.tie_breaker_rule_id ?? null,
      updated_at: runTimestamp,
    }),
    after: (items) => context.register('stages', items),
  },
  {
    name: 'rounds',
    dependencies: ['leagues', 'seasons', 'stages'],
    table: 'rounds',
    path: 'football/rounds',
    populate: true,
    perPage: 1000,
    map: (item) => ({
      id: item.id,
      sport_id: item.sport_id,
      league_id: ensure(context.getSet('leagues'), item.league_id),
      season_id: ensure(context.getSet('seasons'), item.season_id),
      stage_id: ensure(context.getSet('stages'), item.stage_id),
      name: item.name,
      finished: !!toBool(item.finished),
      is_current: !!toBool(item.is_current),
      starting_at: item.starting_at ?? null,
      ending_at: item.ending_at ?? null,
      games_in_current_week: !!toBool(item.games_in_current_week),
      updated_at: runTimestamp,
    }),
    after: (items) => context.register('rounds', items),
  },
  {
    name: 'teams',
    dependencies: ['countries', 'venues'],
    table: 'teams',
    path: 'football/teams',
    populate: true,
    perPage: 1000,
    map: (item) => ({
      id: item.id,
      sport_id: item.sport_id,
      country_id: ensure(context.getSet('countries'), item.country_id),
      venue_id: ensure(context.getSet('venues'), item.venue_id),
      gender: item.gender ?? null,
      name: item.name,
      short_code: item.short_code ?? null,
      image_path: item.image_path ?? null,
      founded: toInt(item.founded),
      type: item.type ?? null,
      placeholder: !!toBool(item.placeholder),
      last_played_at: item.last_played_at ?? null,
      updated_at: runTimestamp,
    }),
    after: (items) => context.register('teams', items),
  },
  {
    name: 'referees',
    dependencies: ['countries', 'cities'],
    table: 'referees',
    path: 'football/referees',
    populate: true,
    perPage: 1000,
    map: (item) => ({
      id: item.id,
      sport_id: item.sport_id,
      country_id: ensure(context.getSet('countries'), item.country_id),
      city_id: ensure(context.getSet('cities'), item.city_id),
      common_name: item.common_name ?? null,
      firstname: item.firstname ?? null,
      lastname: item.lastname ?? null,
      name: item.name ?? null,
      display_name: item.display_name ?? null,
      image_path: item.image_path ?? null,
      height: toInt(item.height),
      weight: toInt(item.weight),
      date_of_birth: item.date_of_birth ?? null,
      gender: item.gender ?? null,
      updated_at: runTimestamp,
    }),
    after: (items) => context.register('referees', items),
  },
  {
    name: 'players',
    dependencies: ['countries', 'cities', 'core_types'],
    table: 'players',
    path: 'football/players',
    populate: true,
    perPage: 1000,
    map: (item) => ({
      id: item.id,
      sport_id: item.sport_id,
      country_id: ensure(context.getSet('countries'), item.country_id),
      nationality_id: ensure(context.getSet('countries'), item.nationality_id),
      city_id: ensure(context.getSet('cities'), item.city_id),
      position_id: item.position_id ?? null,
      detailed_position_id: item.detailed_position_id ?? null,
      type_id: ensure(context.getSet('core_types'), item.type_id),
      common_name: item.common_name ?? null,
      firstname: item.firstname ?? null,
      lastname: item.lastname ?? null,
      name: item.name ?? null,
      display_name: item.display_name ?? null,
      image_path: item.image_path ?? null,
      height: toInt(item.height),
      weight: toInt(item.weight),
      date_of_birth: item.date_of_birth ?? null,
      gender: item.gender ?? null,
      updated_at: runTimestamp,
    }),
    after: (items) => context.register('players', items),
  },
  {
    name: 'coaches',
    dependencies: ['players', 'countries', 'cities'],
    table: 'coaches',
    path: 'football/coaches',
    populate: true,
    perPage: 1000,
    map: (item) => ({
      id: item.id,
      player_id: ensure(context.getSet('players'), item.player_id),
      sport_id: item.sport_id,
      country_id: ensure(context.getSet('countries'), item.country_id),
      nationality_id: ensure(context.getSet('countries'), item.nationality_id),
      city_id: ensure(context.getSet('cities'), item.city_id),
      common_name: item.common_name ?? null,
      firstname: item.firstname ?? null,
      lastname: item.lastname ?? null,
      name: item.name ?? null,
      display_name: item.display_name ?? null,
      image_path: item.image_path ?? null,
      height: toInt(item.height),
      weight: toInt(item.weight),
      date_of_birth: item.date_of_birth ?? null,
      gender: item.gender ?? null,
      updated_at: runTimestamp,
    }),
    after: (items) => context.register('coaches', items),
  },
  {
    name: 'standings',
    dependencies: ['teams', 'leagues', 'seasons', 'stages', 'rounds'],
    table: 'standings',
    path: 'football/standings',
    populate: true,
    perPage: 1000,
    map: (item) => ({
      id: item.id,
      participant_id: ensure(context.getSet('teams'), item.participant_id),
      sport_id: item.sport_id,
      league_id: ensure(context.getSet('leagues'), item.league_id),
      season_id: ensure(context.getSet('seasons'), item.season_id),
      stage_id: ensure(context.getSet('stages'), item.stage_id),
      group_id: item.group_id ?? null,
      round_id: ensure(context.getSet('rounds'), item.round_id),
      standing_rule_id: item.standing_rule_id ?? null,
      position: toInt(item.position),
      result: item.result ?? null,
      points: toFloat(item.points),
      updated_at: runTimestamp,
    }),
    after: (items) => context.register('standings', items),
  },
  {
    name: 'fixtures',
    dependencies: ['leagues', 'seasons', 'stages', 'rounds', 'states', 'venues'],
    table: 'fixtures',
    path: 'football/fixtures',
    populate: true,
    perPage: 1000,
    map: (item) => ({
      id: item.id,
      sport_id: item.sport_id,
      league_id: ensure(context.getSet('leagues'), item.league_id),
      season_id: ensure(context.getSet('seasons'), item.season_id),
      stage_id: ensure(context.getSet('stages'), item.stage_id),
      group_id: item.group_id ?? null,
      aggregate_id: item.aggregate_id ?? null,
      round_id: ensure(context.getSet('rounds'), item.round_id),
      state_id: ensure(context.getSet('states'), item.state_id),
      venue_id: ensure(context.getSet('venues'), item.venue_id),
      name: item.name,
      starting_at: item.starting_at ?? null,
      result_info: item.result_info ?? null,
      leg: item.leg ?? null,
      details: item.details ?? null,
      length: toInt(item.length),
      placeholder: !!toBool(item.placeholder),
      has_odds: !!toBool(item.has_odds),
      has_premium_odds: !!toBool(item.has_premium_odds),
      starting_at_timestamp: toInt(item.starting_at_timestamp),
      updated_at: runTimestamp,
    }),
  },
];

function resolveTasks(taskList, names) {
  const map = new Map(taskList.map((task) => [task.name, task]));
  const selected = new Set();

  const visit = (name) => {
    if (!map.has(name)) {
      throw new Error(`Unknown task ${name}`);
    }
    if (selected.has(name)) return;

    const task = map.get(name);
    (task.dependencies ?? []).forEach(visit);
    selected.add(name);
  };

  if (names && names.length) {
    names.forEach(visit);
  } else {
    taskList.forEach((task) => visit(task.name));
  }

  return taskList.filter((task) => selected.has(task.name));
}

const selectedTasks = resolveTasks(tasks, requestedTasks);

async function main() {
  for (const task of selectedTasks) {
    console.log(`\n[${task.name}] fetching data...`);
    const rawItems = await fetchEntities(task.path, {
      perPage: task.perPage,
      maxPages: task.maxPages,
      populate: task.populate,
      include: task.include,
      select: task.select,
      filters: task.filters,
      query: task.query,
      onPage: async ({ page, data, pagination, rateLimit }) => {
        const hasMore = pagination?.has_more ? 'yes' : 'no';
        const remaining = rateLimit?.remaining ?? 'n/a';
        console.log(
          `[${task.name}] page ${page} -> ${data.length} records (has_more=${hasMore}, rate_remaining=${remaining})`,
        );
        if (typeof task.onPage === 'function') {
          await task.onPage({ page, data, pagination, rateLimit });
        }
      },
    });
    console.log(`[${task.name}] fetched ${rawItems.length} records`);

    const mapped = rawItems
      .map((item) => task.map(item))
      .filter(Boolean);

    if (typeof task.after === 'function') {
      task.after(mapped);
    }

    if (!mapped.length) {
      console.log(`[${task.name}] no records to upsert.`);
      continue;
    }

    await upsert(task.table, mapped);
    console.log(`[${task.name}] upserted ${mapped.length} records`);

    const sampleId = rawItems[0]?.id;
    if (sampleId !== undefined) {
      const sample = await selectSample(task.table, sampleId);
      console.log(`[${task.name}] sample row:`, JSON.stringify(sample, null, 2));
    }
  }

  console.log('\nSeeding completed.');
}

main().catch((err) => {
  console.error('Seed process failed:', err.message);
  process.exit(1);
});
