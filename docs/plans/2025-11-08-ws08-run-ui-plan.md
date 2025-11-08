# WS08 Run UI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the `/devices/:id` LiveView so operators can launch commands, watch streamed output, and explore historical runs with rich filters.

**Architecture:** Extend the Automation context with device-scoped, filterable run queries; add a configurable `NetAuto.Network` boundary; create a Phoenix LiveView that renders a split layout (history + tabbed run panel), calls the network boundary to start runs, and streams chunk/topic events via Phoenix Streams while persisting UI state.

**Tech Stack:** Elixir 1.17, Phoenix 1.8, LiveView 1.1, Ecto, Phoenix PubSub, Chelekom components (cards, tabs, tables), Tailwind/daisyUI.

---

### Task 1: Add Automation run history query helpers

**Files:**
- Modify: `net_auto/lib/net_auto/automation.ex`
- Modify: `net_auto/test/net_auto/automation_test.exs`

**Step 1: Write failing tests**
Add a new `describe "paginated_runs_for_device/2"` block that seeds a device with multiple runs and asserts:
```elixir
params = %{page: 1, per_page: 2, statuses: ["running", "ok"], requested_by: "alice", query: "show", from: ~U[2024-01-01 00:00:00Z], to: ~U[2024-12-31 23:59:59Z]}
result = Automation.paginated_runs_for_device(device.id, params)
assert [%{requested_by: "alice"} = first | _] = result.entries
assert result.total >= 2
assert result.page == 1
```
Add similar test for `Automation.latest_run_for_device/1` returning newest run id.

**Step 2: Run tests to verify failures**
Execute `mix test test/net_auto/automation_test.exs`. Expect undefined function failures.

**Step 3: Implement query helpers**
In `Automation`, add:
- `@history_default_limit 25`
- `def paginated_runs_for_device(device_id, params)` returning `%{entries: runs, page: page, per_page: per_page, total: total}`
- Use a private `run_history_query/2` that pipes `Run |> where(device_id: ^device_id)` through filter helpers for statuses (`where([r], r.status in ^statuses)`), requested_by, `requested_at >= from` / `<= to`, and ILIKE search across `command`, `site`, `hostname` (via join on `Device`).
- Apply `order_by(desc: r.inserted_at)` and `limit/offset` for pagination; compute `total` via `Repo.aggregate(query, :count)` before limit.
- Implement `latest_run_for_device(device_id)` returning the newest run or `nil`.

**Step 4: Re-run targeted tests**
`mix test test/net_auto/automation_test.exs` should pass.

**Step 5: Commit**
`git add net_auto/lib/net_auto/automation.ex net_auto/test/net_auto/automation_test.exs`
`git commit -m "feat(ws08): add automation run history helpers"`

---

### Task 2: Introduce NetAuto.Network boundary for run execution

**Files:**
- Create: `net_auto/lib/net_auto/network.ex`
- Create: `net_auto/test/net_auto/network_test.exs`
- Modify: `net_auto/config/config.exs` (set default module env)

**Step 1: Write failing tests**
Add `NetAuto.NetworkTest` verifying:
```elixir
defmodule DummyNetwork do
  @behaviour NetAuto.Network.Client
  def execute_command(device_id, cmd, attrs), do: {:ok, %{device_id: device_id, command: cmd, attrs: attrs}}
end

test "delegates to configured client" do
  Application.put_env(:net_auto, :network_client, DummyNetwork)
  assert {:ok, %{command: "show"}} = NetAuto.Network.execute_command(1, "show", %{requested_by: "alice"})
end
```
Also assert default client module implements `execute_command/3` by creating a `Run` row with `status: :pending`.

**Step 2: Run tests to see failures**
`mix test test/net_auto/network_test.exs`.

