// deno-lint-ignore-file
// @ts-nocheck
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const SPORTMONKS_API_KEY = Deno.env.get("SPORTMONKS_API_KEY");

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Missing SUPABASE_URL or SERVICE_ROLE_KEY environment variables");
}

if (!SPORTMONKS_API_KEY) {
  throw new Error("Missing SPORTMONKS_API_KEY environment variable");
}

const SPORTMONKS_BASE = "https://api.sportmonks.com/v3";
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  db: {
    schema: "public",
  },
});

const DEFAULT_LIMIT = Number(Deno.env.get("FIXTURE_ENRICHMENT_LIMIT") ?? 100);
const BATCH_SIZE = Number(Deno.env.get("FIXTURE_ENRICHMENT_BATCH_SIZE") ?? 20);
const RATE_THRESHOLD = Number(Deno.env.get("SPORTMONKS_RATE_THRESHOLD") ?? 50);
const RATE_WAIT_MS = Number(Deno.env.get("SPORTMONKS_RATE_WAIT_MS") ?? 1000);
const MAX_RETRIES = Number(Deno.env.get("SPORTMONKS_MAX_RETRIES") ?? 3);
const RETRY_BASE_MS = Number(Deno.env.get("SPORTMONKS_RETRY_BASE_MS") ?? 500);
const DEFAULT_DAYS_BACK = Number(Deno.env.get("FIXTURE_ENRICHMENT_DAYS_BACK") ?? 3);
const DEFAULT_DAYS_FORWARD = Number(Deno.env.get("FIXTURE_ENRICHMENT_DAYS_FORWARD") ?? 1);
const DEFAULT_INCLUDES =
  Deno.env.get("FIXTURE_ENRICHMENT_INCLUDES") ??
  "participants;lineups.player;lineups.details;scores;periods;weatherReport;odds";

const ALL_ENRICHMENT_TARGETS = new Set<string>([
  "fixture_participants",
  "fixture_scores",
  "fixture_periods",
  "fixture_lineups",
  "fixture_lineup_details",
  "fixture_odds",
  "fixture_weather",
  "fixture_events",
  "fixture_statistics",
  "fixture_referees",
]);

function normaliseTargets(rawTargets: unknown): string[] {
  if (!Array.isArray(rawTargets)) return [];
  return rawTargets
    .map((t) => (typeof t === "string" ? t.trim() : ""))
    .filter((t) => ALL_ENRICHMENT_TARGETS.has(t));
}

function buildIncludesFromTargets(targets: string[]): string {
  if (!targets.length) return DEFAULT_INCLUDES;

  const includeTokens = new Set<string>();
  for (const t of targets) {
    switch (t) {
      case "fixture_participants":
        includeTokens.add("participants");
        break;
      case "fixture_events":
        includeTokens.add("events");
        break;
      case "fixture_statistics":
        includeTokens.add("statistics.type");
        break;
      case "fixture_scores":
        includeTokens.add("scores");
        break;
      case "fixture_periods":
        includeTokens.add("periods");
        break;
      case "fixture_lineups":
      case "fixture_lineup_details":
        // É necessário incluir o recurso raiz 'lineups' além dos includes aninhados
        includeTokens.add("lineups");
        includeTokens.add("lineups.player");
        includeTokens.add("lineups.details");
        break;
      case "fixture_odds":
        includeTokens.add("odds");
        break;
      case "fixture_weather":
        includeTokens.add("weatherReport");
        break;
      case "fixture_referees":
        includeTokens.add("referees");
        break;
      default:
        break;
    }
  }
  if (includeTokens.size === 0) return DEFAULT_INCLUDES;
  return Array.from(includeTokens).join(";");
}

const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

function dedupeBy<T>(rows: T[], keyOf: (row: T) => string): T[] {
  const seen = new Set<string>();
  const result: T[] = [];
  for (const row of rows) {
    const key = keyOf(row);
    if (!seen.has(key)) {
      seen.add(key);
      result.push(row);
    }
  }
  return result;
}

