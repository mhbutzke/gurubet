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

const DEFAULT_LIMIT = Number(Deno.env.get("FIXTURE_DELTA_LIMIT") ?? 5000);
const PER_PAGE = Number(Deno.env.get("FIXTURE_DELTA_PER_PAGE") ?? 50);
const BATCH_SIZE = Number(Deno.env.get("FIXTURE_DELTA_BATCH_SIZE") ?? 50);
const DAYS_BACK = Number(Deno.env.get("FIXTURE_DELTA_DAYS_BACK") ?? 1);
const DAYS_FORWARD = Number(Deno.env.get("FIXTURE_DELTA_DAYS_FORWARD") ?? 0);
const RATE_THRESHOLD = Number(Deno.env.get("SPORTMONKS_RATE_THRESHOLD") ?? 50);
const RATE_WAIT_MS = Number(Deno.env.get("SPORTMONKS_RATE_WAIT_MS") ?? 1000);
const MAX_RETRIES = Number(Deno.env.get("SPORTMONKS_MAX_RETRIES") ?? 3);
const RETRY_BASE_MS = Number(Deno.env.get("SPORTMONKS_RETRY_BASE_MS") ?? 500);

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

function normaliseTimestamp(value: unknown) {
  if (!value || typeof value !== "string") return null;
  if (value.includes("T")) return value;
  return value.replace(" ", "T");
}