**Step 3: Implement boundary**
Create `NetAuto.Network` with:
- `@callback execute_command(integer(), String.t(), map()) :: {:ok, Run.t()} | {:error, term()}` defined in nested behaviour `NetAuto.Network.Client`.
- `def execute_command(device_id, command, attrs \\ %{})` fetching module via `Application.get_env(:net_auto, :network_client, NetAuto.Network.LocalRunner)` and delegating.
- `NetAuto.Network.LocalRunner` uses `NetAuto.Automation.create_run/1` (setting `requested_by`, `requested_at`, etc.) and returns result. Add TODO comment about integrating `RunServer.start_child/1` when WS05 lands.
Update `config/config.exs` to set `config :net_auto, :network_client, NetAuto.Network.LocalRunner`.

**Step 4: Re-run tests**
`mix test test/net_auto/network_test.exs` (ensure sandbox cleanup via `on_exit`).

**Step 5: Commit**
`git add net_auto/lib/net_auto/network.ex net_auto/test/net_auto/network_test.exs net_auto/config/config.exs`
`git commit -m "feat(ws08): add network execution boundary"`

---

### Task 3: Add RunLive route and baseline render

**Files:**
- Create: `net_auto/lib/net_auto_web/live/run_live.ex`
- Modify: `net_auto/lib/net_auto_web/router.ex`
- Create: `net_auto/test/net_auto_web/live/run_live_test.exs`

**Step 1: Write failing LiveView tests**
In `run_live_test.exs`, use `ConnCase` helpers:
```elixir
@live_path ~p"/devices/#{device.id}"

setup [:register_and_log_in_user]

test "redirects guests", %{conn: conn} do
  assert {:error, {:redirect, _}} = live(conn, @live_path)
end

test "loads device info", %{conn: conn} do
  device = InventoryFixtures.device_fixture()
  {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/devices/#{device.id}")
  assert has_element?(view, "h1", device.hostname)
end
```

**Step 2: Run tests and observe failures**
`mix test test/net_auto_web/live/run_live_test.exs`.

**Step 3: Implement route + LiveView skeleton**
- Update router: inside authenticated scope add `live "/devices/:device_id", RunLive`.
- Implement `NetAutoWeb.RunLive` with `use NetAutoWeb, :live_view`. In `mount`, load device via `Inventory.get_device!`, fetch newest run via `Automation.latest_run_for_device`, prefetch history via `Automation.paginated_runs_for_device`, and assign baseline state (`history`, `filters`, `selected_run_id`, `tab: :live_output`). Provide placeholder render showing device heading and TODO comments.

**Step 4: Re-run tests**
`mix test test/net_auto_web/live/run_live_test.exs`.

**Step 5: Commit**
`git add net_auto/lib/net_auto_web/router.ex net_auto/lib/net_auto_web/live/run_live.ex net_auto/test/net_auto_web/live/run_live_test.exs`
`git commit -m "feat(ws08): add run liveview skeleton"`

---

### Task 4: Implement run history panel with filters

**Files:**
- Modify: `net_auto/lib/net_auto_web/live/run_live.ex`
- Modify: `net_auto/test/net_auto_web/live/run_live_test.exs`
- (Optional) Add shared component under `net_auto/lib/net_auto_web/components/run_components.ex` if code grows

**Step 1: Write failing LiveView tests**
Add tests that:
1. Submit filter form updates query params and list: `view |> element("form[phx-submit=\"filter\"]") |> render_submit(%{"status" => ["ok"], "query" => "show"})` and assert `render(view)` contains only filtered commands.
2. Clicking history row using `phx-click="select_run"` updates detail header.

**Step 2: Run tests (expect failure)**
`mix test test/net_auto_web/live/run_live_test.exs`.

**Step 3: Implement filtering UI + events**
- In LiveView assigns, maintain `%{status: [], requested_by: nil, query: nil, from: nil, to: nil}`.
- Add `handle_event("filter", params, socket)` that normalizes params, calls `Automation.paginated_runs_for_device/2`, updates history, and uses `push_patch` to reflect filters in `live_patch` URL.
- Render left column `card` with filter inputs (Chelekom `select`, `input`, `date`). Under form, render history list using `for run <- @history.entries`. Each row is button with `phx-click="select_run"` value run.id.
- Keep `selected_run_id` unchanged unless user clicks row.

**Step 4: Re-run tests**
`mix test test/net_auto_web/live/run_live_test.exs`.

