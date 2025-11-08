defmodule NetAutoWeb.RunLiveTest do
  use NetAutoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias NetAuto.Automation
  alias NetAuto.AutomationFixtures
  alias NetAuto.InventoryFixtures

  setup [:register_and_log_in_user]

  test "redirects guests to login" do
    device = InventoryFixtures.device_fixture()

    assert {:error, {:redirect, %{to: redirect_path}}} =
             live(build_conn(), ~p"/devices/#{device.id}")

    assert redirect_path =~ "/users/log-in"
  end

  test "renders device info for authenticated users", %{conn: conn} do
    device = InventoryFixtures.device_fixture(%{hostname: "dc-edge-01"})
    _run = AutomationFixtures.run_fixture(%{device: device})

    {:ok, _view, html} = live(conn, ~p"/devices/#{device.id}")

    assert html =~ device.hostname
    assert html =~ "Run workspace"
  end

  test "filtering history narrows the list", %{conn: conn} do
    device = InventoryFixtures.device_fixture()
    AutomationFixtures.run_fixture(%{device: device, status: :ok, command: "show version", requested_by: "alice"})
    AutomationFixtures.run_fixture(%{device: device, status: :error, command: "show config", requested_by: "bob"})

    {:ok, view, _html} = live(conn, ~p"/devices/#{device.id}")

    view
    |> form("#history-filter-form", %{"statuses" => ["ok"], "requested_by" => "alice", "query" => "show"})
    |> render_submit()

    html = render(view)
    assert html =~ "show version"
    refute html =~ "show config"
  end

  test "selecting a run updates the detail panel", %{conn: conn} do
    device = InventoryFixtures.device_fixture()
    _first = AutomationFixtures.run_fixture(%{device: device, command: "show version"})
    second = AutomationFixtures.run_fixture(%{device: device, command: "show interface"})

    {:ok, view, _html} = live(conn, ~p"/devices/#{device.id}")

    view
    |> element("#run-entry-#{second.id} button")
    |> render_click()

    html = render(view)
    assert html =~ Integer.to_string(second.id)
    assert html =~ second.command
  end

  test "command form starts a run via NetAuto.Network", %{conn: conn, user: user} do
    device = InventoryFixtures.device_fixture()

    {:ok, view, _html} = live(conn, ~p"/devices/#{device.id}")

    view
    |> form("#run-command-form", %{"command" => "show version"})
    |> render_submit()

    run = Enum.find(Automation.list_runs(), &(&1.command == "show version"))
    assert run
    assert run.requested_by == user.email
  end

  test "chunk broadcasts append to live output", %{conn: conn} do
    device = InventoryFixtures.device_fixture()
    run = AutomationFixtures.run_fixture(%{device: device, command: "show version"})

    {:ok, view, _html} = live(conn, ~p"/devices/#{device.id}")

    send(view.pid, {:subscribe_run, run.id})
    render(view)
    Phoenix.PubSub.broadcast(NetAuto.PubSub, "run:#{run.id}", {:chunk, run.id, 42, "booting"})
    Process.sleep(10)

    assert render(view) =~ "booting"
  end

  test "tabs switch between live output and details", %{conn: conn} do
    device = InventoryFixtures.device_fixture()
    run = AutomationFixtures.run_fixture(%{device: device, command: "show version", status: :ok})

    {:ok, view, _html} = live(conn, ~p"/devices/#{device.id}")

    view
    |> element("button[phx-value-tab=\"details\"]")
    |> render_click()

    html = render(view)
    assert html =~ "Run status"
    assert html =~ Atom.to_string(run.status)
  end

  test "mount emits telemetry", %{conn: conn} do
    device = InventoryFixtures.device_fixture()
    handler = attach_telemetry([:net_auto, :liveview, :mount])
    on_exit(fn -> :telemetry.detach(handler) end)

    live(conn, ~p"/devices/#{device.id}")

    device_id = device.id
    assert_receive {
      :telemetry_event,
      [:net_auto, :liveview, :mount],
      %{duration_ms: _duration, count: 1},
      %{view: NetAutoWeb.RunLive, device_id: ^device_id}
    }
  end

  test "command submission emits telemetry", %{conn: conn} do
    device = InventoryFixtures.device_fixture()
    AutomationFixtures.run_fixture(%{device: device})
    handler = attach_telemetry([:net_auto, :liveview, :command_submitted])
    on_exit(fn -> :telemetry.detach(handler) end)

    {:ok, view, _html} = live(conn, ~p"/devices/#{device.id}")

    view
    |> form("#run-command-form", %{"command" => "show version"})
    |> render_submit()

    device_id = device.id
    assert_receive {
      :telemetry_event,
      [:net_auto, :liveview, :command_submitted],
      %{count: 1},
      %{command: "show version", device_id: ^device_id, requested_by: _}
    }
  end

  test "bulk_ref param renders context panel", %{conn: conn} do
    device = InventoryFixtures.device_fixture()
    {:ok, _view, html} = live(conn, ~p"/devices/#{device.id}?bulk_ref=bulk-demo")
    assert html =~ "Bulk job bulk-demo"
  end

  test "bulk progress updates are rendered for current device", %{conn: conn} do
    device = InventoryFixtures.device_fixture()
    {:ok, view, _html} = live(conn, ~p"/devices/#{device.id}?bulk_ref=bulk-demo")

    Phoenix.PubSub.broadcast(NetAuto.PubSub, "bulk:bulk-demo", {:bulk_progress, %{bulk_ref: "bulk-demo", device_id: device.id, status: :ok, run_id: 777, error: nil}})
    Phoenix.PubSub.broadcast(NetAuto.PubSub, "bulk:bulk-demo", {:bulk_summary, %{bulk_ref: "bulk-demo", ok: 1, error: 0}})

    html = render(view)
    assert html =~ "Bulk job bulk-demo"
    assert html =~ "Last status: OK run #777"
    assert html =~ "Summary: ok=1 error=0"
  end

  defp attach_telemetry(event) do
    handler_id = "run-live-telemetry-#{Enum.join(Enum.map(event, &to_string/1), "-")}-#{System.unique_integer()}"
    test_pid = self()

    :telemetry.attach(handler_id, event, fn ^event, measurements, metadata, _ ->
      send(test_pid, {:telemetry_event, event, measurements, metadata})
    end, nil)

    handler_id
  end
end
