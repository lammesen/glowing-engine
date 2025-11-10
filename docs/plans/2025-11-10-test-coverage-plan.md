# Test Coverage & Data Isolation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminate seeded data leakage in tests, add LiveView integration coverage for `/`, `/devices`, `/bulk/<ref>`, and uplift overall coverage above the 90% gate.

**Architecture:** Pivot tests to factories/fixtures instead of global seeds, add LiveView tests using `Phoenix.LiveViewTest` + `LazyHTML`, and extend unit coverage on contexts. All changes stay within `net_auto/test` and support modules; no production features altered.

**Tech Stack:** Elixir 1.19.2, Phoenix LiveView 1.1.17, Ecto SQL sandbox, ExUnit, LazyHTML, ExMachina (if introduced).

---

### Task 1: Remove Seed Leakage & Provide Fixtures

**Files:**
- Modify: `net_auto/priv/repo/seeds.exs`, `net_auto/test/test_helper.exs`, `net_auto/test/support/*`, `net_auto/test/net_auto/inventory_test.exs`

**Step 1:** Stop running seeds in tests.
- In `mix.exs`, ensure `test` alias does not run `ecto.setup`; currently `test` alias already creates/migrates only (good). Confirm seeds file isn’t auto-run.
- Remove assumptions from tests that rely on seeded data.

**Step 2:** Introduce inventory fixture helper.
- Update `NetAuto.InventoryFixtures` (`test/support`) with functions `device_fixture/1`, `device_group_fixture/1`, etc., returning inserted structs using `NetAuto.Inventory.create_device/1`.
- Ensure fixtures accept attrs override.

**Step 3:** Update `NetAuto.InventoryTest` to use fixtures.
- Replace `assert [fetched] = Inventory.list_devices()` test with deterministic data (insert one device via fixture and assert equality).

**Step 4:** Add DB cleanup assertions.
- Confirm each test uses `DataCase` sandbox; no further code needed once fixtures handle data.

**Expected outcome:** `mix test --cover` no longer fails due to extra devices; coverage still <90 but deterministic.

### Task 2: LiveView Smoke Tests (/ , /devices, /bulk/<ref>)

**Files:**
- `net_auto/test/net_auto_web/live/device_live_test.exs`
- `net_auto/test/net_auto_web/live/bulk_live_test.exs`
- New file: `net_auto/test/net_auto_web/live/home_live_test.exs`

**Step 1:** Add helper to log in user + visit `/` (existing `ConnCase.register_and_log_in_user/1`).
- Write LiveView test verifying redirect from `/` to `/devices` (if that’s intended) or presence of flash. Use `live(conn, ~p"/devices")` etc.

**Step 2:** `/devices` coverage.
- Ensure test inserts device via fixture and asserts table renders device hostname.
- Include event coverage (e.g., search filter, stream updates) if feasible.

**Step 3:** `/bulk/<ref>` coverage.
- Insert run/bulk job fixture (maybe via context). Assert LiveView mounts, shows placeholder, handles undone states.

**Step 4:** Add tests for unauthorized access (redirect to login) using `build_conn()` without login, verifying 302 to `/users/log_in`.

**Expected outcome:** Increases LiveView coverage and ensures key routes guarded.

### Task 3: Context/Unit Coverage Boost

**Files:**
- `net_auto/test/net_auto/network_test.exs`
- `net_auto/test/net_auto/automation_test.exs` (if exists)
- `net_auto/test/net_auto/secrets_test.exs`

**Step 1:** Identify low coverage modules (from cover report) like `NetAuto.Network`, `NetAuto.Inventory`, `NetAuto.Protocols.SSHAdapter`.

**Step 2:** Add unit tests for `NetAuto.Network.normalize_attrs/1` edge cases (since Credo flagged deep nesting there).

**Step 3:** Add tests for `NetAuto.Automation.normalize_status/1` and `QuotaServer.decrement_owner/3` to cover cond branches.

**Step 4:** Extend `NetAuto.SecretsTest` to cover `String.to_atom` change once sanitized; for now, add test ensuring unknown filter keys raise helpful error.

**Expected outcome:** Coverage exceeds 90%. Track coverage number from `mix test --cover` and update `docs/shared/metrics.md`.

### Task 4: Documentation Updates

**Files:**
- `CODE_REVIEW.md`
- `TEST_PLAN.md`
- `docs/shared/metrics.md`
- `CHANGELOG.md`

**Step 1:** Update CR-04/CR-05 status once coverage passes and tests deterministic.

**Step 2:** In TEST_PLAN, document new fixtures + LiveView smoke flows.

**Step 3:** Update metrics table TM-01 with new coverage numbers.

**Step 4:** Add CHANGELOG entry describing coverage improvements + new tests.

### Task 5: Verification & Commit

**Step 1:** Run `mix test --cover` ensuring ≥90%. Capture percentage.

**Step 2:** Run `mix precommit` (still expected to fail at Credo/Dialyzer/Sobelow until addressed; ensure only coverage portion now green).

**Step 3:** Commit with message `test: stabilize fixtures and add liveview coverage` referencing CR-04/CR-05.

---

## Execution Handoff
Plan saved to `docs/plans/2025-11-10-test-coverage-plan.md`. Two execution approaches:
1. Subagent-Driven (current session) – recommended.
2. Parallel session – open new workspace with executing-plans.