**Step 5: Commit**
`git add net_auto/lib/net_auto_web/live/run_live.ex net_auto/test/net_auto_web/live/run_live_test.exs`
`git commit -m "feat(ws08): add run history filters"`

---

### Task 5: Wire command form, tabs, and streaming

**Files:**
- Modify: `net_auto/lib/net_auto_web/live/run_live.ex`
- Modify: `net_auto/test/net_auto_web/live/run_live_test.exs`

**Step 1: Write failing tests**
Add tests covering:
1. **Command submission:** Stub network client via `Application.put_env(:net_auto, :network_client, TestNetwork)`; within test, `TestNetwork` records args (Agent). Submit form via `render_submit/2` and assert new run row appears and toast message shown.
2. **Tab persistence:** Simulate clicking tab button (phx-click `set_tab`) and ensure render shows `aria-selected`.
3. **Streaming events:** After mounting view with existing run, broadcast chunk event: `Phoenix.PubSub.broadcast(NetAuto.PubSub, "run:#{run.id}", {:chunk, run.id, 0, "boot"})` and assert `render(view)` now includes "boot". Similarly broadcast finish event and assert status badge updates.

**Step 2: Run tests to ensure failure**
`mix test test/net_auto_web/live/run_live_test.exs`.

**Step 3: Implement command form + events**
- Render Chelekom `form_wrapper` with textarea (command), select for templates (if available), and `button` that triggers `phx-submit="run"`.
- In `handle_event("run", %{"command" => cmd} = params, socket)`, call `NetAuto.Network.execute_command(device.id, String.trim(cmd), %{requested_by: socket.assigns.current_user.email})`. On `{:ok, run}`, refresh history, optionally reset filters, update `selected_run_id` if user currently following `follow_latest` toggle false (per requirement B, keep user selection unless they opt-in). Show success toast via `put_flash`.
- Keep boolean `follow_latest` default false; add button to opt in, toggling assign.

**Step 4: Implement tabs + streaming**
- Use `stream/4` to manage `:chunks`. On mount, load existing chunks and `stream(socket, :chunks, chunks)`. Render tabs via Chelekom `tabs`: `tab(:live_output)` and `tab(:run_details)`; hooking `handle_event("set_tab", %{"tab" => tab})`. Tab choice stored in assigns and in query params.
- In `handle_info({:chunk, run_id, seq, data}, socket)` when `run_id == socket.assigns.selected_run_id`, call `stream_insert(:chunks, %{id: seq, data: data})` and update byte count. Use JS hook to auto-scroll if `@auto_scroll` true.
- Handle completion event `{:run_finished, run}` to update `selected_run` fields and history list.
- Provide `handle_params` to react to `run_id`/`tab` query params for deep links.

**Step 5: Re-run tests**
`mix test test/net_auto_web/live/run_live_test.exs`. Fix any flake by using `superpowers:condition-based-waiting` if asynchronous updates race.

**Step 6: Commit**
`git add net_auto/lib/net_auto_web/live/run_live.ex net_auto/test/net_auto_web/live/run_live_test.exs`
`git commit -m "feat(ws08): complete run streaming UI"`

---

### Task 6: Documentation & polish

**Files:**
- Modify: `README.md` (Quick start > mention `/devices/:id` run UI)
- Modify: `project.md` (WS08 status/notes if needed)
- Modify: `docs/plans/2025-11-08-ws08-run-ui-design.md` (link to LiveView instructions if updates)

**Step 1: Update docs**
Document how to trigger a run locally (set env secret, visit `/devices/:id`, use run form). Mention filters and tabs, plus requirement to start runner service.

**Step 2: Run full test suite + format**
`mix format` then `mix test`. Ensure `mix phx.digest` unnecessary.

**Step 3: Commit**
`git add README.md project.md docs/plans/2025-11-08-ws08-run-ui-design.md`
`git commit -m "docs(ws08): document run ui usage"`

---

**Ready for implementation once plan is approved. Follow tasks sequentially with TDD, using `superpowers:executing-plans` during execution.**
