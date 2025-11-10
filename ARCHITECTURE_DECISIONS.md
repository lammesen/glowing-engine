# ARCHITECTURE_DECISIONS.md

## Status Snapshot
| Area | Baseline | Current Risk | Next Action |
|------|----------|--------------|-------------|
| ADR Coverage | Pending | Unknown | Capture decisions for auth, secrets, LiveView, jobs, telemetry, releases |

## Purpose & Scope
Provide canonical ADRs covering key modernization decisions. Each ADR links back to the relevant CODE_REVIEW findings (`CR-##`) and REFACTOR_PLAN phases (`RP-##`).

## Sources & Evidence
- CODE_REVIEW.md
- REFACTOR_PLAN.md
- `docs/shared/context-map.md`
- Implementation PRs and telemetry evidence

## ADR Index
| ID | Title | Status | Linked Findings |
|----|-------|--------|-----------------|
| ADR-01 | TBD | Proposed | CR-## |

## ADR Template
For each ADR, use the following structure:

### ADR-XX Title
- **Status:** Proposed / Accepted / Superseded
- **Context:** Describe the problem and constraints.
- **Decision:** The choice made, including alternatives rejected.
- **Consequences:** Positive, negative, and neutral outcomes.
- **Linked Findings & Phases:** Cite CR/RP IDs plus affected docs (TEST, PERF, SECURITY).
- **Verification:** Evidence proving the decision works (tests, telemetry, runbooks).

Expected ADRs: Auth & Session Hardening, Secrets Handling, LiveView State Strategy, Background Jobs & Oban, Telemetry & Observability, Deployment & Release Packaging.
