# NetAuto Modernization Docs Index

This index explains the modernization deliverables, who owns them, the inputs they require, and how evidence flows between documents. Every artifact listed below starts with the shared **Status Snapshot** table and references centralized context/metrics documents under `docs/shared/`.

## Shared Templates
- **Status Snapshot Table**
  | Area | Baseline | Current Risk | Next Action |
  |------|----------|--------------|-------------|
- **Finding ID Namespaces**
  | Document | Prefix |
  |----------|--------|
  | CODE_REVIEW.md | `CR-##` |
  | REFACTOR_PLAN.md | `RP-##` |
  | ARCHITECTURE_DECISIONS.md | `ADR-##` |
  | TEST_PLAN.md | `TP-##` |
  | PERF_REPORT.md | `PRF-##` |
  | SECURITY_REPORT.md | `SEC-##` |
  | MIGRATIONS_GUIDE.md | `MIG-##` |
  | DX_GUIDE.md | `DX-##` |

## Artifact Overview
| Document | Purpose | Primary Owner | Key Inputs | Outputs / Consumers | Update Cadence |
|----------|---------|---------------|------------|---------------------|----------------|
| CODE_REVIEW.md | Inventory risks, gaps, and dependency graph | Architecture | Baseline inventory, `docs/shared/context-map.md` | REFACTOR_PLAN, ADRs, PR justifications | Each major refactor wave |
| REFACTOR_PLAN.md | Phase the modernization into reviewable PR waves | Architecture + PM | CODE_REVIEW findings | PR sequencing, risk mitigations | Update before each wave |
| ARCHITECTURE_DECISIONS.md | Record ADRs for auth, secrets, LiveView, jobs, telemetry, release packaging | Architecture | CODE_REVIEW + REFACTOR_PLAN | Test/Perf/Security docs, CI | When decisions change |
| TEST_PLAN.md | Define coverage strategy and acceptance tests | QA / Dev | CODE_REVIEW, app routes, fixtures | CI gating, PR requirements | Quarterly / major feature |
| PERF_REPORT.md | Track perf baselines and improvements | Performance Eng | Telemetry, PromEx dashboards | REFACTOR_PLAN, CHANGELOG | After perf work |
| SECURITY_REPORT.md | Surface security posture and Sobelow findings | Security | Sobelow, auth configs, secrets | CODE_REVIEW, DX_GUIDE, CHANGELOG | After security work |
| MIGRATIONS_GUIDE.md | Document DB/index changes with rollout/backout | DBAs | Ecto migrations, Oban jobs | Ops, release runbooks | Every migration set |
| DX_GUIDE.md | Developer experience workflows, scripts, env guidance | DX | Tooling configs, secrets policy | Onboarding docs, README | Update with DX changes |

## Evidence and Traceability
- `docs/shared/context-map.md`: single source for architecture/LiveView/adapter diagrams referenced by CODE_REVIEW, REFACTOR_PLAN, ADRs.
- `docs/shared/metrics.md`: canonical metrics tables (tests, perf, security) referenced by PERF_REPORT, SECURITY_REPORT, TEST_PLAN, CHANGELOG.
- CHANGELOG entries must cite at least one Finding ID plus evidence link (test results, telemetry screenshot, migration proof).

## Workflow Expectations
1. Update CODE_REVIEW first when new findings emerge.
2. Mirror those IDs in REFACTOR_PLAN phases and ADRs.
3. Ensure TEST/ PERF/ SECURITY/ MIGRATION/ DX docs cite the latest findings, adding verification artifacts.
4. Reflect merged work in CHANGELOG with Conventional Commit summaries and links back to the relevant documents.
