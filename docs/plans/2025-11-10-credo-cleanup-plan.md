# Credo Cleanup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Resolve current `mix credo --strict` failures (missing `@moduledoc`, alias ordering, nested `cond`s, repeated helper warnings) so the lint gate and `mix precommit` can pass.

**Architecture:** Add concise module docs to key modules, alphabetize alias blocks, and refactor flagged `cond`/function bodies to comply with Credo style guidance. Focus on targeted modules without altering behavior; rely on existing tests to confirm no regressions.

**Tech Stack:** Elixir 1.19.2, Credo 1.7.13, Phoenix LiveView 1.1.17.

---

### Task 1: Module Docs & Alias Ordering

**Files:**
- `net_auto/lib/net_auto_web/user_auth.ex`
- `net_auto/lib/net_auto/accounts/user_token.ex`
- `net_auto/lib/net_auto/accounts/user_notifier.ex`
- `net_auto/lib/net_auto/accounts/user.ex`
- `net_auto/lib/net_auto/inventory.ex`
- `net_auto/lib/net_auto/automation.ex`
- `net_auto/lib/net_auto/accounts.ex`
- `net_auto/lib/net_auto/accounts/user_notifier.ex`
- `net_auto/test/net_auto/network_test.exs`
- `net_auto/test/net_auto/automation_test.exs`

**Steps:**
1. Insert concise `@moduledoc` definitions (1–2 sentences) describing purpose; omit where Phoenix already injects docs unless Credo still warns.
2. Reorder aliases alphabetically within each block (e.g., `NetAuto.Inventory.Device` vs `Phoenix.PubSub`). Keep grouped alias blocks per standard.
3. Re-run `mix credo --strict` to confirm doc/alias warnings resolved before moving on.

### Task 2: Refactor Nested `cond` / Function Complexity

**Files:**
- `net_auto/lib/net_auto_web/live/device_live/index.ex`
- `net_auto/lib/net_auto/protocols/ssh_adapter.ex`
- `net_auto/lib/net_auto/web/live/run_live.ex`
- `net_auto/lib/net_auto/web/live/device_live/form_component.ex`
- `net_auto/lib/net_auto/automation/quota_server.ex`
- `net_auto/lib/net_auto/automation.ex` (normalize_status)
- `net_auto/lib/net_auto/network.ex`

**Steps:**
1. For each warning, convert simple `cond` with default `true` branch into `if`/`case` statements or guard clauses.
2. Extract helper functions where nesting >2 (e.g., `NetAuto.Network.normalize_attrs/1` reduce block) to simplify.
3. Maintain existing behavior; add inline comments only when logic non-obvious.
4. Re-run targeted tests (`mix test test/net_auto/..._test.exs`) if logic touched.

### Task 3: Clean Up Remaining Credo Findings

**Files:**
- `net_auto/test/support/data_case.ex`
- `net_auto/test/support/conn_case.ex`
- `net_auto/test/net_auto_web/live/run_live_test.exs`

**Steps:**
1. Add module-level aliases for nested modules (DataCase/ConnCase warnings) or disable warnings if code generated and acceptable.
2. Replace `Enum.map |> Enum.join` in `run_live_test` with `Enum.map_join`.
3. Re-run `mix credo --strict`; ensure zero failures.

### Task 4: Verification & Commit

1. `mix test --cover` (sanity) – expect coverage unchanged (~80.78%).
2. `mix credo --strict` – must PASS.
3. `mix precommit` – should now fail only on Dialyzer/Sobelow (document output).
4. Update CODE_REVIEW findings for CR-01 status.
5. Commit with message `style: satisfy credo requirements` referencing CR-01.

---

## Execution Handoff
Plan saved to `docs/plans/2025-11-10-credo-cleanup-plan.md`. Execution options:
1. Subagent-Driven (this session) – recommended for lint fixes.
2. Parallel executing-plans session.
