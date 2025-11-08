# WS10 Bulk & Retention Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add retention controls (configurable purge of runs/chunks) and bulk fan-out execution with UI hooks, powered by Oban.

**Architecture:** Wire Oban as a first-class dependency (config + supervision). Implement `NetAuto.Automation.RetentionWorker` and `NetAuto.Automation.BulkJob` as Oban workers. Extend existing Devices/Run LiveViews with Chelekom components for multi-select + bulk progress UI. Add telemetry, tests, and docs.

**Tech Stack:** Elixir/Phoenix, Ecto, Oban 2.20, Phoenix LiveView, Mishka Chelekom components, ExUnit/Oban.Testing.

---

### Task 1: Oban configuration & supervision

**Files:**
- Modify: `net_auto/mix.exs` (ensure `:oban` started in extra applications if needed)
- Modify: `net_auto/config/config.exs`
- Modify: `net_auto/config/runtime.exs`
- Modify: `net_auto/lib/net_auto/application.ex`
- Modify: `net_auto/lib/net_auto_web/telemetry.ex`

**Step 1:** Update `config/config.exs` to add:
```elixir
config :net_auto, Oban,
  repo: NetAuto.Repo,
  queues: [default: 10, retention: 5, bulk: 5],
  plugins: [
    {Oban.Plugins.Cron, crontab: [{"@daily", NetAuto.Automation.RetentionWorker}]}
  ]
```

**Step 2:** In `config/runtime.exs`, fetch env overrides:
```elixir
retention_cron = System.get_env("NET_AUTO_RETENTION_CRON") || "@daily"
max_age = String.to_integer(System.get_env("NET_AUTO_RUN_MAX_DAYS") || "30")
max_bytes = System.get_env("NET_AUTO_RUN_MAX_BYTES")
config :net_auto, Oban, plugins: [{Oban.Plugins.Cron, crontab: [{retention_cron, NetAuto.Automation.RetentionWorker}]}]
config :net_auto, NetAuto.Automation.Retention,
  max_age_days: max_age,
  max_total_bytes: max_bytes && String.to_integer(max_bytes)
```
(keep defaults when env unset).

**Step 3:** Ensure Oban child starts in `NetAuto.Application`:
```elixir
oban_config = Application.fetch_env!(:net_auto, Oban)
children = [..., {Oban, oban_config}, ...]
```
Place before workers depending on DB.

**Step 4:** Attach telemetry in `NetAutoWeb.Telemetry.start_link/0`:
```elixir
:ok = Oban.Telemetry.attach_default_logger()
```
(or attach event handler).

**Step 5:** Run `mix deps.get && MIX_ENV=dev mix compile` to ensure config compiles.

**Expected Result:** Oban wired globally with configurable cron + retention settings.

---

### Task 2: Retention worker implementation & tests

**Files:**
- Create: `net_auto/lib/net_auto/automation/retention_worker.ex`
- Modify: `net_auto/lib/net_auto/automation.ex`
- Modify: `net_auto/test/net_auto/automation_test.exs`
- Add: `net_auto/test/support/oban_case.ex` if needed

**Step 1:** Add runtime accessor in `NetAuto.Automation`:
```elixir
def retention_config do
  defaults = %{max_age_days: 30, max_total_bytes: :infinity}
  configs = Application.get_env(:net_auto, NetAuto.Automation.Retention, %{})
  Map.merge(defaults, configs)
end
```

**Step 2:** Implement `NetAuto.Automation.RetentionWorker`:
```elixir
defmodule NetAuto.Automation.RetentionWorker do
  use Oban.Worker, queue: :retention
  import Ecto.Query
  alias NetAuto.{Repo, Automation.Run}

  @impl true
  def perform(_job) do
    config = NetAuto.Automation.retention_config()
    purge_by_age(config.max_age_days)
    purge_by_bytes(config.max_total_bytes)
    :ok
  end
```
Add helper functions to delete runs older than `max_age_days` (guard `:infinity`), and to enforce total bytes per device: e.g., query `from r in Run, group_by: r.device_id, select: {r.device_id, sum(r.bytes)}` and delete oldest runs until below limit (use recursive helper). Emit telemetry via `:telemetry.execute([:net_auto, :retention, :purge], %{runs_deleted: n}, %{type: :age})`.

**Step 3:** Tests using `Oban.Testing`:
- In `test/test_helper.exs`, `Oban.Testing.start_link(repo: NetAuto.Repo)` or configure sandbox.
- Add `NetAuto.DataCase` test `describe "RetentionWorker" do ...` seeding runs/chunks with various ages/bytes, run `RetentionWorker.perform(%Oban.Job{})`, assert counts drop and telemetry events (use `:telemetry.attach_many` or `capture_log`).

