# WS07 Devices UI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Deliver the `/devices` LiveView with unified search, sortable columns, and modal create/edit forms powered by Chelekom components plus Inventory PubSub so the table stays in sync.

**Architecture:** Extend `NetAuto.Inventory` with a `search_devices/1` query helper and PubSub broadcasts (`"inventory:devices"`). Build a `NetAutoWeb.DeviceLive.Index` LiveView that streams results, reacts to PubSub, and drives modals that host a reusable `DeviceFormComponent`. Wire routes under the authenticated operator session and cover behaviour with LiveView/DataCase tests.

**Tech Stack:** Phoenix 1.8, LiveView 1.1, Ecto 3.13, Phoenix PubSub, Mishka Chelekom components, ExUnit.

---

### Task 1: Add searchable/broadcasting Inventory helpers

**Files**
- Modify: `net_auto/lib/net_auto/inventory.ex`
- Modify: `net_auto/test/net_auto/inventory_test.exs`

**Step 1: Write failing Inventory tests**

Append to `test/net_auto/inventory_test.exs`:

```elixir
describe "search_devices/1" do
  setup do
    d1 = InventoryFixtures.device_fixture(%{hostname: "core-sw1", ip: "192.0.2.10", site: "dc1", vendor: "acme"})
    d2 = InventoryFixtures.device_fixture(%{hostname: "edge-rtr1", ip: "10.10.1.2", site: "dc2", vendor: "globex"})
    %{d1: d1, d2: d2}
  end

  test "matches across hostname/ip/vendor/site", %{d1: d1} do
    result = Inventory.search_devices(%{query: "core", sort_by: :hostname, sort_dir: :asc})
    assert Enum.map(result, & &1.id) == [d1.id]
  end

  test "sorts descending by vendor", %{d1: d1, d2: d2} do
    result = Inventory.search_devices(%{query: "", sort_by: :vendor, sort_dir: :desc})
    assert Enum.map(result, & &1.vendor) == Enum.sort([d1.vendor, d2.vendor], :desc)
  end

  test "broadcasts device events" do
    Phoenix.PubSub.subscribe(NetAuto.PubSub, "inventory:devices")
    {:ok, device} = Inventory.create_device(%{hostname: "notify", ip: "198.51.100.1", protocol: :ssh, port: 22, username: "netops", cred_ref: "LAB"})
    assert_receive {:device, :created, ^device}

    {:ok, updated} = Inventory.update_device(device, %{site: "edge"})
    assert_receive {:device, :updated, ^updated}

    {:ok, _} = Inventory.delete_device(updated)
    assert_receive {:device, :deleted, ^updated}
  end
end
```

**Step 2: Run failing tests**

```bash
cd net_auto
mix test test/net_auto/inventory_test.exs
```
Expected: failures because `search_devices/1` and broadcasts don’t exist.

**Step 3: Implement search helpers and broadcasts**

- In `lib/net_auto/inventory.ex`, add module attributes:
  ```elixir
  @device_topic "inventory:devices"
  @sortable_fields ~w(hostname ip protocol site username vendor model inserted_at)a
  ```
- Implement `search_devices/1` calling a private `device_search_query/1` that:
  - Builds base query `from d in Device`
  - Applies `query_filter/2` with `fragment("?::text", d.tags)` to make tags searchable
  - Applies `order_by([{^sort_dir, field(d, ^sort_by)}])` only when `sort_by` is in `@sortable_fields`
- Add `broadcast_device({:ok, device}, action)` helper that calls `Phoenix.PubSub.broadcast(NetAuto.PubSub, @device_topic, {:device, action, device})`.
- Pipe `create_device/1`, `update_device/2`, and `delete_device/1` results through `broadcast_device(result, :created | :updated | :deleted)`.

**Step 4: Re-run tests**

```bash
mix test test/net_auto/inventory_test.exs
```
Expected: all Inventory tests pass.

**Step 5: Commit**

```bash
git add lib/net_auto/inventory.ex test/net_auto/inventory_test.exs
git commit -m "feat(inventory): add search helper and device broadcasts"
```

---

### Task 2: Write LiveView tests for devices UI

**Files**
- Create: `net_auto/test/net_auto_web/live/device_live_test.exs`

**Step 1: Write tests covering list/search/modals**

