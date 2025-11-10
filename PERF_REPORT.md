# PERF_REPORT.md

## Status Snapshot
| Area | Baseline | Current Risk | Next Action |
|------|----------|--------------|-------------|
| LV Perf | Pending | Unknown | Instrument mount/render timings via Telemetry |

## Purpose & Scope
Track render, diff, and DB performance metrics before/after each modernization phase.

## Sources & Evidence
- `docs/shared/metrics.md` (Table PM-01)
- PromEx dashboards and Grafana exports
- Telemetry events emitted from LiveViews and contexts
- Database query logs / EXPLAIN data

## 1. Baseline Metrics
Summaries of current TTFP, LV mount, render diff, DB p95/99, memory/connection.

- Initial dev snapshot (2025-11-10): unauthenticated GET requests redirected by auth pipeline.
  - `/` → 302 in 20ms.
  - `/devices` → 302 in ~0.7ms.
  - `/bulk/test` → 302 in 1ms.
- Need authenticated session to capture actual LiveView mount/render timings; no Telemetry log output observed yet.

## 2. Instrumentation Coverage
Describe telemetry events, PromEx hooks, and logging needed to keep data accurate.

- NetAuto.PromEx.ObservabilityPlugin defines metrics for runner, run, LiveView, and chunk events but we have not validated that emitters fire on mount/render; no `[:net_auto, :liveview, :mount]` logs observed yet.

## 3. Bottleneck Catalog
| ID | Area | Symptom | Evidence | Proposed Fix | Status |
|----|------|---------|----------|--------------|--------|
| PRF-01 | TBD | TBD | TBD | TBD | TBD |

## 4. Improvement Tracking
| Metric | Before | After | Delta | Evidence |
|--------|--------|-------|-------|----------|
| TTFP | TBD | TBD | TBD | PRF-## |

## 5. Action Items
List upcoming profiling tasks, indexes to add, or LiveView stream optimizations with owners.

## Verification & Evidence Links
Attach Grafana screenshots, flamegraphs, and PR links showing perf improvements.
