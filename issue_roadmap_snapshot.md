## Roadmap: Cobertura 2023–2025 (dados completos + near real-time)

### Metas
- 2025: 99.9% em todos os targets
- 2024: 99.0%
- 2023: 95.0%

### Snapshot atual (por ano)
- 2023: total=27.364 | participants=0.00% | scores=0.00% | periods=0.00% | lineups=0.00% | lineup_details=0.00% | odds=0.00% | weather=0.00%
- 2024: total=29.483 | participants=0.39% | scores=0.39% | periods=0.39% | lineups=0.36% | lineup_details=0.36% | odds=0.30% | weather=0.00%
- 2025: total=25.194 | participants=10.08% | scores=9.78% | periods=9.72% | lineups=6.53% | lineup_details=6.37% | odds=6.93% | weather=0.00%

Obs.: weather depende de cobertura do provider e pode ficar 0% para muitos jogos históricos.

### Cron jobs ativos
- enrichment_historic_light: */5 04–10 UTC (01–07 BRT) — targets: participants,scores,periods — limit 1000
- enrichment_historic_heavy: 1-59/5 04–10 UTC — targets: lineups,lineup_details,odds,weather — limit 600
- lineups_hourly_catchup: 15 00–03,11–23 UTC — targets: lineups,lineup_details — limit 80
- guard_coverage_2023/2024/2025: */10 04–10 UTC — mode=missing, todos os targets — limit 800
- fixture_delta_live: */5 00–03,11–23 UTC
- fixture_delta_job: */15 00–03,11–23 UTC
- coverage_snapshot_daily: 04:45 UTC — refresh MV + gravar em coverage_snapshots
- coverage_alerts_daily: 05:00 UTC — grava alertas em coverage_alerts

### Tabelas/visões de suporte
- `mv_coverage_by_month_target` (materialized view)
- `coverage_snapshots` (histórico diário)
- `coverage_alerts` (abaixo do threshold)
- `ingestion_runs` (logs)

### Plano
- Usar janela BRT 01–08 para backfill histórico (split leve/pesado) até atingir metas de 2023 e 2024 (completou uma vez, estável).
- Manter 2025 com guards + hourly e diários para near real-time.
- Preparação para particionamento por ano aplicada (fase 1); backfill de fixture_year e índices CONCURRENTLY agendados 05:35–05:40 UTC.
- Fase 2: converter `fixture_events` e `fixture_statistics` para tabelas particionadas em janela de manutenção.

### Checklist
- [ ] 2025 ≥ 99.9% em todos os targets
- [ ] 2024 ≥ 99.0% em todos os targets
- [ ] 2023 ≥ 95.0% em todos os targets
- [ ] Crons históricos executando sem "noop" excessivo
- [ ] Alertas sem violações pendentes