Create `test/net_auto_web/live/device_live_test.exs`:

```elixir
defmodule NetAutoWeb.DeviceLiveTest do
  use NetAutoWeb.ConnCase

  import Phoenix.LiveViewTest
  alias NetAuto.InventoryFixtures

  setup %{conn: conn} do
    %{conn: log_in_user(conn, NetAuto.AccountsFixtures.user_fixture())}
  end

  test "lists devices with default sort", %{conn: conn} do
    d1 = InventoryFixtures.device_fixture(%{hostname: "alpha", vendor: "acme"})
    d2 = InventoryFixtures.device_fixture(%{hostname: "bravo", vendor: "globex"})
    {:ok, view, _html} = live(conn, ~p"/devices")
    assert has_element?(view, "#device-row-#{d1.id}")
    assert render(view) =~ d1.hostname
    assert render(view) =~ d2.hostname
  end

  test "search filters rows", %{conn: conn} do
    InventoryFixtures.device_fixture(%{hostname: "edge-one", site: "lab"})
    InventoryFixtures.device_fixture(%{hostname: "core-two", site: "dc1"})
    {:ok, view, _} = live(conn, ~p"/devices")
    view |> element("form[phx-change=search] input[name=q]") |> render_change(%{"q" => "core"})
    refute has_element?(view, "tbody tr", text: "edge-one")
    assert has_element?(view, "tbody tr", text: "core-two")
  end

  test "create device modal saves record", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/devices")
    view |> element("button", "Add Device") |> render_click()
    form_params = %{hostname: "modal-sw", ip: "10.0.0.5", protocol: :ssh, port: 22, username: "ops", cred_ref: "LAB"}
    view |> form("#device-form", device: form_params) |> render_submit()
    assert has_element?(view, ".toast", "Device saved")
    assert has_element?(view, "tbody tr", text: "modal-sw")
  end

  test "edit modal updates record", %{conn: conn} do
    device = InventoryFixtures.device_fixture(%{hostname: "edit-me"})
    {:ok, view, _} = live(conn, ~p"/devices")
    view |> element("#device-row-#{device.id} button", "Edit") |> render_click()
    view |> form("#device-form", device: %{hostname: "edit-updated"}) |> render_submit()
    assert has_element?(view, "tbody tr", text: "edit-updated")
  end
end
```

Adjust helper names to match actual button labels/selectors in implementation.

**Step 2: Run tests (expect failure)**

```bash
mix test test/net_auto_web/live/device_live_test.exs
```
Expected: failures because routes and LiveViews don’t exist.

**Step 3: Commit tests**

```bash
git add test/net_auto_web/live/device_live_test.exs
git commit -m "test(devices): specify LiveView behaviour"
```

---

### Task 3: Implement Device form component

**Files**
- Create: `net_auto/lib/net_auto_web/live/device_live/form_component.ex`
- Modify: `net_auto/lib/net_auto_web.ex` (if component imports needed)

**Step 1: Implement component**

Create `lib/net_auto_web/live/device_live/form_component.ex`:

```elixir
defmodule NetAutoWeb.DeviceLive.FormComponent do
  use NetAutoWeb, :live_component

  alias NetAuto.Inventory

  def render(assigns) do
    ~H"""
    <.simple_form for={@form} id="device-form" phx-target={@myself} phx-change="validate" phx-submit="save">
      <.input field={@form[:hostname]} label="Hostname" />
      <.input field={@form[:ip]} label="IP Address" />
      <.input field={@form[:protocol]} type="select" label="Protocol" options={Ecto.Enum.values(NetAuto.Inventory.Device, :protocol)} />
      <.input field={@form[:port]} type="number" label="Port" />
      <.input field={@form[:username]} label="Username" />
      <.input field={@form[:cred_ref]} label="Credential Ref" />
      <.input field={@form[:vendor]} label="Vendor" />
      <.input field={@form[:model]} label="Model" />
      <.input field={@form[:site]} label="Site" />
      <.input field={@form[:tags]} type="textarea" label="Tags (JSON map)" />
      <:actions>
        <.button type="submit">Save Device</.button>
      </:actions>
    </.simple_form>
    """
  end

  def update(%{device: device} = assigns, socket) do
    changeset = Inventory.change_device(device)
    {:ok, socket |> assign(assigns) |> assign(:form, to_form(changeset))}
  end

  def handle_event("validate", %{"device" => params}, socket) do
    changeset = socket.assigns.device |> Inventory.change_device(params) |> Map.put(:action, :validate)
    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"device" => params}, socket) do
    save_device(socket, socket.assigns.action, params)
  end
```

