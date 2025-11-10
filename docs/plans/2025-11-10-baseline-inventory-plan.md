# Baseline Inventory & Evidence Capture Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Capture current NetAuto stack, test, perf, and security baselines so CODE_REVIEW and companion docs can reference real evidence.

**Architecture:** Use existing Phoenix app (`net_auto/`) as-is, run required Mix tooling, and store outputs in shared docs (`docs/shared/metrics.md`, CODE_REVIEW.md, SECURITY_REPORT.md, PERF_REPORT.md). No code changes beyond documentation updates.

**Tech Stack:** Elixir (mix), Phoenix, Postgres (for tests), Sobelow, Credo, Dialyzer, PromEx telemetry exports, GitHub Actions parity scripts.

---

### Task 1: Workspace & Dependency Prep

**Files:**
- `docs/shared/metrics.md`
- `CODE_REVIEW.md`

**Step 1: Ensure deps and tools installed**
Run: `cd net_auto && mix deps.get`
Expected: Dependencies fetch successfully with no errors.

**Step 2: Compile with warnings as errors**
Run: `cd net_auto && mix compile --warnings-as-errors`
Expected: SUCCESS with no warnings; otherwise log CR-IDs.

**Step 3: Record any compile issues**
Update `CODE_REVIEW.md` Detailed Findings table with entries referencing CR-IDs if compile fails; otherwise note "Compilation clean" in Executive Summary draft.

### Task 2: Version Inventory

**Files:**
- `docs/shared/metrics.md`
- `CODE_REVIEW.md`

**Step 1: Capture Elixir & OTP**
Run: `elixir --version`
Expected: Output shows Elixir ~>1.17.x and Erlang/OTP version. Record exact strings.

**Step 2: Capture Phoenix & LiveView versions**
Run: `cd net_auto && mix deps | grep -E "phoenix|phoenix_live_view"`
Expected: Lines showing locked versions. Note mismatches vs targets (Phoenix 1.8.1, LV latest compatible).

**Step 3: Update docs**
Edit CODE_REVIEW Stack Gap Matrix with captured versions. In `docs/shared/metrics.md`, add narrative or footnote referencing version data; include baseline row (e.g., LiveView 1.1.0).

### Task 3: Linting & Static Analysis Baseline

**Files:**
- `CODE_REVIEW.md`
- `REFACTOR_PLAN.md`

**Step 1: Format check**
Run: `cd net_auto && mix format --check-formatted`
Expected: "Files formatted correctly"; otherwise add CR entry for formatting debt.

**Step 2: Credo strict**
Run: `cd net_auto && mix credo --strict`
Expected: PASS; capture warnings/errors and log CR-IDs with categories (readability, refactor, warnings).

**Step 3: Dialyzer**
Run: `cd net_auto && mix dialyzer`
Expected: PASS; record PLT build time & warnings. Update CODE_REVIEW and REFACTOR_PLAN (Phase risks) with any issues.

### Task 4: Test Coverage Baseline

**Files:**
- `docs/shared/metrics.md`
- `TEST_PLAN.md`
- `CODE_REVIEW.md`

**Step 1: Prepare DB**
Run: `cd net_auto && MIX_ENV=test mix ecto.reset`
Expected: DB reset cleanly.

**Step 2: Run coverage suite**
Run: `cd net_auto && mix test --cover`
Expected: PASS. Note overall coverage percentage and failing tests (if any) with CR-IDs.

**Step 3: Update docs**
Populate Table TM-01 in `docs/shared/metrics.md` with coverage numbers; add commentary in TEST_PLAN (Coverage Targets section) referencing TP-IDs; add findings to CODE_REVIEW if coverage below targets.

### Task 5: Security Baseline

**Files:**
- `SECURITY_REPORT.md`
- `docs/shared/metrics.md`

**Step 1: Run Sobelow**
Run: `cd net_auto && mix sobelow -i Config.HTTPS --exit`
Expected: PASS or explicit findings. Export report (`--format html --out sobelow-report.html`) if possible.

**Step 2: Document findings**
Add entries to SECURITY_REPORT (SEC-IDs) with category, severity, recommendation. Update Table SM-01 in `docs/shared/metrics.md` with counts.

**Step 3: Session/cookie inventory**
Inspect `net_auto/config/prod.exs` and `net_auto/lib/net_auto_web/endpoint.ex` for session options; note TTL/cookie flags in SECURITY_REPORT.

### Task 6: Performance & Telemetry Snapshot

**Files:**
- `PERF_REPORT.md`
- `docs/shared/metrics.md`

**Step 1: Enable instrumentation**
Review `net_auto/lib/net_auto/prom_ex/observability_plugin.ex` for enabled events; adjust if instrumentation disabled and note CR-IDs (no code changes yet, just confirm).

**Step 2: Capture baseline metrics**
Run dev server with telemetry logging: `cd net_auto && MIX_ENV=dev mix phx.server` while hitting `/`, `/devices`, `/bulk/test` (if data). Use `curl` or browser; capture console timings or PromEx output.

**Step 3: Update docs**
Fill rows in Table PM-01 with observed TTFP/mount/render metrics (even approximate). Add PRF-IDs for any bottlenecks discovered.

### Task 7: Migration & DX Notes

**Files:**
- `MIGRATIONS_GUIDE.md`
- `DX_GUIDE.md`

**Step 1: List migrations**
Run: `cd net_auto && ls priv/repo/migrations`
Expected: list of migration files. Summarize in MIGRATIONS_GUIDE Change Log.

**Step 2: Verify Oban migrations**
Check for Oban version requirements (`priv/repo/migrations/*oban*`). Note status + required rollout steps.

**Step 3: DX observations**
While executing prior tasks, record friction (time for mix setup, tool installs) and update DX_GUIDE sections (Setup & Toolchain, Commands & Scripts) with actual pain points.

### Task 8: Commit + CHANGELOG stub

**Files:**
- `CHANGELOG.md` (create if missing)
- All updated docs

**Step 1: Review changes**
Run: `git status`
Ensure only documentation updates.

**Step 2: Commit**
Run: `git commit -am "docs: add baseline inventory scaffolding"`
Expected: commit created with Conventional Commit prefix `docs:`. (Skip if additional files staged separately.)

**Step 3: Update CHANGELOG**
Add entry summarizing baseline capture referencing relevant Finding IDs. If CHANGELOG absent, create with section for Unreleased.

**Step 4: Share plan execution status**
Report progress back to team, referencing plan file and pending tasks.

---

## Notes
- If any command fails due to environment issues, capture output verbatim and add CR-IDs before retrying.
- Tie every metric/security/perf observation to shared tables to avoid drift.
- After tasks complete, run `superpowers:executing-plans` (and possibly `superpowers:subagent-driven-development`) for precise execution tracking.