interface RateLimitInfo {
  remaining?: number;
  resets_in_seconds?: number;
  requested_entity?: string;
}

async function maybePause(rateLimit: RateLimitInfo | null, context: string) {
  if (!rateLimit || rateLimit.remaining === undefined) return;
  if (rateLimit.remaining > RATE_THRESHOLD) return;

  let waitMs = RATE_WAIT_MS;
  if (
    rateLimit.resets_in_seconds !== undefined &&
    rateLimit.remaining > 0
  ) {
    const estimate = Math.ceil((rateLimit.resets_in_seconds * 1000) / rateLimit.remaining);
    waitMs = Math.max(waitMs, estimate);
  }
  console.log(
    `Rate limit low for ${context} (remaining=${rateLimit.remaining}). Waiting ${waitMs}ms`,
  );
  await delay(waitMs);
}

async function fetchSportmonks(url: URL, metrics?: { http: Array<Record<string, unknown>> }) {
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    const startedAt = Date.now();
    let status = 0;
    try {
      const response = await fetch(url, { headers: { Accept: "application/json" } });
      status = response.status;
      if (!response.ok) {
        const text = await response.text();
        if ((status === 429 || status >= 500) && attempt < MAX_RETRIES) {
          const backoff = RETRY_BASE_MS * Math.pow(2, attempt - 1);
          await delay(backoff);
          continue;
        }
        throw new Error(`Sportmonks request failed (${status}): ${text}`);
      }
      const payload = await response.json();
      const rateLimit = payload?.rate_limit ?? null;
      return { payload, rateLimit, status };
    } finally {
      if (metrics && Array.isArray(metrics.http)) {
        metrics.http.push({ path: url.pathname, status, ms: Date.now() - startedAt, attempt });
      }
    }
  }
  throw new Error("Exhausted retries for Sportmonks request");
}

function normaliseTimestamp(value: unknown) {
  if (!value || typeof value !== "string") return null;
  if (value.includes("T")) return value;
  return value.replace(" ", "T");
}

function toNumber(value: unknown) {
  if (value === null || value === undefined || value === "") return null;
  const num = typeof value === "number" ? value : Number(value);
  return Number.isFinite(num) ? num : null;
}

function toBool(value: unknown) {
  if (value === null || value === undefined) return null;
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (["true", "1", "t", "yes", "y"].includes(normalized)) return true;
    if (["false", "0", "f", "no", "n"].includes(normalized)) return false;
  }
  return null;
}

function mapParticipant(participant: any, fixtureId: number, runTimestamp: string) {
  const meta = typeof participant.meta === "object" ? participant.meta : null;
  return {
    fixture_id: fixtureId,
    participant_id: participant.id,
    location: meta?.location ?? meta?.side ?? null,
    winner: toBool(meta?.winner),
    position: toNumber(meta?.position),
    meta,
    updated_at: runTimestamp,
  };
}

function mapScore(score: any, fixtureId: number, runTimestamp: string) {
  const payload = typeof score.score === "object" && score.score !== null
    ? score.score
    : score;
  return {
    id: score.id,
    fixture_id: fixtureId,
    participant_id: score.participant_id ?? null,
    type_id: score.type_id ?? null,
    score: payload,
    description: score.description ?? null,
    result: score.result ?? null,
    updated_at: runTimestamp,
  };
}

function mapPeriod(period: any, runTimestamp: string) {
  return {
    id: period.id,
    fixture_id: period.fixture_id,
    type_id: period.type_id ?? null,
    started: toBool(period.started) ?? false,
    ended: toBool(period.ended) ?? false,
    counts_from: toNumber(period.counts_from),
    ticking: toBool(period.ticking) ?? false,
    sort_order: toNumber(period.sort_order),
    description: period.description ?? null,
    time_added: toNumber(period.time_added),
    period_length: toNumber(period.period_length),
    minutes: toNumber(period.minutes),
    seconds: toNumber(period.seconds),
    updated_at: runTimestamp,
  };
}

