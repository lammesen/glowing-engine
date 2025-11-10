# Documentation Topology & Deliverable Plan (2025-11-10)

## Context
- Mandate: produce nine modernization deliverables (CODE_REVIEW, REFACTOR_PLAN, ARCHITECTURE_DECISIONS, TEST_PLAN, PERF_REPORT, SECURITY_REPORT, MIGRATIONS_GUIDE, DX_GUIDE, per-feature PR/CHANGELOG guidance).
- Goals: shared structure, cross-document traceability (finding IDs, metrics tables), easy reviewer onboarding, future automation for metrics ingest.
- Constraints: zero behavior regressions, evidence-backed assertions, Conventional Commits, Phoenix LiveView modernization scope.

## Strategy Overview
1. Create `docs/README.md` summarizing every artifact (purpose, owner, inputs, outputs, cadence) and embedding a Status Snapshot table template reused across files.
2. Add `docs/shared/context-map.md` and `docs/shared/metrics.md` to centralize diagrams + baseline/perf/security tables. All other docs link here instead of copy/pasting.
3. Each deliverable adopts the following header order:
   - Status Snapshot (Area | Baseline | Risk | Next Action)
   - Purpose & Scope
   - Sources & Evidence
   - Body (doc-specific sections below)
   - Verification & Evidence Links (ties to CODE_REVIEW finding IDs `CR-xx` and PR numbers)
4. Introduce `Finding IDs` namespace per doc: `CR-##`, `RP-##`, `ADR-##`, `TP-##`, `PRF-##`, `SEC-##`, `MIG-##`, `DX-##`. CHANGELOG entries reference these IDs.

## Wave 1 Document Outlines
### CODE_REVIEW.md
1. Executive Summary (top 5 risks + severity)
2. Stack Gap Matrix (current vs target versions/configs)
3. Dependency Graph overview (links to `docs/shared/context-map.md`)
4. Detailed Findings Table (ID, Component, Issue, Evidence, Impact, Recommendation, Tests Needed)

### REFACTOR_PLAN.md
1. Goals & Guardrails
2. Effort vs Impact matrix covering the nine PR waves
3. Phase breakdown (scope, dependencies, owner, exit criteria, telemetry/test evidence)
4. Risk Register + Mitigations
5. Communication Cadence

### ARCHITECTURE_DECISIONS.md
- ADR index plus entries for Auth & Session Hardening, Secrets Handling, LiveView State Strategy, Background Jobs/Oban, Telemetry/Observability, Deployment/Release Packaging.
- Standard ADR template: Context, Decision, Consequences, Status, Linked Findings/Phases.

## Wave 2 Document Outlines
### TEST_PLAN.md
1. Coverage targets per layer (unit, LiveView, integration, property)
2. Fixture/Factory strategy (ExMachina, data-case helpers, LazyHTML helpers)
3. Critical user journeys (`/`, `/devices`, `/bulk/<ref>`)
4. Tooling matrix (local vs CI commands, coverage gating)

### PERF_REPORT.md
1. Baseline metrics (TTFP, mount/render timing, DB p95/99, memory/connection)
2. Instrumentation sources (Telemetry events, PromEx dashboards)
3. Bottleneck catalog (N+1, missing indexes, render hotspots)
4. Improvement tracking (Before/After/Delta/Evidence table)

### SECURITY_REPORT.md
1. Threat model summary
2. Sobelow findings + waivers
3. AuthZ/AuthN posture (phx.gen.auth, session TTL, remember-me, cookie flags)
4. CSRF/CSP review, secrets handling audit

### MIGRATIONS_GUIDE.md
1. Change log for DB/index updates with rollout/backout steps
2. Online migration playbooks (add/backfill/swap/drop pattern)
3. Data migration + Oban job backfill guidance

### DX_GUIDE.md
1. Dev setup scripts (`mix setup`, `bin/dev`, Makefile targets)
2. Tooling (asdf, direnv, devcontainer/Nix) + secrets hygiene (`NET_AUTO_*`)
3. Sample `.envrc`, Cisco simulator workflow reminders

## CHANGELOG / PR Guidance
- Document Conventional Commit prefixes for each PR wave.
- Require each PR description to cite relevant Finding IDs + evidence sections.
- Central CHANGELOG references before/after metrics stored in shared tables.

## Next Steps
1. Scaffold folder/files: `docs/README.md`, `docs/shared/context-map.md`, `docs/shared/metrics.md`, plus all nine deliverable markdown files with header templates.
2. Collect baseline inventory (versions, deps, tests, perf, security) to populate shared tables and CODE_REVIEW findings.
3. Draft Wave 1 docs first, then iterate across Wave 2 once baseline data lands.
