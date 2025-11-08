# WS05 Runner + Quotas Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the automation runtime layer (RunSupervisor + RunServer) plus QuotaServer admission control that enforces global/per-site limits, streams chunks, and emits telemetry.

**Architecture:** DynamicSupervisor spawns one RunServer per run; RunServer coordinates the protocol adapter, Repo writes, and PubSub streaming. QuotaServer tracks active reservations and fast-fails when global or site caps are reached, cleaning up via monitors to avoid leaks.

**Tech Stack:** Elixir 1.17, Phoenix PubSub, Ecto, Telemetry, DynamicSupervisor/GenServer, Mox for adapter mocks.

---

### Task 1: QuotaServer TDD

**Files:**
- Create: `lib/net_auto/automation/quota_server.ex`
- Create: `test/net_auto/automation/quota_server_test.exs`
- Modify: `config/config.exs`, `config/test.exs`

**Step 1: Write the failing test**

Add `QuotaServerTest` that asserts `check_out/3` enforces limits and `check_in/1` releases counters.

```elixir
# test/net_auto/automation/quota_server_test.exs
describe "check_out/3" do
  test "grants reservation when under global and site caps" do
    assert {:ok, ref} = QuotaServer.check_out(:global, "chi1", %{run_id: 1})
    assert %{global: %{active: 1}, sites: %{"chi1" => %{active: 1}}} = QuotaServer.debug_state()
    assert :ok = QuotaServer.check_in(ref)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/net_auto/automation/quota_server_test.exs`  
Expected: FAIL with `undefined function QuotaServer.check_out/3`.

**Step 3: Write minimal implementation**

Create `QuotaServer` GenServer that reads limits from `Application.compile_env(:net_auto, NetAuto.Automation, ...)`, stores counts, and exposes `check_out/3`, `check_in/1`, `debug_state/0`.

```elixir
# lib/net_auto/automation/quota_server.ex
defmodule NetAuto.Automation.QuotaServer do
  use GenServer
  @name __MODULE__

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: @name)
  def check_out(scope, site, meta \\ %{}), do: GenServer.call(@name, {:check_out, scope, site, meta})
  def check_in(ref, reason \\ :normal), do: GenServer.call(@name, {:check_in, ref, reason})
  def debug_state, do: GenServer.call(@name, :debug_state)
  # ...
end
```

Include state struct `%{global: %{active: 0, limit: 50}, sites: %{}, reservations: %{}}` and logic described in the design.

**Step 4: Run test to verify it passes**

Run: `mix test test/net_auto/automation/quota_server_test.exs`  
Expected: PASS.

**Step 5: Commit**

```bash
git add lib/net_auto/automation/quota_server.ex test/net_auto/automation/quota_server_test.exs config
git commit -m "feat(automation): add QuotaServer with configurable limits"
```

---

### Task 2: Quota cleanup & telemetry

**Files:**
- Modify: `lib/net_auto/automation/quota_server.ex`
- Modify: `test/net_auto/automation/quota_server_test.exs`

**Step 1: Write failing telemetry + cleanup tests**

Add tests covering `{:DOWN, ...}` cleanup and telemetry emission.

```elixir
test "releases reservation if owner process dies" do
  parent = self()
  pid = spawn(fn ->
    send(parent, QuotaServer.check_out(:global, "chi1", %{owner: self()}))
    Process.sleep(:infinity)
  end)
  assert {:ok, ref} = receive do msg -> msg end
  Process.exit(pid, :kill)
  assert_receive {:quota_event, :checked_in}
  assert %{global: %{active: 0}} = QuotaServer.debug_state()
end
```

Attach a temporary telemetry handler in the test to collect events.

**Step 2: Run test; expect failure due to missing instrumentation/monitors**

`mix test test/net_auto/automation/quota_server_test.exs`

**Step 3: Implement monitors + telemetry**

- `handle_call({:check_out, ...})` should `Process.monitor(caller)` and store pid in reservation.
- Implement `handle_info({:DOWN, _, :process, pid, reason}, state)` that finds reservations and calls internal release.
- Emit `:telemetry.execute([:net_auto, :quota, :checked_out], %{global_active: ..., site_active: ...}, meta)` and similar for `:checked_in`.
- Allow tests to subscribe by `:telemetry.attach/4`.

