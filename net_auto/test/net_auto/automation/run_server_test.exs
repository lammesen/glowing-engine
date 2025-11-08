defmodule NetAuto.Automation.RunServerTest do
  use NetAuto.DataCase, async: false

  import Mox

  alias NetAuto.Automation
  alias NetAuto.Automation.{QuotaServer, RunServer}
  alias NetAuto.AutomationFixtures
  alias NetAuto.InventoryFixtures

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
end
