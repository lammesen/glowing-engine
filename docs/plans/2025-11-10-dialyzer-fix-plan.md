# Dialyzer Remediation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Resolve current `mix dialyzer` failures (CR-02) by fixing impossible pattern matches in `RetentionWorker`, ensuring struct types expose `@type t`, and silencing known-safe warnings via ignore file only when necessary.

**Architecture:** Add/maintain explicit typespecs on structs (`NetAuto.Automation.Run`, `NetAuto.Inventory.Device`, adapters), normalize pattern matches in Retention worker, and configure Dialyzer via `dialyzer_ignore.exs` for acceptable third-party noise. Verify by running Dialyzer and precommit.

**Tech Stack:** Elixir 1.19.2, Dialyxir 1.4, Oban 2.20.1, Ecto.

---

### Task 1: Capture Current Dialyzer Output

**Steps:**
1. `cd net_auto && mix dialyzer > tmp_dialyzer.log` – collect warnings.
2. Summarize key failure buckets (pattern matches, unknown types, missing specs) to drive fixes.

### Task 2: Fix RetentionWorker Pattern Matches

**Files:** `net_auto/lib/net_auto/automation/retention_worker.ex`

**Steps:**
1. Identify guards where `max_total_bytes` pattern matches `:infinity`/`nil`; rewrite matches to handle integers vs sentinel atoms without impossible clauses.
2. Add typespec for retention config struct so Dialyzer knows possible values.
3. Update tests (if any) or add new ones to cover boundary conditions.

### Task 3: Ensure Struct Typespecs

**Files:**
- `net_auto/lib/net_auto/automation/run.ex`
- `net_auto/lib/net_auto/inventory/device.ex`
- `net_auto/lib/net_auto/network.ex` (client behaviour references Run.t, Device.t)
- Any behaviour referencing missing types (e.g., `NetAuto.Protocols.Adapter`)

**Steps:**
1. Add `@type t :: %__MODULE__{}` definitions for Run, Device, etc., explicitly listing fields used by behaviours.
2. Update behaviours (`NetAuto.Network.Client`, `NetAuto.Protocols.Adapter`) to reference these types.

### Task 4: Dialyzer Ignore Config (if needed)

**Files:** `.dialyzer_ignore.exs`

**Steps:**
1. Create ignore file with minimal entries (only third-party warnings such as `xmerl`).
2. Reference file in `mix.exs` under `dialyzer: [ignore_warnings: "dialyzer_ignore.exs"]`.

### Task 5: Verification & Docs

1. `mix dialyzer` → should pass or only show ignored warnings.
2. `mix precommit` → still expected to fail at Sobelow (`mix sobelow`), but dialyzer step should now pass.
3. Update CODE_REVIEW (CR-02 status) and DX_GUIDE to note dialyzer gate state.
4. Commit with message `chore: satisfy dialyzer guardrail` referencing CR-02.

---

## Execution Handoff
Plan saved to `docs/plans/2025-11-10-dialyzer-fix-plan.md`. Execution options:
1. Subagent-Driven (this session) – recommended.
2. Parallel session using executing-plans.
