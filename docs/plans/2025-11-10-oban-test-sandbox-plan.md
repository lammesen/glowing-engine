# Oban Sandbox & Test Stability Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ensure `mix test --cover` can run reliably by stopping Oban peer processes from fighting the SQL sandbox (ownership errors) in the test environment.

**Architecture:** Disable Oban peers/cron queues in `:test`, run Oban in inline or sandbox-friendly mode, and guard any PromEx instrumentation that queries Oban so tests do not spawn background DB usage outside the ExUnit sandbox. Verify by running the full coverage suite.

**Tech Stack:** Elixir 1.19.2, Oban 2.20.1, Ecto SQL sandbox, PromEx.

---

### Task 1: Disable Oban Peers in Test

**Files:**
- `net_auto/config/test.exs`
- `net_auto/config/runtime.exs` (if needed)

**Steps:**
1. Add config in `test.exs`:
```elixir
config :net_auto, Oban,
  testing: :inline,
  queues: false,
  plugins: false
```
(or equivalent). Ensure Oban application uses this config (check supervision tree in `NetAuto.Application`).
2. Confirm that PromEx/Telemetry referencing Oban handle `false` queues gracefully (no peer started).

### Task 2: Guard PromEx Oban Plugin During Tests

**Files:**
- `net_auto/lib/net_auto/prom_ex/observability_plugin.ex`

**Steps:**
1. Ensure Oban plugin only registers when `Application.get_env(:net_auto, Oban)` supports it (e.g., skip plugin when `queues: false`).
2. Add conditional or runtime guard to avoid DB polling when Oban disabled.

### Task 3: Adjust Test Helpers for Oban

**Files:**
- `net_auto/test/support/data_case.ex` (if needed)

**Steps:**
1. After starting sandbox owner, ensure Oban is put into `testing: :inline` mode via `Oban.Testing` helper or resetting config per test.
2. Provide helper `use Oban.Testing` as needed for suites that assert on jobs.

### Task 4: Verification

1. Run `mix test --cover` – expect PASS without ownership errors; capture new coverage percentage.
2. Run `mix precommit` – confirm it now fails only at Dialyzer/Sobelow steps (existing known issues).

### Task 5: Documentation & Commit

1. Update CODE_REVIEW findings referencing CR-04 (note sandbox fix) and DX_GUIDE instructions for running tests without Oban peers.
2. Commit with message `test: stabilize oban sandbox in tests` referencing CR-04.

---

## Execution Handoff
Plan saved to `docs/plans/2025-11-10-oban-test-sandbox-plan.md`. Execution options:
1. Subagent-Driven (this session) – recommended.
2. Parallel executing-plans session.