function mapLineup(lineup: any, runTimestamp: string) {
  return {
    id: lineup.id,
    fixture_id: lineup.fixture_id,
    participant_id: lineup.participant_id ?? lineup.team_id ?? null,
    player_id: lineup.player_id ?? null,
    position_id: lineup.position_id ?? lineup.type_id ?? null,
    jersey_number: toNumber(lineup.jersey_number),
    player_name: lineup.player_name ?? lineup.player?.display_name ?? null,
    formation_field: toNumber(lineup.formation_field),
    formation_position: toNumber(lineup.formation_position),
    posx: toNumber(lineup.posx),
    posy: toNumber(lineup.posy),
    captain: toBool(lineup.captain) ?? false,
    updated_at: runTimestamp,
  };
}

function mapLineupDetail(detail: any, fixtureId: number, lineupId: number, runTimestamp: string) {
  return {
    id: detail.id,
    fixture_id: fixtureId,
    lineup_id: lineupId,
    participant_id: detail.participant_id ?? detail.team_id ?? null,
    player_id: detail.player_id ?? null,
    related_player_id: detail.related_player_id ?? detail.substitution_player_id ?? null,
    type_id: detail.type_id ?? null,
    formation_field: toNumber(detail.formation_field),
    formation_position: toNumber(detail.formation_position),
    minute: toNumber(detail.minute),
    additional_position_id: detail.additional_position_id ?? null,
    jersey_number: toNumber(detail.jersey_number),
    player_name: detail.player_name ?? detail.player?.display_name ?? null,
    updated_at: runTimestamp,
  };
}

function mapOdds(odd: any, fixtureId: number, runTimestamp: string) {
  return {
    id: odd.id,
    fixture_id: fixtureId,
    bookmaker_id: odd.bookmaker_id ?? null,
    market_id: odd.market_id ?? null,
    label: odd.label ?? odd.name ?? null,
    value: toNumber(odd.value),
    probability: toNumber(odd.probability),
    dp3: odd.dp3 ?? null,
    fractional: odd.fractional ?? null,
    american: odd.american ?? null,
    winning: toBool(odd.winning),
    stopped: toBool(odd.stopped),
    handicap: toNumber(odd.handicap),
    participant: odd.participant ?? null,
    latest_bookmaker_update: normaliseTimestamp(odd.latest_bookmaker_update),
    updated_at: runTimestamp,
  };
}

function extractStatValue(stat: any) {
  if (!stat || typeof stat !== "object") return { numeric: null, text: null };
  const { data } = stat;
  if (!data || typeof data !== "object") return { numeric: null, text: null };
  const value = data?.value ?? data?.count ?? data?.total ?? data?.avg ?? null;
  if (value === null || value === undefined) return { numeric: null, text: null };
  if (typeof value === "number") return { numeric: value, text: String(value) };
  const num = Number(value);
  return {
    numeric: Number.isFinite(num) ? num : null,
    text: String(value),
  };
}

function mapEvent(event: any, runTimestamp: string) {
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
    minute: toNumber(event.minute),
    extra_minute: toNumber(event.extra_minute),
    injured: toBool(event.injured),
    on_bench: toBool(event.on_bench),
    rescinded: toBool(event.rescinded),
    section: event.section ?? null,
    sort_order: toNumber(event.sort_order),
    updated_at: runTimestamp,
  };
}