Include `save_device/3` function calling `Inventory.create_device` or `Inventory.update_device` and returning `{:noreply, notify_parent({:saved, device})}`.

**Step 2: Ensure component module available**

If `NetAutoWeb` `:component` macro doesn’t already alias the LiveView directory, no change needed. Otherwise import path per project conventions.

**Step 3: (Optional) Commit component after tests pass later**

---

### Task 4: Build DeviceLive Index and router wiring

**Files**
- Create: `net_auto/lib/net_auto_web/live/device_live/index.ex`
- Modify: `net_auto/lib/net_auto_web/router.ex`

**Step 1: Implement LiveView**

Create Index module with:

```elixir
defmodule NetAutoWeb.DeviceLive.Index do
  use NetAutoWeb, :live_view

  alias NetAuto.Inventory
  @device_topic "inventory:devices"

  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(NetAuto.PubSub, @device_topic)

    {:ok,
     socket
     |> assign(:filters, %{query: "", sort_by: :hostname, sort_dir: :asc})
     |> assign(:modal, %{open?: false, device: nil, action: nil})
     |> stream(:devices, [])}
  end
```

- `handle_params/3` reads `"q"`, `"sort"`, `"dir"` from params, updates `:filters`, calls `load_devices(socket)` which uses `Inventory.search_devices` and `stream_reset/3`.
- `handle_event("search", %{"q" => query}, socket)` updates filters and issues `push_patch`.
- `handle_event("sort", %{"field" => field}, socket)` toggles direction.
- `handle_info({:device, action, device}, socket)` handles `:created`, `:updated`, `:deleted` via `stream_insert`/`stream_delete`.
- Template:
  - Wrap with `<Layouts.app flash={@flash} current_scope={@current_scope}>`
  - Header containing title, search form (`phx-change="search"`, `phx-debounce="300"`), and `<.button phx-click="new">Add Device</.button>`
  - Chelekom `table` (or existing `CoreComponents.table`) with sortable headers (`phx-click="sort"`). Each row `id={"device-row-#{device.id}"}`.
  - Modal rendered when `@modal.open?`, containing `<.live_component module={DeviceLive.FormComponent} id="device-form-component" device={@modal.device} action={@modal.action} ... />`

**Step 2: Router wiring**

In `router.ex`, under the authenticated scope (currently only PageController), add a `live_session :operators, on_mount: [...]` block if needed, e.g.:

```elixir
scope "/", NetAutoWeb do
  pipe_through [:browser, :require_authenticated_user]

  live_session :operators, on_mount: [{NetAutoWeb.UserAuth, :ensure_authenticated}] do
    live "/devices", DeviceLive.Index, :index
    live "/devices/new", DeviceLive.Index, :new
    live "/devices/:id/edit", DeviceLive.Index, :edit
  end

  get "/", PageController, :home
end
```

Ensure we explain in PR why this scope uses `:browser, :require_authenticated_user` per AGENTS.md.

**Step 3: Manual verification**

Run `mix phx.server`, log in, navigate to `/devices`, test search & modals.

**Step 4: Commit**

```bash
git add lib/net_auto_web/live/device_live/*.ex lib/net_auto_web/router.ex
git commit -m "feat(devices): add LiveView with search and modals"
```

---

### Task 5: Verify LiveView tests + formatting

**Files**
- (No new files; run tooling)

**Step 1: Run targeted tests**

```bash
mix test test/net_auto_web/live/device_live_test.exs
```

**Step 2: Run full suite + formatter**

```bash
mix test
mix format
```

**Step 3: Commit**

```bash
git add .
git commit -m "test(devices): cover live interactions"
```

---

Plan complete and saved to `docs/plans/2025-11-08-ws07-devices-ui-plan.md`.

Two execution options:

1. **Subagent-Driven (this session)** – I’ll dispatch a fresh subagent per task with reviews between tasks for fast iteration.
2. **Parallel Session** – Open a new session in this worktree, run `superpowers:executing-plans`, and implement the plan with checkpoints there.

Which approach would you like? 