**Step 4: Run tests to confirm pass**

`mix test test/net_auto/automation/quota_server_test.exs`

**Step 5: Commit**

```bash
git add lib/net_auto/automation/quota_server.ex test/net_auto/automation/quota_server_test.exs
git commit -m "feat(automation): add quota telemetry and crash cleanup"
```

---

### Task 3: RunSupervisor wiring

**Files:**
- Create: `lib/net_auto/automation/run_supervisor.ex`
- Modify: `lib/net_auto/application.ex`
- Modify: `mix.exs` (if new aliases/config helpers needed)

**Step 1: Write failing supervision test**

Add `test/net_auto/automation/run_supervisor_test.exs` asserting `DynamicSupervisor.start_child/2` boots a temporary GenServer.

```elixir
test "starts children" do
  {:ok, pid} = DynamicSupervisor.start_child(NetAuto.RunSupervisor, {Task, fn -> :ok end})
  assert Process.alive?(pid)
end
```

Ensure test starts the supervisor via `start_supervised!(NetAuto.RunSupervisor)`.

**Step 2: Run test (expect failure: supervisor undefined)**

`mix test test/net_auto/automation/run_supervisor_test.exs`

**Step 3: Implement RunSupervisor + application wiring**

- Add `NetAuto.Automation.RunSupervisor` module using `DynamicSupervisor`.
- Update `NetAuto.Application` children list to include `{NetAuto.Automation.QuotaServer, []}` and `{NetAuto.Automation.RunSupervisor, []}` **before** Endpoint.

**Step 4: Run focused test + regression suite**

`mix test test/net_auto/automation/run_supervisor_test.exs`

**Step 5: Commit**

```bash
git add lib/net_auto/automation/run_supervisor.ex lib/net_auto/application.ex test/net_auto/automation/run_supervisor_test.exs
git commit -m "feat(automation): add RunSupervisor and wire supervision tree"
```

---

### Task 4: RunServer skeleton with adapter callbacks

**Files:**
- Create: `lib/net_auto/automation/run_server.ex`
- Create: `test/support/mocks/protocols_adapter_mock.ex`
- Modify: `test/test_helper.exs`
- Modify: `mix.exs` (add `:mox` dependency if absent)

**Step 1: Write failing RunServer tests**

`test/net_auto/automation/run_server_test.exs` should start RunServer with mocked adapter returning success and assert run status transitions, chunk inserts, and quota release.

```elixir
setup :verify_on_exit!

test "completes successful run" do
  adapter = NetAuto.ProtocolsAdapterMock
  expect(adapter, :run, fn _device, "show", _opts, chunk_cb ->
    chunk_cb.("ok\n")
    {:ok, 0, 3}
  end)
  {:ok, run} = Automation.create_run(%{command: "show", device_id: device.id, status: :pending})
  {:ok, ref} = QuotaServer.check_out(:global, "chi1", %{run_id: run.id})
  {:ok, pid} = RunServer.start_link(%{run: run, reservation: ref, adapter: adapter})
  assert :ok = wait_until_finished(pid)
  assert %{status: :ok, bytes: 3} = Repo.get(Run, run.id)
end
```

**Step 2: Run test; expect compile errors for missing modules/mocks**

`mix test test/net_auto/automation/run_server_test.exs`

**Step 3: Implement RunServer + adapter behavior**

- Define `NetAuto.Automation.RunServer` as GenServer with `start_link/1`.
- Accept params `%{run: %Run{}, reservation: ref, device: %Device{}, adapter: module, command: binary, requested_by: binary}`.
- In `init/1`, update run to `:running`, start Task to call `adapter.run/4`, monitor it, and store seq counter/bytes.
- Implement `handle_info({:chunk, data}, state)` invoked by Task via `send`.
- On Task completion, finalize run status, emit telemetry, call `QuotaServer.check_in/2`, stop GenServer.
- Add `handle_call(:cancel, ...)` for cancellations.
- Provide helper to broadcast via `Phoenix.PubSub`.
- Introduce adapter behaviour `NetAuto.Protocols.Adapter` if not present.

**Step 4: Run tests**

`mix test test/net_auto/automation/run_server_test.exs`

**Step 5: Commit**