**Step 4:** Document new config in README (Task 5) after tests.

**Expected Result:** Worker purges old runs and enforces per-device byte limits with passing tests.

---

### Task 3: Bulk job API + backend tests

**Files:**
- Create: `net_auto/lib/net_auto/automation/bulk_job.ex`
- Modify: `net_auto/lib/net_auto/automation.ex`
- Modify: `net_auto/lib/net_auto/network.ex`
- Create: `net_auto/test/net_auto/automation/bulk_job_test.exs`

**Step 1:** Implement `NetAuto.Automation.Bulk.enqueue/3`:
```elixir
@spec enqueue(String.t(), [pos_integer()], keyword()) :: {:ok, [Oban.Job.t()]} | {:error, term()}
def enqueue(command, device_ids, opts \\ []) do
  chunks = Enum.chunk_every(Enum.uniq(device_ids), 50)
  Enum.map(chunks, fn ids ->
    Oban.new(queue: :bulk, worker: NetAuto.Automation.BulkJob, args: %{device_ids: ids, command: command, requested_by: opts[:requested_by]})
    |> Oban.insert()
  end)
end
```
Validate command/device list, return {:error, :invalid} otherwise.

**Step 2:** `BulkJob` `perform/1` loops device IDs, calling `NetAuto.Network.client().execute_command/3`. Use `Enum.each` with error handling; accumulate per-device status for logging/telemetry.

**Step 3:** Tests: use `Oban.Testing` and `Mox` to stub `NetAuto.Network.Client`. Assert enqueue splits as expected and `perform/1` calls `execute_command/3` for each device, handling failures gracefully.

**Expected Result:** Bulk job infrastructure ready with unit coverage.

---

### Task 4: Devices/Run LiveView bulk UI

**Files:**
- Modify: `net_auto/lib/net_auto_web/live/device_live/index.ex`
- Modify: `net_auto/lib/net_auto_web/live/device_live/index.html.heex` (if separate template)
- Modify: `net_auto/lib/net_auto_web/live/run_live/show.ex` (progress panel)
- Modify/Create tests: `net_auto/test/net_auto_web/live/device_live_test.exs`, `net_auto/test/net_auto_web/live/run_live_test.exs`

**Step 1:** Devices index: add multi-select (checkbox per row). Use Chelekom components (`checkbox_field`) and track selected IDs in socket assigns. Add “Run Bulk Command” button opening a modal (Chelekom `modal` + `form_wrapper`) with command textarea and `requested_by` defaulting to current user.

**Step 2:** On submit, call `NetAuto.Automation.Bulk.enqueue/3`, flash success w/ job IDs, and push event to Run LiveView via PubSub topic `"bulk:" <> job_id`.

**Step 3:** Add PubSub broadcasting inside `BulkJob` when each device run enqueues: `Phoenix.PubSub.broadcast(NetAuto.PubSub, "bulk:#{job_id}", {:bulk_progress, job_id, device_id, status})`.

**Step 4:** Run LiveView show: subscribe to `"bulk:" <> params[:job_id]` when query string has `?job=<id>`, render progress list (Chelekom `card` with list). Provide link from Devices bulk modal to run show with job param for monitoring.

**Step 5:** Update LiveView tests to cover selecting devices, submitting bulk form (use `NetAuto.Automation.Bulk` Mox), and verifying progress updates.

**Expected Result:** Users can select devices, submit a bulk command, and watch progress in Run UI.

---

### Task 5: Docs + verification

**Files:**
- Modify: `README.md` (document Oban + retention knobs + bulk usage)
- Modify: `project.md` checklist (tick retention + bulk items)
- Modify: `docs/plans/2025-11-08-ws10-bulk-retention-design.md` (link to implementation notes if needed)

**Steps:**
1. Update README “Configuration” with `NET_AUTO_RUN_MAX_DAYS`, `NET_AUTO_RUN_MAX_BYTES`, `NET_AUTO_RETENTION_CRON`, and instructions for bulk commands (UI + `NetAuto.Automation.Bulk.enqueue/3`).
2. In `project.md`, mark retention checkbox done, add note under WS10 that bulk UI is accessible from `/devices`.
3. Run `mix format`, `mix test`, `mix assets.build`.
4. Commit with `feat(retention): add purge worker` and `feat(bulk): add fan-out runner` (or similar), splitting commits per major feature.

**Expected Result:** Documentation updated, tests green, assets build clean.

---
