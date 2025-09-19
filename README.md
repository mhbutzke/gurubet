# GURUBET Data Pipeline

Ingests football data from the Sportmonks API (v3) and persists it to a Supabase Postgres project. The scripts cover reference entities (continents, leagues, teams, etc.) and competition data such as fixtures.

## Getting Started

1. **Install dependencies**
   ```bash
   npm install
   ```
2. **Configure environment**
   Create a `.env` file (ignored by git) with:
   ```dotenv
   SUPABASE_URL=...
   SUPABASE_SERVICE_ROLE_KEY=...
   SPORTMONKS_API_KEY=...
   # Optional tuning
   # SPORTMONKS_PER_PAGE=50
   # SPORTMONKS_MAX_PAGES=Infinity
   # SPORTMONKS_RATE_THRESHOLD=50
   # SPORTMONKS_RATE_WAIT_MS=1000
   # SUPABASE_UPSERT_CHUNK=500
   ```

## Scripts

- `npm run test:connection` – validates Supabase credentials via the Admin API.
- `npm run inspect:endpoint -- <endpoint> [perPage]` – prints metadata/sample for any Sportmonks endpoint (e.g. `core/countries`).
- `npm run inspect:fixtures` – convenience wrapper to review the fixtures payload.
- `npm run seed:fixtures` – upserts a sample of fixtures (20 by default).
- `npm run seed:all` – orchestrates ingestion for every configured entity. Use `--only` to target specific tables (e.g. `npm run seed:all -- --only fixtures`).

Each seeding step uses `upsert` to keep data idempotent and respects the API pagination rules (including `filters=populate`) plus Sportmonks rate limiting headers.

## SQL Migrations

`sql/` contains schema definitions:
- `0001_create_fixtures.sql` – base fixtures table (stage/state columns optional).
- `0002_create_core_entities.sql` – continents, countries, regions, cities, core types.
- `0003_create_football_entities.sql` – leagues, teams, seasons, etc.
- `0004_alter_fixtures_nullable.sql` – relaxes not-null constraints to match API payloads.

Apply the migrations in order using Supabase SQL editor or `psql`:
```bash
psql "postgres://postgres:<password>@db.<project>.supabase.co:6543/postgres?sslmode=require" -f sql/0001_create_fixtures.sql
```

## Logs

Execution logs (`*.log`) remain local-only and are excluded via `.gitignore`.
