---
name: Roadmap de Cobertura 2023–2025
about: Acompanhar metas de completude por alvo e ações de backfill/monitoramento
title: "Roadmap: Cobertura 2023–2025 (participants/scores/periods/lineups/odds/weather)"
labels: enhancement, data-quality, monitoring
assignees: ''
---

## Metas por ano

- 2025: 99.9% em todos os targets (participants, scores, periods, lineups, lineup_details, odds, weather*)
- 2024: 99.0%
- 2023: 95.0%

Observação: `weather` depende de cobertura do provider; se necessário usar fallback externo (ex.: Open‑Meteo) para atingir meta.

## Cron jobs (estado esperado)

- Histórico leve (*/5 04–10 UTC): `participants,scores,periods` (limit 1000)
- Histórico pesado (1-59/5 04–10 UTC): `lineups,lineup_details,odds,weather` (limit 600)
- Lineups hourly catch‑up (15 00–03,11–23 UTC): `lineups,lineup_details` (limit 80)
- Guards 2023/2024/2025 (*/10 04–10 UTC): `mode=missing` todos alvos (limit 800)
- Delta live (*/5 00–03,11–23 UTC) e delta job (*/15 00–03,11–23 UTC)
- Snapshot cobertura diária (04:45 UTC) → `coverage_snapshots`
- Alertas de cobertura (05:00 UTC) → `coverage_alerts`

## Tabelas/visões úteis

- `mv_coverage_by_month_target` (materialized view)
- `coverage_snapshots` (histórico diário)
- `coverage_alerts` (eventos abaixo do threshold)
- `ingestion_runs` (logs de execução)

## Queries rápidas

```sql
-- Cobertura 2023/2024/2025 por alvo
WITH yr(y) AS (VALUES (2023),(2024),(2025))
SELECT y AS year,
  ROUND(100.0 * COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM fixture_participants fp WHERE fp.fixture_id=f.id)) / COUNT(*), 2) AS pct_participants,
  ROUND(100.0 * COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM fixture_scores s WHERE s.fixture_id=f.id)) / COUNT(*), 2) AS pct_scores,
  ROUND(100.0 * COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM fixture_periods p WHERE p.fixture_id=f.id)) / COUNT(*), 2) AS pct_periods,
  ROUND(100.0 * COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM fixture_lineups l WHERE l.fixture_id=f.id)) / COUNT(*), 2) AS pct_lineups,
  ROUND(100.0 * COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM fixture_lineup_details d WHERE d.fixture_id=f.id)) / COUNT(*), 2) AS pct_lineup_details,
  ROUND(100.0 * COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM fixture_odds o WHERE o.fixture_id=f.id)) / COUNT(*), 2) AS pct_odds,
  ROUND(100.0 * COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM fixture_weather w WHERE w.fixture_id=f.id)) / COUNT(*), 2) AS pct_weather
FROM yr
JOIN fixtures f ON f.starting_at >= make_date(y,1,1) AND f.starting_at < make_date(y+1,1,1)
GROUP BY y
ORDER BY y;
```

## Checklist de execução

- [ ] 2025 ≥ 99.9% em todos os targets
- [ ] 2024 ≥ 99.0% em todos os targets
- [ ] 2023 ≥ 95.0% em todos os targets
- [ ] Crons históricos (light/heavy) executando sem “noop” excessivo
- [ ] Lineups hourly catch‑up eficaz para jogos recentes
- [ ] Alertas diários sem violações pendentes

## Tarefas técnicas relacionadas

- [ ] Particionamento por ano – fase 1: `fixture_year` + índices (agendado)
- [ ] Particionamento por ano – fase 2: converter `fixture_events`/`fixture_statistics` em tabelas particionadas
- [ ] (Opcional) Fallback de weather

## Comentários automáticos (opcional)

Sugestão: GitHub Action diária 05:50 UTC que consulta `coverage_snapshots` e publica resumo nos comentários desta issue. Requer secrets do banco.

