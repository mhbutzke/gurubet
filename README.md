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
- `npm run seed:fixture-details` – downloads events and statistics for fixtures in batches. Supports options such as `--limit`, `--start-after`, `--batch-size`, `--page-size`, `--skip-events`, and `--skip-stats`.

Each seeding step uses `upsert` to keep data idempotent and respects the API pagination rules (including `filters=populate`) plus Sportmonks rate limiting headers.

## SQL Migrations

`sql/` contains schema definitions:
- `0001_create_fixtures.sql` – base fixtures table (stage/state columns optional).
- `0002_create_core_entities.sql` – continents, countries, regions, cities, core types.
- `0003_create_football_entities.sql` – leagues, teams, seasons, etc.
- `0004_alter_fixtures_nullable.sql` – relaxes not-null constraints to match API payloads.
- `0005_create_fixture_details.sql` – schema for `fixture_events` and `fixture_statistics`.
- `0006_create_ingestion_metadata.sql` – cria as tabelas `metadata.ingestion_state` e `metadata.ingestion_runs` para orquestrar cargas incrementais.
- `0007_create_ingestion_tables_public.sql` – replica as tabelas de metadados no schema `public` para uso das Edge Functions.

Apply the migrations in order using Supabase SQL editor or `psql`:
```bash
psql "postgres://postgres:<password>@db.<project>.supabase.co:6543/postgres?sslmode=require" -f sql/0001_create_fixtures.sql
```

## Logs

Execution logs (`*.log`) remain local-only and are excluded via `.gitignore`.

## Incremental Updates

O repositório inclui uma Edge Function (`supabase/functions/fixture-delta`) que executa a carga incremental diária diretamente dentro do Supabase. Passos recomendados:

1. Aplicar os migrations até `0007_create_ingestion_tables_public.sql` para habilitar as tabelas de estado.
2. Definir as variáveis no projeto Supabase (`SERVICE_ROLE_KEY`, `SPORTMONKS_API_KEY`, opcionais `FIXTURE_DELTA_LIMIT`, `FIXTURE_DELTA_PER_PAGE`, `FIXTURE_DELTA_BATCH_SIZE`, `FIXTURE_DELTA_DAYS_BACK`, `FIXTURE_DELTA_DAYS_FORWARD`). No dashboard, evite prefixos `SUPABASE_` (o painel bloqueia esses nomes); use exatamente `SERVICE_ROLE_KEY`.
3. Implantar a função: `supabase functions deploy fixture-delta`.
4. Testar manualmente. Exemplos:
   - CLI recente: `supabase functions invoke fixture-delta --headers "Authorization: Bearer <ANON_KEY>" --body '{"limit": 1000}'`
   - Via SQL Editor (extensões `pg_net` + `pg_cron`):
     ```sql
     select net.http_post(
       url      := 'https://<project>.supabase.co/functions/v1/fixture-delta',
       body     := jsonb_build_object('limit', 1000),
       headers  := jsonb_build_object(
         'Content-Type', 'application/json',
         'Authorization', 'Bearer <ANON_KEY>'
       )
     );
     ```
5. Agendar via cron do Supabase (ex.: duas execuções diárias):
   ```bash
   supabase functions schedule create fixture-delta-daily \
     --function fixture-delta \
     --cron "0 6,18 * * *"
   ```

A função lê o último checkpoint em `ingestion_state`, busca fixtures novos via `filters=IdAfter`, revisita uma janela recente configurável (`FIXTURE_DELTA_DAYS_BACK`/`FORWARD`) e faz `upsert` em `fixtures`, `fixture_events`, `fixture_statistics`. Cada execução é registrada em `ingestion_runs` para auditoria.
