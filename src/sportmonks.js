require('dotenv').config();

const BASE_URL = 'https://api.sportmonks.com/v3';
const MAX_PER_PAGE = 50;
const POPULATE_MAX_PER_PAGE = 1000;
const DEFAULT_PER_PAGE = Math.min(
  MAX_PER_PAGE,
  clampNumber(process.env.SPORTMONKS_PER_PAGE, MAX_PER_PAGE),
);
const DEFAULT_MAX_PAGES = Number.isFinite(Number(process.env.SPORTMONKS_MAX_PAGES))
  ? Number(process.env.SPORTMONKS_MAX_PAGES)
  : Infinity;
const RATE_THRESHOLD = clampNumber(process.env.SPORTMONKS_RATE_THRESHOLD, 50);
const RATE_WAIT_MS = clampNumber(process.env.SPORTMONKS_RATE_WAIT_MS, 1000);
const MAX_REQUESTS_PER_WINDOW = clampNumber(process.env.SPORTMONKS_RATE_LIMIT ?? 3000, 3000);

function clampNumber(value, fallback) {
  if (value === undefined || value === null) return fallback;
  const num = Number(value);
  if (!Number.isFinite(num)) {
    return fallback;
  }
  return num;
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function ensureToken() {
  const token = process.env.SPORTMONKS_API_KEY;
  if (!token) {
    throw new Error('SPORTMONKS_API_KEY not configured in environment');
  }
  return token;
}

function normaliseParam(value, joinWith) {
  if (value === undefined || value === null) return null;
  if (Array.isArray(value)) {
    return value.join(joinWith);
  }
  return String(value);
}

function applyQueryParams(url, params) {
  Object.entries(params).forEach(([key, value]) => {
    if (value === undefined || value === null || value === '') return;
    url.searchParams.set(key, value);
  });
}

async function fetchEntities(path, options = {}) {
  const token = ensureToken();

  const populate = options.populate === true;
  const perPageInput = Number(options.perPage ?? DEFAULT_PER_PAGE) || DEFAULT_PER_PAGE;
  const perPage = populate
    ? Math.min(POPULATE_MAX_PER_PAGE, perPageInput || POPULATE_MAX_PER_PAGE)
    : Math.min(MAX_PER_PAGE, Math.max(1, perPageInput || DEFAULT_PER_PAGE));

  const maxPagesRaw = options.maxPages ?? DEFAULT_MAX_PAGES;
  const maxPages = Number.isFinite(Number(maxPagesRaw)) ? Number(maxPagesRaw) : Infinity;

  const includes = normaliseParam(options.include ?? options.includes, ';');
  const select = normaliseParam(options.select, ',');
  const filtersList = [];
  const filtersParam = normaliseParam(options.filters, ';');
  if (filtersParam) filtersList.push(filtersParam);
  if (populate && !filtersList.some((value) => value.split(';').includes('populate'))) {
    filtersList.push('populate');
  }

  const baseParams = {
    api_token: token,
    per_page: String(perPage),
  };

  if (includes) baseParams.include = includes;
  if (select) baseParams.select = select;
  if (filtersList.length) baseParams.filters = filtersList.join(';');

  const additionalParams = options.query ?? options.params ?? {};

  let currentPage = 1;
  const results = [];
  let requestCount = 0;
  const startTime = Date.now();

  while (currentPage <= maxPages) {
    if (requestCount >= MAX_REQUESTS_PER_WINDOW) {
      const elapsedMs = Date.now() - startTime;
      const remainingMs = Math.max(0, 60 * 60 * 1000 - elapsedMs);
      if (remainingMs > 0) {
        console.log(
          `Reached configured max requests per window (${MAX_REQUESTS_PER_WINDOW}) for ${path}. ` +
            `Sleeping ${remainingMs}ms to respect rate limits.`,
        );
        await sleep(remainingMs);
      }
      requestCount = 0;
    }

    const url = new URL(`${BASE_URL}/${path}`);
    applyQueryParams(url, baseParams);
    applyQueryParams(url, additionalParams);
    url.searchParams.set('page', String(currentPage));

    const response = await fetch(url);
    requestCount += 1;
    if (!response.ok) {
      const body = await response.text();
      throw new Error(`Sportmonks request failed (${response.status}): ${body}`);
    }

    const payload = await response.json();
    const data = payload.data ?? [];
    results.push(...data);

    const pagination = payload.pagination ?? {};
    const hasMore = Boolean(pagination.has_more);

    if (typeof options.onPage === 'function') {
      await options.onPage({
        page: currentPage,
        data,
        pagination,
        rateLimit: payload.rate_limit ?? null,
      });
    }

    const rateLimit = payload.rate_limit ?? null;
    if (rateLimit) {
      const remaining = Number(rateLimit.remaining);
      if (Number.isFinite(remaining) && remaining <= RATE_THRESHOLD) {
        let waitFor = RATE_WAIT_MS;
        if (Number.isFinite(Number(rateLimit.resets_in_seconds)) && remaining > 0) {
          const averageSpacing = Math.ceil((Number(rateLimit.resets_in_seconds) * 1000) / remaining);
          waitFor = Math.max(waitFor, averageSpacing);
        }
        console.log(
          `Rate limit nearing for ${path} (entity: ${rateLimit.requested_entity}, remaining: ${remaining}). ` +
            `Pausing for ${waitFor}ms.`,
        );
        await sleep(waitFor);
      }
    }

    if (!hasMore || !pagination.next_page) {
      break;
    }

    currentPage += 1;
  }

  return results;
}

module.exports = {
  fetchEntities,
};
