# TEST_PLAN.md

## Status Snapshot
| Area | Baseline | Current Risk | Next Action |
|------|----------|--------------|-------------|
| Coverage | Pending | Unknown | Capture baseline mix test --cover results |

## Purpose & Scope
Define testing strategy (unit, LiveView, integration, property) that guarantees zero behavior regressions during modernization.

## Sources & Evidence
- CODE_REVIEW.md findings
- `docs/shared/metrics.md` (Table TM-01)
- Existing test helpers (data case, LiveView test modules)

## 1. Coverage Targets
Specify minimum coverage per layer and mapping to CI gates.

- Baseline (2025-11-10) `mix test --cover`: 80.78% overall after LiveView smoke tests + context fixtures — still below ≥85% guardrail (CR-04). Continue expanding LiveView flows and context/unit suites until coverage gate passes locally and in CI.

## 2. Fixtures & Factories
Document ExMachina usage, data-case helpers, and LazyHTML selectors for LiveView tests.

## 3. Critical Journeys
Outline smoke flows for `/`, `/devices`, `/bulk/<ref>` including auth guards, events, and stream assertions. Tests now cover:
- Unauthorized visitors redirected to `/users/log-in` for `/`, `/devices`, `/bulk/<ref>`.
- `/devices` lists/searches devices, opens modal, enqueues bulk runs, and listens for PubSub updates.
- `/bulk/<ref>` receives progress + summary events.

## 4. Tooling Matrix
| Command | Purpose | When to Run | Evidence |
|---------|---------|-------------|----------|
| `mix test` | Full suite | Local + CI | TP-## |
| `mix test --cover` | Coverage gate | CI | TP-## |
| ... | ... | ... | ... |

## 5. Flake & Regression Handling
Policy for reruns, tagging (`@tag :focus`), and reporting in CODE_REVIEW.

## Verification & Evidence Links
Attach last CI run URLs, coverage reports, and recorded walkthroughs proving critical journeys.
