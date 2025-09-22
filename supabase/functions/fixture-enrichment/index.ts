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
      default:
        break;
    }
  }
  if (includeTokens.size === 0) return DEFAULT_INCLUDES;
  return Array.from(includeTokens).join(";");
}

const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

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

function mapWeather(weather: any, fixtureId: number, runTimestamp: string) {
  return {
    fixture_id: fixtureId,
    temperature_celsius: toNumber(weather.temperature_celsius),
    temperature_fahrenheit: toNumber(weather.temperature_fahrenheit),
    humidity: toNumber(weather.humidity),
    pressure: toNumber(weather.pressure),
    wind_speed: toNumber(weather.wind_speed),
    wind_direction: toNumber(weather.wind_direction),
    clouds: toNumber(weather.clouds),
    condition_code: weather.condition_code ?? null,
    condition_description: weather.condition_description ?? null,
    condition_icon: weather.condition_icon ?? null,
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
  const targets = normaliseTargets(rawTargets);

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
  const participantRows: any[] = [];
  const scoreRows: any[] = [];
  const periodRows: any[] = [];
  const lineupRows: any[] = [];
  const lineupDetailRows: any[] = [];
  const weatherRows: any[] = [];
  const oddsRows: any[] = [];

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
    });
  }

  return { participantRows, scoreRows, periodRows, lineupRows, lineupDetailRows, weatherRows, oddsRows };
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
      participantRows,
      scoreRows,
      periodRows,
      lineupRows,
      lineupDetailRows,
      weatherRows,
      oddsRows,
    } = await fetchEnrichmentData(fixtureIds, includes, targetSet, metrics);

    if (targetSet.has("fixture_participants") && participantRows.length) {
      await chunkedUpsert("fixture_participants", participantRows);
    }
    if (targetSet.has("fixture_scores") && scoreRows.length) {
      await chunkedUpsert("fixture_scores", scoreRows);
    }
    if (targetSet.has("fixture_periods") && periodRows.length) {
      await chunkedUpsert("fixture_periods", periodRows);
    }
    if (targetSet.has("fixture_lineups") && lineupRows.length) {
      await chunkedUpsert("fixture_lineups", lineupRows);
    }
    if (targetSet.has("fixture_lineup_details") && lineupDetailRows.length) {
      await chunkedUpsert("fixture_lineup_details", lineupDetailRows);
    }
    if (targetSet.has("fixture_weather") && weatherRows.length) {
      await chunkedUpsert("fixture_weather", weatherRows);
    }
    if (targetSet.has("fixture_odds") && oddsRows.length) {
      await chunkedUpsert("fixture_odds", oddsRows);
    }

    const summary = {
      fixturesEnriched: fixtureIds.length,
      participants: participantRows.length,
      scores: scoreRows.length,
      periods: periodRows.length,
      lineups: lineupRows.length,
      lineupDetails: lineupDetailRows.length,
      weather: weatherRows.length,
      odds: oddsRows.length,
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
