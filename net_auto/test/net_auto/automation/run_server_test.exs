defmodule NetAuto.Automation.RunServerTest do
  use NetAuto.DataCase, async: false

  import Mox

  alias NetAuto.Automation
  alias NetAuto.Automation.{QuotaServer, RunServer}
  alias NetAuto.AutomationFixtures
  alias NetAuto.InventoryFixtures

  setup_all do
    case Registry.start_link(keys: :unique, name: NetAuto.Automation.Registry) do
      {:ok, pid} ->
        on_exit(fn -> Process.exit(pid, :normal) end)
        :ok

      {:error, {:already_started, _pid}} ->
        :ok
    end

    :ok
  end

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    quota_name =
      Module.concat(__MODULE__, "Quota#{System.unique_integer([:positive])}")

    start_supervised!(
      {QuotaServer, name: quota_name, global_limit: 5, site_limits: %{}, default_site_limit: 5}
    )

    %{quota_server: quota_name}
  end

  test "completes successful run and persists chunks", %{quota_server: quota} do
    device = InventoryFixtures.device_fixture(%{site: "chi1"})
    run = AutomationFixtures.run_fixture(%{device: device, status: :pending})
    command = run.command
    {:ok, reservation} = QuotaServer.check_out(quota, "chi1", %{run_id: run.id})

    expect(NetAuto.ProtocolsAdapterMock, :run, fn ^device, ^command, _opts, chunk_cb ->
      chunk_cb.("first\n")
      chunk_cb.("second\n")
      {:ok, 0, 12}
    end)

    {:ok, pid} =
      start_supervised(
        {RunServer,
         run: run,
         device: device,
         adapter: NetAuto.ProtocolsAdapterMock,
         command: command,
         site: "chi1",
         reservation: reservation,
         quota_server: quota}
      )

    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

    updated = Automation.get_run!(run.id)

    assert updated.status == :ok
    assert updated.exit_code == 0
    assert updated.bytes == byte_size("first\nsecond\n")
    assert updated.finished_at

    chunks = Automation.list_run_chunks(run.id)
    assert Enum.map(chunks, & &1.data) == ["first\n", "second\n"]

    state = QuotaServer.debug_state(quota)
    assert state.global.active == 0
    assert get_in(state.sites, ["chi1", :active]) == 0
  end

  test "emits telemetry events on start and stop", %{quota_server: quota} do
    handler = attach_run_telemetry()
    device = InventoryFixtures.device_fixture(%{site: "chi1"})
    run = AutomationFixtures.run_fixture(%{device: device, status: :pending})
    command = run.command
    {:ok, reservation} = QuotaServer.check_out(quota, "chi1", %{run_id: run.id})

    test_pid = self()

    expect(NetAuto.ProtocolsAdapterMock, :run, fn ^device, ^command, _opts, chunk_cb ->
      send(test_pid, :adapter_started)
      chunk_cb.("ok\n")
      Process.sleep(10)
      {:ok, 0, 3}
    end)

    {:ok, pid} =
      start_supervised(
        {RunServer,
         run: run,
         device: device,
         adapter: NetAuto.ProtocolsAdapterMock,
         command: command,
         site: "chi1",
         reservation: reservation,
         quota_server: quota}
      )

    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

    {measurements, metadata} = wait_for_event([:net_auto, :run, :start])
    assert measurements[:system_time]
    assert metadata.run_id == run.id
    assert metadata.device_id == device.id

    {chunk_meas, chunk_meta} = wait_for_event([:net_auto, :run, :chunk])
    assert chunk_meas.bytes == 3
    assert chunk_meta.seq == 0
    assert chunk_meta.run_id == run.id

    {stop_meas, stop_meta} = wait_for_event([:net_auto, :run, :stop])
    assert stop_meas.bytes == 3
    assert stop_meta.status == :ok

    detach_run_telemetry(handler)
  end

  test "adapter error marks run as error", %{quota_server: quota} do
    device = InventoryFixtures.device_fixture(%{site: "chi1"})
    run = AutomationFixtures.run_fixture(%{device: device, status: :pending})
    command = run.command
    {:ok, reservation} = QuotaServer.check_out(quota, "chi1", %{run_id: run.id})

    expect(NetAuto.ProtocolsAdapterMock, :run, fn ^device, ^command, _opts, _chunk_cb ->
      {:error, :timeout}
    end)

    {:ok, pid} =
      start_supervised(
        {RunServer,
         run: run,
         device: device,
         adapter: NetAuto.ProtocolsAdapterMock,
         command: command,
         site: "chi1",
         reservation: reservation,
         quota_server: quota}
      )

    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

    updated = Automation.get_run!(run.id)
    assert updated.status == :error
    assert updated.error_reason =~ "timeout"

    state = QuotaServer.debug_state(quota)
    assert state.global.active == 0
  end

  test "cancellation marks run as error and releases quota", %{quota_server: quota} do
    device = InventoryFixtures.device_fixture(%{site: "chi1"})
    run = AutomationFixtures.run_fixture(%{device: device, status: :pending})
    command = run.command
    {:ok, reservation} = QuotaServer.check_out(quota, "chi1", %{run_id: run.id})

    test_pid = self()

    expect(NetAuto.ProtocolsAdapterMock, :run, fn ^device, ^command, _opts, _chunk_cb ->
      send(test_pid, :adapter_started)
      Process.sleep(:infinity)
    end)

    {:ok, pid} =
      start_supervised(
        {RunServer,
         run: run,
         device: device,
         adapter: NetAuto.ProtocolsAdapterMock,
         command: command,
         site: "chi1",
         reservation: reservation,
         quota_server: quota}
      )

    assert_receive :adapter_started
    assert :ok == RunServer.cancel(run.id)
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

    updated = Automation.get_run!(run.id)
    assert updated.status == :error
    assert updated.error_reason == "canceled"

    state = QuotaServer.debug_state(quota)
    assert state.global.active == 0
  end

  defp attach_run_telemetry do
    handler_id = {:run_server_test, System.unique_integer([:positive])}
    test_pid = self()

    :telemetry.attach_many(
      handler_id,
      [[:net_auto, :run, :start], [:net_auto, :run, :chunk], [:net_auto, :run, :stop]],
      fn event, measurements, metadata, _ ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    handler_id
  end

  defp detach_run_telemetry(handler_id) do
    :telemetry.detach(handler_id)
  end

  defp wait_for_event(event, timeout \\ 200) do
    receive do
      {:telemetry_event, ^event, measurements, metadata} ->
        {measurements, metadata}

      {:telemetry_event, _other, _measurements, _metadata} ->
        wait_for_event(event, timeout)

      _other ->
        wait_for_event(event, timeout)
    after
      timeout -> flunk("expected telemetry event #{inspect(event)}")
    end
  end
end
