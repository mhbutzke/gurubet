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
- `npm run monitor` – displays comprehensive pipeline status including ingestion summary, table counts, and enriched fixtures.
- `npm run backfill:enrichment` – backfills enrichment tables (participants, scores, lineups, odds) for historical fixtures using the live edge function.

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

## Sistema Expandido

### Edge Functions Ativas

1. **fixture-delta** - Atualização incremental de fixtures (2x por dia)
2. **fixture-enrichment** - Enriquecimento com participantes, lineups, períodos, scores, odds e clima (2x por dia)

### Novas Tabelas de Enriquecimento

- `fixture_participants` – participantes (times) das fixtures com flags de localização, winner e payload bruto (`meta`)
- `fixture_scores` – placares por tipo/período com resultado e payload completo
- `fixture_periods` – períodos do jogo (1º tempo, 2º tempo, prorrogação, etc)
- `fixture_lineups` – escalações dos times com posições/coordenadas
- `fixture_lineup_details` – detalhes da escalação (substituições, banco, etc)
- `fixture_odds` – odds básicas das casas de apostas para o fixture
- `fixture_weather` – condições climáticas do jogo (1 linha por fixture)

### Views e Funções Úteis

- `v_fixtures_with_participants` – fixtures com participantes agregados + string `teams`
- `v_ingestion_summary` – relatório de execuções dos últimos 30 dias
- `get_fixture_stats(fixture_id)` – estatísticas rápidas de uma fixture
- `get_team_fixtures(team_id, limit)` – fixtures de um time específico

### Monitoramento

Use `npm run monitor` para visualizar:
- Status das ingestões
- Contadores de registros
- Fixtures recentes enriquecidas
- Status dos cron jobs

### Agendamentos Automáticos

- **fixture-delta**: 6:00 e 18:00 UTC (fixtures, events, statistics)
- **fixture-enrichment**: 8:00 e 20:00 UTC (participants, lineups, scores, períodos, odds, weather)

Variáveis de ambiente úteis para a função de enrichment:

- `FIXTURE_ENRICHMENT_DAYS_BACK` / `FIXTURE_ENRICHMENT_DAYS_FORWARD` – janela de reprocessamento (default 3 dias para trás, 1 para frente).
- `FIXTURE_ENRICHMENT_INCLUDES` – lista de includes usada no endpoint `fixtures/multi`.

### Backfill histórico

- Rodar `npm run backfill:enrichment -- --start-date 1998-01-01 --end-date 2020-01-01 --page-size 500 --chunk-size 25` para enriquecer fixtures antigas.
- A ferramenta processa páginas cronológicas, identifica fixtures sem `fixture_participants`, `fixture_scores`, `fixture_lineups` ou `fixture_lineup_details` e aciona a edge function em blocos.
- Ajuste `--targets` (lista separada por vírgulas) para incluir outras tabelas (`fixture_odds`, `fixture_periods`, etc.) e `--sleep-ms` para respeitar limites da API.
- Queries úteis para acompanhar o progresso:

  ```sql
  select date_trunc('year', starting_at) as year,
         count(*) filter (where participant_count = 0) as fixtures_missing_participants,
         count(*) as total_fixtures
  from (
    select f.id,
           f.starting_at,
           (select count(*) from fixture_participants fp where fp.fixture_id = f.id) as participant_count
    from fixtures f
  ) t
  group by 1
  order by 1;
  ```

## Validação de Cron Jobs e Ingestões

- SQL: `sql/validate_cron_jobs.sql` lista cron jobs relevantes e últimas execuções com duração.
- Script Node: `node scripts/validateCronJobs.js` imprime:
  - Estado dos jobs (`cron.job`)
  - Últimos `cron.job_run_details`
  - Últimos `ingestion_runs`
  - Amostra de métricas HTTP coletadas nas Edge Functions

Exemplo de execução:

```bash
psql "$DATABASE_URL" -f sql/validate_cron_jobs.sql
node scripts/validateCronJobs.js
```