function mapFixture(raw: any, runTimestamp: string) {
  return {
    id: raw.id,
    sport_id: raw.sport_id,
    league_id: raw.league_id,
    season_id: raw.season_id,
    stage_id: raw.stage_id,
    group_id: raw.group_id,
    aggregate_id: raw.aggregate_id,
    round_id: raw.round_id,
    state_id: raw.state_id,
    venue_id: raw.venue_id,
    name: raw.name,
    starting_at: normaliseTimestamp(raw.starting_at),
    result_info: raw.result_info ?? null,
    leg: raw.leg ?? null,
    details: raw.details ?? null,
    length: toNumber(raw.length),
    placeholder: toBool(raw.placeholder) ?? false,
    has_odds: toBool(raw.has_odds) ?? false,
    has_premium_odds: toBool(raw.has_premium_odds) ?? false,
    starting_at_timestamp: toNumber(raw.starting_at_timestamp),
    updated_at: runTimestamp,
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

function extractStatValue(stat: any) {
  if (!stat || typeof stat !== "object") return { numeric: null, text: null };
  const { data } = stat;
  if (!data || typeof data !== "object") return { numeric: null, text: null };
  const value = data.value ?? data.count ?? data.total ?? data.avg ?? null;
  if (value === null || value === undefined) return { numeric: null, text: null };
  if (typeof value === "number") return { numeric: value, text: String(value) };
  const num = Number(value);
  return {
    numeric: Number.isFinite(num) ? num : null,
    text: String(value),
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

async function chunkedUpsert(table: string, rows: any[], chunkSize = 500) {
  for (let i = 0; i < rows.length; i += chunkSize) {
    const chunk = rows.slice(i, i + chunkSize);
    const { error } = await supabase.from(table).upsert(chunk, { onConflict: "id" });
    if (error) {
      throw new Error(`Upsert into ${table} failed: ${error.message}`);
    }
  }
}

async function updateIngestionState(entity: string, lastId: number | null, lastTimestamp: string | null) {
  const records = [{
    entity,
    last_id: lastId,
    last_timestamp: lastTimestamp,
  }];
  const { error } = await supabase
    .from("ingestion_state")
    .upsert(records, { onConflict: "entity" });
  if (error) {
    throw new Error(`Failed to update ingestion state for ${entity}: ${error.message}`);
  }
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

async function getIngestionState(entity: string) {
  const { data, error } = await supabase
    .from("ingestion_state")
    .select("last_id, last_timestamp")
    .eq("entity", entity)
    .maybeSingle();
  if (error) {
    throw new Error(`Failed to read ingestion state: ${error.message}`);
  }
  return {
    lastId: data?.last_id ?? null,
    lastTimestamp: data?.last_timestamp ?? null,
  };
}

async function collectFixtures(startAfter: number, limit: number, metrics?: { http: Array<Record<string, unknown>> }) {
  const fixtures: any[] = [];
  let cursor = startAfter;
  let page = 1;

  while (fixtures.length < limit) {
    const url = new URL(`${SPORTMONKS_BASE}/football/fixtures`);
    url.searchParams.set("api_token", SPORTMONKS_API_KEY);
    url.searchParams.set("filters", `IdAfter:${cursor}`);
    url.searchParams.set("per_page", String(Math.min(PER_PAGE, limit - fixtures.length)));
    url.searchParams.set("page", String(page));

    const { payload, rateLimit } = await fetchSportmonks(url, metrics);
    await maybePause(rateLimit, "fixtures");

    const batch = payload?.data ?? [];
    if (!Array.isArray(batch) || batch.length === 0) break;

    fixtures.push(...batch);
    const maxId = batch.reduce((max: number, item: any) => item.id > max ? item.id : max, cursor);
    cursor = maxId;

    if (batch.length < PER_PAGE) break;
    page += 1;
  }

  return { fixtures, lastId: cursor };
}

function formatDate(date: Date) {
  return date.toISOString().slice(0, 10);
}

async function collectFixturesBetween(fromDate: string, toDate: string, metrics?: { http: Array<Record<string, unknown>> }) {
  const fixtures: any[] = [];
  let page = 1;

  while (true) {
    const url = new URL(`${SPORTMONKS_BASE}/football/fixtures/between/${fromDate}/${toDate}`);
    url.searchParams.set("api_token", SPORTMONKS_API_KEY);
    url.searchParams.set("per_page", String(PER_PAGE));
    url.searchParams.set("page", String(page));

    const { payload, rateLimit } = await fetchSportmonks(url, metrics);
    await maybePause(rateLimit, "fixtures/between");

    const batch = payload?.data ?? [];
    if (!Array.isArray(batch) || batch.length === 0) break;

    fixtures.push(...batch);

    if (batch.length < PER_PAGE) break;
    page += 1;
  }

  return fixtures;
}

async function fetchDetailsForFixtures(ids: number[], metrics?: { http: Array<Record<string, unknown>> }) {
  const runTimestamp = new Date().toISOString();
  const eventRows: any[] = [];
  const statRows: any[] = [];

  for (let i = 0; i < ids.length; i += BATCH_SIZE) {
    const batch = ids.slice(i, i + BATCH_SIZE);
    if (!batch.length) continue;

    const url = new URL(`${SPORTMONKS_BASE}/football/fixtures/multi/${batch.join(",")}`);
    url.searchParams.set("api_token", SPORTMONKS_API_KEY);
    url.searchParams.set("include", "events;statistics.type");

    const { payload, rateLimit } = await fetchSportmonks(url, metrics);
    await maybePause(rateLimit, "fixtures/multi");

    const fixtures = payload?.data ?? [];
    fixtures.forEach((fixture: any) => {
      if (Array.isArray(fixture.events)) {
        fixture.events.forEach((event: any) => {
          eventRows.push(mapEvent(event, runTimestamp));
        });
      }
      if (Array.isArray(fixture.statistics)) {
        fixture.statistics.forEach((stat: any) => {
          statRows.push(mapStatistic(stat, runTimestamp));
        });
      }
    });
  }

  return { eventRows, statRows };
}

serve(async (request) => {
  const startedAt = new Date().toISOString();
  const LOCK_NAME = "edge:fixture-delta";
  let acquiredLock = false;
  try {
    const metrics: { http: Array<Record<string, unknown>> } = { http: [] };
    const { data: gotLock, error: lockError } = await supabase.rpc("try_advisory_lock", { lock_name: LOCK_NAME });
    if (lockError) {
      console.error("Lock error:", lockError.message);
      await insertRunLog("fixtures", "noop", startedAt, 0, undefined, { reason: "lock_error" });
      return new Response(JSON.stringify({ message: "Lock error - aborting" }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      });
    }
    if (!gotLock) {
      await insertRunLog("fixtures", "noop", startedAt, 0, undefined, { reason: "concurrent_lock" });
      return new Response(JSON.stringify({ message: "Already running - noop" }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      });
    }
    acquiredLock = true;

    const payload = await request.json().catch(() => ({}));
    const explicitStart = typeof payload.startAfter === "number" ? payload.startAfter : null;
    const limit = typeof payload.limit === "number" ? payload.limit : DEFAULT_LIMIT;

    const payloadFromDate = typeof payload.fromDate === "string" ? payload.fromDate : null;
    const payloadToDate = typeof payload.toDate === "string" ? payload.toDate : null;

    const state = await getIngestionState("fixtures");
    const startAfter = explicitStart ?? state.lastId ?? 0;
    const { fixtures: newFixtures, lastId } = await collectFixtures(startAfter, limit, metrics);

    const fixtureMap = new Map<number, any>();
    newFixtures.forEach((fixture) => fixtureMap.set(fixture.id, fixture));

    let rangeFixtures: any[] = [];
    const usePayloadRange = payloadFromDate && payloadToDate;
    const parsedDaysBack = payload.daysBack !== undefined ? Number(payload.daysBack) : NaN;
    const parsedDaysForward = payload.daysForward !== undefined ? Number(payload.daysForward) : NaN;
    const daysBack = Number.isFinite(parsedDaysBack) ? parsedDaysBack : DAYS_BACK;
    const daysForward = Number.isFinite(parsedDaysForward) ? parsedDaysForward : DAYS_FORWARD;

    // Só puxa a janela entre datas quando explicitamente solicitada ou quando
    // os parâmetros daysBack/daysForward forem positivos. Com daysBack = 0
    // (uso recorrente), evitamos reprocessar toda a janela a cada execução.
    if (usePayloadRange || daysBack > 0 || daysForward > 0) {
      let fromDate: string;
      let toDate: string;

      if (usePayloadRange) {
        fromDate = payloadFromDate!;
        toDate = payloadToDate!;
      } else {
        const today = new Date();
        const utcToday = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate()));
        const from = new Date(utcToday);
        from.setUTCDate(from.getUTCDate() - Math.max(0, daysBack));
        const to = new Date(utcToday);
        to.setUTCDate(to.getUTCDate() + Math.max(0, daysForward));
        fromDate = formatDate(from);
        toDate = formatDate(to);
      }

      rangeFixtures = await collectFixturesBetween(fromDate, toDate, metrics);
      rangeFixtures.forEach((fixture) => fixtureMap.set(fixture.id, fixture));
    }

    const fixtures = Array.from(fixtureMap.values());

    if (!fixtures.length) {
      await insertRunLog("fixtures", "noop", startedAt, 0, undefined, {
        startAfter,
        daysBack,
        daysForward,
      });
      return new Response(JSON.stringify({ message: "No new fixtures", startAfter }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      });
    }

    const runTimestamp = new Date().toISOString();
    const mappedFixtures = fixtures.map((item) => mapFixture(item, runTimestamp));
    await chunkedUpsert("fixtures", mappedFixtures);

    const fixtureIds = fixtures.map((f) => f.id);
    const { eventRows, statRows } = await fetchDetailsForFixtures(fixtureIds, metrics);

    if (eventRows.length) {
      await chunkedUpsert("fixture_events", eventRows);
    }
    if (statRows.length) {
      await chunkedUpsert("fixture_statistics", statRows);
    }

    const maxStartingAt = fixtures
      .map((f) => normaliseTimestamp(f.starting_at))
      .filter((value): value is string => Boolean(value))
      .sort()
      .pop() ?? null;

    const maxFixtureId = fixtureIds.reduce(
      (acc, id) => (id > acc ? id : acc),
      state.lastId ?? 0,
    );
    const newLastId = Math.max(state.lastId ?? 0, lastId ?? 0, maxFixtureId);
    const newLastTimestamp = maxStartingAt ?? state.lastTimestamp ?? null;

    await updateIngestionState("fixtures", newLastId, newLastTimestamp);

    await insertRunLog("fixtures", "success", startedAt, fixtures.length, undefined, {
      newFixtures: newFixtures.length,
      dateRangeFixtures: rangeFixtures.length,
      events: eventRows.length,
      statistics: statRows.length,
      lastId: newLastId,
      daysBack,
      daysForward,
      http: metrics.http,
    });

    return new Response(
      JSON.stringify({
        fixturesProcessed: fixtures.length,
        lastId: newLastId,
        eventsUpserted: eventRows.length,
        statisticsUpserted: statRows.length,
      }),
      { headers: { "Content-Type": "application/json" }, status: 200 },
    );
  } catch (error) {
    console.error(error);
    const message = error instanceof Error ? error.message : String(error);
    await insertRunLog("fixtures", "error", startedAt, 0, message);
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
