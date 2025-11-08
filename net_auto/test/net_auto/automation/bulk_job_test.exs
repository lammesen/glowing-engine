defmodule NetAuto.Automation.BulkJobTest do
  use NetAuto.DataCase, async: false

  import Mox

  alias NetAuto.Automation.BulkJob
  alias NetAuto.Automation.Run
  alias NetAuto.InventoryFixtures
  alias Oban.Job

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    Application.put_env(:net_auto, :network_client, NetAuto.NetworkClientMock)

    on_exit(fn ->
      Application.put_env(:net_auto, :network_client, NetAuto.Network.LocalRunner)
    end)

    :ok
  end

  test "executes command for each device and broadcasts progress" do
    devices = Enum.map(1..2, fn _ -> InventoryFixtures.device_fixture() end)
    device_ids = Enum.map(devices, & &1.id)
    bulk_ref = "bulk-test"

    Phoenix.PubSub.subscribe(NetAuto.PubSub, "bulk:#{bulk_ref}")

    Enum.each(device_ids, fn id ->
      expect(NetAuto.NetworkClientMock, :execute_command, fn ^id,
                                                             "show version",
                                                             %{requested_by: "ops"} ->
        {:ok, %Run{id: System.unique_integer([:positive]), device_id: id}}
      end)
    end)

    job =
      %Job{
        args: %{
          "device_ids" => device_ids,
          "command" => "show version",
          "requested_by" => "ops",
          "bulk_ref" => bulk_ref
        }
      }

    assert :ok = BulkJob.perform(job)

    Enum.each(device_ids, fn id ->
      assert_receive {:bulk_progress, %{bulk_ref: ^bulk_ref, device_id: ^id, status: :ok}}
    end)

    assert_receive {:bulk_summary, %{bulk_ref: ^bulk_ref, ok: 2, error: 0}}
  end

  test "reports errors when execution fails" do
    device = InventoryFixtures.device_fixture()
    device_id = device.id
    bulk_ref = "bulk-error"

    Phoenix.PubSub.subscribe(NetAuto.PubSub, "bulk:#{bulk_ref}")

    expect(NetAuto.NetworkClientMock, :execute_command, fn ^device_id, "show", %{} ->
      {:error, :unreachable}
    end)

    job = %Job{args: %{"device_ids" => [device_id], "command" => "show", "bulk_ref" => bulk_ref}}

    assert :ok = BulkJob.perform(job)

    assert_receive {:bulk_progress,
                    %{
                      bulk_ref: ^bulk_ref,
                      device_id: ^device_id,
                      status: :error,
                      error: "unreachable"
                    }}

    assert_receive {:bulk_summary, %{bulk_ref: ^bulk_ref, ok: 0, error: 1}}
  end
end