```bash
git add lib/net_auto/automation/run_server.ex test/net_auto/automation/run_server_test.exs test/support/mocks/protocols_adapter_mock.ex mix.exs mix.lock test/test_helper.exs
git commit -m "feat(automation): add RunServer with adapter streaming"
```

---

### Task 5: Telemetry, chunk streaming, and cancellation polish

**Files:**
- Modify: `lib/net_auto/automation/run_server.ex`
- Modify: `test/net_auto/automation/run_server_test.exs`

**Step 1: Add failing tests for telemetry + cancel path**

```elixir
test "emits telemetry events" do
  attach_events()
  # ... run server ...
  assert_receive {:telemetry_event, [:net_auto, :run, :start], _, %{run_id: ^run.id}}
end

test "cancellation sets error status" do
  {:ok, pid} = RunServer.start_link(...)
  assert :ok = RunServer.cancel(run.id)
  assert %{status: :error, error_reason: "canceled"} = Repo.get(Run, run.id)
end
```

**Step 2: Run tests (expect fail)**

`mix test test/net_auto/automation/run_server_test.exs`

**Step 3: Implement telemetry + cancel**

- Wrap telemetry emits using `:telemetry.execute`.
- Keep Registry of run pid by run_id (e.g., `Registry.NetAuto.RunServers`) or store in ETS; implement `RunServer.cancel/1` that looks up pid and sends `GenServer.cast(pid, :cancel)`.
- Ensure cancel path releases quota and updates DB.

**Step 4: Re-run tests**

`mix test test/net_auto/automation/run_server_test.exs`

**Step 5: Commit**

```bash
git add lib/net_auto/automation/run_server.ex test/net_auto/automation/run_server_test.exs
git commit -m "feat(automation): add run telemetry and cancellation support"
```

---

### Task 6: Automation.execute_run orchestration

**Files:**
- Modify: `lib/net_auto/automation.ex`
- Modify: `test/net_auto/automation_test.exs`
- Modify: `lib/net_auto/application.ex` (register registry if needed)

**Step 1: Write failing context tests**

Add tests that `execute_run/2` inserts run, handles quota exhaustion, and starts RunServer by checking Registry.

```elixir
test "returns quota error and marks run" do
  put_automation_config(global_limit: 0)
  assert {:error, :quota_exceeded} = Automation.execute_run(device, %{command: "show", requested_by: "ops"})
  assert %{status: :error, error_reason: "quota_exceeded:global"} = Repo.one(Run)
end
```

**Step 2: Run tests; expect fail (function missing)**

`mix test test/net_auto/automation_test.exs`

**Step 3: Implement execute_run + cancel_run**

- Load device + first group’s site via preloads.
- Create run (pending), resolve secrets, call `QuotaServer.check_out`.
- On success start child: `DynamicSupervisor.start_child(NetAuto.RunSupervisor, {RunServer, opts})`.
- Provide `cancel_run/1` that delegates to RunServer registry.

**Step 4: Run suite**

`mix test test/net_auto/automation_test.exs`

**Step 5: Commit**

```bash
git add lib/net_auto/automation.ex test/net_auto/automation_test.exs lib/net_auto/application.ex
git commit -m "feat(automation): add execute_run workflow with quotas"
```

---

### Task 7: Documentation + config defaults

**Files:**
- Modify: `README.md`
- Modify: `config/runtime.exs` (document env overrides)
- Modify: `.env.sample` (if exists; otherwise create)

**Step 1: Update docs/tests referencing quotas**

Add README section “Runner quotas” describing env vars: `NET_AUTO_AUTOMATION_GLOBAL_LIMIT`, `NET_AUTO_AUTOMATION_SITE_LIMITS` (JSON/CSV).

**Step 2: No dedicated tests required (docs), but run formatter**

`mix format`

**Step 3: Commit**

```bash
git add README.md config/runtime.exs .env.sample
git commit -m "docs(automation): document quota configuration"
```

---

Plan complete and saved to `docs/plans/2025-11-08-ws05-runner-quotas.md`. Two execution options:

1. Subagent-Driven (this session) — I dispatch fresh subagent per task with reviews between tasks for fast iteration.
2. Parallel Session — Open a new session focused solely on implementation using superpowers:executing-plans.

Which approach do you prefer?***