function mapStatistic(stat: any, runTimestamp: string) {
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

function mapFixtureReferee(refereeId: number, fixtureId: number, runTimestamp: string) {
  return {
    fixture_id: fixtureId,
    referee_id: refereeId,  // Use passed refereeId
    role: 'main',  // Default for main
    updated_at: runTimestamp,
  };
}

const UPSERT_TARGETS: Record<string, string> = {
  fixture_participants: "fixture_id,participant_id",
  fixture_scores: "id",
  fixture_periods: "id",
  fixture_lineups: "id",
  fixture_lineup_details: "id",
  fixture_odds: "id",
  fixture_weather: "fixture_id",
  fixture_events: "id",
  fixture_statistics: "id",
  fixture_referees: "fixture_id,referee_id",
};

async function chunkedUpsert(table: string, rows: any[], chunkSize = 500) {
  const onConflict = UPSERT_TARGETS[table];
  if (!onConflict) {
    throw new Error(`No conflict target configured for table ${table}`);
  }

  for (let i = 0; i < rows.length; i += chunkSize) {
    const chunk = rows.slice(i, i + chunkSize).map((row) => {
      const copy: Record<string, unknown> = {};
      for (const [key, value] of Object.entries(row)) {
        copy[key] = value ?? null;
      }
      return copy;
    });

    const { error } = await supabase.from(table).upsert(chunk, { onConflict });
    if (error) {
      throw new Error(`Upsert into ${table} failed: ${error.message}`);
    }
  }
}

async function getFixturesToEnrich(limit: number, payload: Record<string, unknown>) {
  const explicitIds = Array.isArray(payload?.fixture_ids)
    ? (payload.fixture_ids as unknown[])
        .map((value) => toNumber(value))
        .filter((value): value is number => typeof value === "number")
    : [];
  if (explicitIds.length) {
    return explicitIds.slice(0, limit);
  }

  const daysBack = toNumber(payload?.days_back) ?? DEFAULT_DAYS_BACK;
  const daysForward = toNumber(payload?.days_forward) ?? DEFAULT_DAYS_FORWARD;
  const useMissing = (payload as any)?.mode === 'missing';
  const rawTargets = (payload as any)?.targets;
  let targets = normaliseTargets(rawTargets);
  // Garantir dependência: se pedir lineup_details, incluir lineups também
  if (targets.includes("fixture_lineup_details") && !targets.includes("fixture_lineups")) {
    targets = [...targets, "fixture_lineups"];
  }

  const now = Date.now();
  const since = new Date(now - daysBack * 86_400_000).toISOString();
  const until = new Date(now + daysForward * 86_400_000).toISOString();

  if (useMissing && targets.length) {
    const { data, error } = await supabase
      .rpc('get_fixtures_missing_enrichment', { targets, limit_count: limit, since_date: since });
    if (error) throw new Error(`Failed to get missing fixtures: ${error.message}`);
    return (data ?? []).map((row: any) => (typeof row === 'object' ? row.id : row));
  }

  const { data, error } = await supabase
    .from('fixtures')
    .select('id, updated_at')
    .gte('starting_at', since)
    .lte('starting_at', until)
    .order('updated_at', { ascending: false })
    .limit(limit);

  if (error) {
    throw new Error(`Failed to get fixtures to enrich: ${error.message}`);
  }

  return (data ?? []).map((row) => row.id);
}

async function fetchEnrichmentData(
  fixtureIds: number[],
  includes: string,
  targetSet: Set<string>,
  metrics?: { http: Array<Record<string, unknown>> },
) {
  const runTimestamp = new Date().toISOString();
  const eventRows: any[] = [];
  const statRows: any[] = [];
  const participantRows: any[] = [];
  const scoreRows: any[] = [];
  const periodRows: any[] = [];
  const lineupRows: any[] = [];
  const lineupDetailRows: any[] = [];
  const weatherRows: any[] = [];
  const oddsRows: any[] = [];
  const refereeRows: any[] = [];
  const refereeMasterRows: any[] = [];

  const effectiveBatch = Math.min(BATCH_SIZE, 50);
  for (let i = 0; i < fixtureIds.length; i += effectiveBatch) {
    const batch = fixtureIds.slice(i, i + effectiveBatch);
    if (!batch.length) continue;

    const url = new URL(`${SPORTMONKS_BASE}/football/fixtures/multi/${batch.join(",")}`);
    url.searchParams.set("api_token", SPORTMONKS_API_KEY);
    url.searchParams.set("include", includes);

    const { payload, rateLimit } = await fetchSportmonks(url, metrics);
    await maybePause(rateLimit, "fixtures/multi/enrichment");

    const fixtures = payload?.data ?? [];
    fixtures.forEach((fixture: any) => {
      // Events
      if (targetSet.has("fixture_events") && Array.isArray(fixture.events)) {
        fixture.events.forEach((event: any) => {
          eventRows.push(mapEvent(event, runTimestamp));
        });
      }

      // Statistics
      if (targetSet.has("fixture_statistics") && Array.isArray(fixture.statistics)) {
        fixture.statistics.forEach((stat: any) => {
          statRows.push(mapStatistic(stat, runTimestamp));
        });
      }

      // Participantes
      if (targetSet.has("fixture_participants") && Array.isArray(fixture.participants)) {
        fixture.participants.forEach((participant: any) => {
          participantRows.push(mapParticipant(participant, fixture.id, runTimestamp));
        });
      }

      // Scores
      if (targetSet.has("fixture_scores") && Array.isArray(fixture.scores)) {
        fixture.scores.forEach((score: any) => {
          scoreRows.push(mapScore(score, fixture.id, runTimestamp));
        });
      }

      // Períodos
      if (targetSet.has("fixture_periods") && Array.isArray(fixture.periods)) {
        fixture.periods.forEach((period: any) => {
          periodRows.push(mapPeriod(period, runTimestamp));
        });
      }

      // Lineups
      if ((targetSet.has("fixture_lineups") || targetSet.has("fixture_lineup_details")) && Array.isArray(fixture.lineups)) {
        fixture.lineups.forEach((lineup: any) => {
          if (targetSet.has("fixture_lineups")) {
            lineupRows.push(mapLineup(lineup, runTimestamp));
          }

          if (targetSet.has("fixture_lineup_details") && Array.isArray(lineup.details)) {
            lineup.details.forEach((detail: any) => {
              lineupDetailRows.push(
                mapLineupDetail(detail, fixture.id, lineup.id, runTimestamp),
              );
            });
          }
        });
      }

      // Weather
      if (targetSet.has("fixture_weather") && fixture.weatherReport && typeof fixture.weatherReport === 'object') {
        weatherRows.push(mapWeather(fixture.weatherReport, fixture.id, runTimestamp));
      }

      // Odds
      if (targetSet.has("fixture_odds") && Array.isArray(fixture.odds)) {
        fixture.odds.forEach((odd: any) => {
          oddsRows.push(mapOdds(odd, fixture.id, runTimestamp));
        });
      }

      // Referees
      if (targetSet.has("fixture_referees") && Array.isArray(fixture.referees)) {
        fixture.referees.forEach((ref: any) => {
          if (ref.type_id === 6) {  // Main referee only
            const refId = ref.referee_id || ref.id;  // Prefer referee_id, fallback id
            refereeRows.push(mapFixtureReferee(refId, fixture.id, runTimestamp));
            refereeMasterRows.push({
              id: refId,  // Use refId
              sport_id: toNumber(ref.sport_id) ?? 1,
              country_id: toNumber(ref.country_id),
              city_id: toNumber(ref.city_id),
              common_name: ref.common_name ?? null,
              firstname: ref.firstname ?? null,
              lastname: ref.lastname ?? null,
              name: ref.name ?? ref.display_name ?? null,
              display_name: ref.display_name ?? null,
              image_path: ref.image_path ?? null,
              height: toNumber(ref.height),
              weight: toNumber(ref.weight),
              date_of_birth: ref.date_of_birth ?? null,
              gender: ref.gender ?? null,
              updated_at: runTimestamp,
            });
            console.log(`Processed main referee ${refId} for fixture ${fixture.id}`);
          }
        });
      }
    });
  }

  return { eventRows, statRows, participantRows, scoreRows, periodRows, lineupRows, lineupDetailRows, weatherRows, oddsRows, refereeRows, refereeMasterRows };
}

async function fetchRefereesDetailsByIds(refIds: number[], metrics?: { http: Array<Record<string, unknown>> }) {
  const details: any[] = [];
  const effectiveBatch = Math.min(BATCH_SIZE, 50);
  for (let i = 0; i < refIds.length; i += effectiveBatch) {
    const batch = refIds.slice(i, i + effectiveBatch);
    if (!batch.length) continue;
    const url = new URL(`${SPORTMONKS_BASE}/football/referees/multi/${batch.join(",")}`);
    url.searchParams.set("api_token", SPORTMONKS_API_KEY);
    const { payload, rateLimit } = await fetchSportmonks(url, metrics);
    await maybePause(rateLimit, "referees/multi/byIds");
    const items = payload?.data ?? [];
    items.forEach((ref: any) => {
      details.push({
        id: ref.id,
        sport_id: toNumber(ref.sport_id) ?? 1,
        country_id: toNumber(ref.country_id),
        city_id: toNumber(ref.city_id),
        common_name: ref.common_name ?? null,
        firstname: ref.firstname ?? null,
        lastname: ref.lastname ?? null,
        name: ref.name ?? ref.display_name ?? null,
        display_name: ref.display_name ?? null,
        image_path: ref.image_path ?? null,
        height: toNumber(ref.height),
        weight: toNumber(ref.weight),
        date_of_birth: ref.date_of_birth ?? null,
        gender: ref.gender ?? null,
        updated_at: new Date().toISOString(),
      });
    });
  }
  return details;
}

async function insertRunLog(entity: string, status: string, startedAt: string, processed: number, errorMessage?: string, details?: Record<string, unknown>) {
  const logEntry = {
    entity,
    status,
    started_at: startedAt,
    finished_at: new Date().toISOString(),
    processed_count: processed,
    error_message: errorMessage ?? null,
    details: details ? JSON.stringify(details) : null,
  };
  const { error } = await supabase.from("ingestion_runs").insert(logEntry);
  if (error) {
    console.error("Failed to insert ingestion run log:", error.message);
  }
}

serve(async (request) => {
  const startedAt = new Date().toISOString();
  const LOCK_NAME = "edge:fixture-enrichment";
  let acquiredLock = false;
  try {
    const { data: gotLock, error: lockError } = await supabase.rpc("try_advisory_lock", { lock_name: LOCK_NAME });
    if (lockError) {
      console.error("Lock error:", lockError.message);
      await insertRunLog("fixture_enrichment", "noop", startedAt, 0, undefined, { reason: "lock_error" });
      return new Response(JSON.stringify({ message: "Lock error - aborting" }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      });
    }
    if (!gotLock) {
      await insertRunLog("fixture_enrichment", "noop", startedAt, 0, undefined, { reason: "concurrent_lock" });
      return new Response(JSON.stringify({ message: "Already running - noop" }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      });
    }
    acquiredLock = true;

    const payload = await request.json().catch(() => ({}));
    const limit = typeof payload.limit === "number" ? payload.limit : DEFAULT_LIMIT;
    const rawTargets = (payload as any)?.targets;
    const normalised = normaliseTargets(rawTargets);
    const effectiveTargets = normalised.length
      ? normalised
      : Array.from(ALL_ENRICHMENT_TARGETS);
    const targetSet = new Set<string>(effectiveTargets);
    const includes = buildIncludesFromTargets(effectiveTargets);

    // Modo direto por referee_ids: atualiza nomes dos árbitros sem depender de fixtures
    const rawRefIds = Array.isArray((payload as any)?.referee_ids) ? (payload as any)?.referee_ids : [];
    const refereeIds = rawRefIds
      .map((v: any) => toNumber(v))
      .filter((v: any): v is number => typeof v === 'number');
    if (refereeIds.length > 0) {
      const metrics: { http: Array<Record<string, unknown>> } = { http: [] };
      const refDetails = await fetchRefereesDetailsByIds(refereeIds, metrics);
      if (refDetails.length) {
        const { error: refErr } = await supabase.from("referees").upsert(refDetails, { onConflict: "id" });
        if (refErr) console.error("Upsert referees (byIds) failed:", refErr.message);
      }
      await insertRunLog("fixture_enrichment", "success", startedAt, refereeIds.length, undefined, { mode: "referees_by_ids", count: refereeIds.length });
      return new Response(JSON.stringify({ message: "Referees updated", count: refereeIds.length }), { headers: { "Content-Type": "application/json" }, status: 200 });
    }

    const fixtureIds = await getFixturesToEnrich(limit, payload);

    if (!fixtureIds.length) {
      await insertRunLog("fixture_enrichment", "noop", startedAt, 0, undefined, { message: "No fixtures to enrich" });
      return new Response(JSON.stringify({ message: "No fixtures to enrich" }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      });
    }

    const metrics: { http: Array<Record<string, unknown>> } = { http: [] };
    const {
      eventRows,
      statRows,
      participantRows,
      scoreRows,
      periodRows,
      lineupRows,
      lineupDetailRows,
      weatherRows,
      oddsRows,
      refereeRows,
      refereeMasterRows,
    } = await fetchEnrichmentData(fixtureIds, includes, targetSet, metrics);

    // Deduplicar por chaves antes do upsert
    const dedupedEvents = dedupeBy(eventRows, (r: any) => String(r.id ?? ''));
    const dedupedStats = dedupeBy(statRows, (r: any) => String(r.id ?? ''));
    const dedupedParticipants = dedupeBy(participantRows, (r: any) => `${r.fixture_id}:${r.participant_id ?? ''}`);
    const dedupedScores = dedupeBy(scoreRows, (r: any) => String(r.id ?? ''));
    const dedupedPeriods = dedupeBy(periodRows, (r: any) => String(r.id ?? ''));
    const dedupedLineups = dedupeBy(lineupRows, (r: any) => String(r.id ?? ''));
    const dedupedLineupDetails = dedupeBy(lineupDetailRows, (r: any) => String(r.id ?? ''));
    const dedupedWeather = dedupeBy(weatherRows, (r: any) => String(r.fixture_id ?? ''));
    const dedupedOdds = dedupeBy(oddsRows, (r: any) => String(r.id ?? ''));
    const dedupedReferees = dedupeBy(refereeRows, (r: any) => `${r.fixture_id}:${r.referee_id ?? ''}`);

    if (targetSet.has("fixture_events") && dedupedEvents.length) {
      await chunkedUpsert("fixture_events", dedupedEvents);
    }
    if (targetSet.has("fixture_statistics") && dedupedStats.length) {
      await chunkedUpsert("fixture_statistics", dedupedStats);
    }
    if (targetSet.has("fixture_participants") && dedupedParticipants.length) {
      await chunkedUpsert("fixture_participants", dedupedParticipants);
    }
    if (targetSet.has("fixture_scores") && dedupedScores.length) {
      await chunkedUpsert("fixture_scores", dedupedScores);
    }
    if (targetSet.has("fixture_periods") && dedupedPeriods.length) {
      await chunkedUpsert("fixture_periods", dedupedPeriods);
    }
    if (targetSet.has("fixture_lineups") && dedupedLineups.length) {
      await chunkedUpsert("fixture_lineups", dedupedLineups);
    }
    if (targetSet.has("fixture_lineup_details") && dedupedLineupDetails.length) {
      await chunkedUpsert("fixture_lineup_details", dedupedLineupDetails);
    }
    if (targetSet.has("fixture_weather") && dedupedWeather.length) {
      await chunkedUpsert("fixture_weather", dedupedWeather);
    }
    if (targetSet.has("fixture_odds") && dedupedOdds.length) {
      await chunkedUpsert("fixture_odds", dedupedOdds);
    }
    if (targetSet.has("fixture_referees") && dedupedReferees.length) {
      // Semear árbitros faltantes (best-effort) antes do vínculo, com fallback para detalhes
      let dedupedRefMaster = dedupeBy(refereeMasterRows, (r: any) => String(r.id ?? ''));

      // Fallback: buscar detalhes dos árbitros sem nome
      const missingNameIds = dedupedRefMaster
        .filter((r: any) => !r.name && !r.display_name && !r.common_name)
        .map((r: any) => r.id)
        .filter((v: any) => typeof v === 'number');

      if (missingNameIds.length) {
        const refDetails: any[] = [];
        const effectiveBatch = Math.min(BATCH_SIZE, 50);
        for (let i = 0; i < missingNameIds.length; i += effectiveBatch) {
          const batch = missingNameIds.slice(i, i + effectiveBatch);
          if (!batch.length) continue;
          const url = new URL(`${SPORTMONKS_BASE}/football/referees/multi/${batch.join(",")}`);
          url.searchParams.set("api_token", SPORTMONKS_API_KEY);

          try {
            const { payload, rateLimit } = await fetchSportmonks(url, metrics);
            await maybePause(rateLimit, "referees/multi");
            const items = payload?.data ?? [];
            items.forEach((ref: any) => {
              refDetails.push({
                id: ref.id,
                sport_id: toNumber(ref.sport_id) ?? 1,
                country_id: toNumber(ref.country_id),
                city_id: toNumber(ref.city_id),
                common_name: ref.common_name ?? null,
                firstname: ref.firstname ?? null,
                lastname: ref.lastname ?? null,
                name: ref.name ?? ref.display_name ?? null,
                display_name: ref.display_name ?? null,
                image_path: ref.image_path ?? null,
                height: toNumber(ref.height),
                weight: toNumber(ref.weight),
                date_of_birth: ref.date_of_birth ?? null,
                gender: ref.gender ?? null,
                updated_at: new Date().toISOString(),
              });
            });
          } catch (e) {
            console.error("Referees details fetch failed:", e && (e as any).message ? (e as any).message : String(e));
          }
        }

        if (refDetails.length) {
          const byId: Record<string, any> = {};
          refDetails.forEach((r) => { byId[String(r.id)] = r; });
          dedupedRefMaster = dedupedRefMaster.map((r: any) => byId[String(r.id)] ?? r);
        }
      }

      if (dedupedRefMaster.length) {
        try {
          const { error: refErr } = await supabase.from("referees").upsert(dedupedRefMaster, { onConflict: "id" });
          if (refErr) console.error("Upsert referees failed:", refErr.message);
        } catch (_) { /* ignore */ }
      }

      await chunkedUpsert("fixture_referees", dedupedReferees);
    }

    const summary = {
      fixturesEnriched: fixtureIds.length,
      events: dedupedEvents.length,
      statistics: dedupedStats.length,
      participants: dedupedParticipants.length,
      scores: dedupedScores.length,
      periods: dedupedPeriods.length,
      lineups: dedupedLineups.length,
      lineupDetails: dedupedLineupDetails.length,
      weather: dedupedWeather.length,
      odds: dedupedOdds.length,
      referees: dedupedReferees.length,
      targets: Array.from(targetSet.values()),
    };

    summary["http"] = metrics.http;
    await insertRunLog("fixture_enrichment", "success", startedAt, fixtureIds.length, undefined, summary);

    return new Response(JSON.stringify(summary), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    console.error(error);
    const message = error instanceof Error ? error.message : String(error);
    await insertRunLog("fixture_enrichment", "error", startedAt, 0, message);
    return new Response(JSON.stringify({ error: message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    });
  } finally {
    if (acquiredLock) {
      try {
        await supabase.rpc("advisory_unlock", { lock_name: LOCK_NAME });
      } catch (e) {
        const msg = e && typeof e === "object" && "message" in e ? (e as any).message : String(e);
        console.error("Unlock error:", msg);
      }
    }
  }
});
