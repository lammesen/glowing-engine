defmodule NetAuto.NetworkTest do
  use NetAuto.DataCase, async: true

  alias NetAuto.Network
  alias NetAuto.InventoryFixtures

  defmodule FakeClient do
    @behaviour NetAuto.Network.Client

    def execute_command(device_id, command, attrs) do
      send(self(), {:fake_client_called, device_id, command, attrs})
      {:ok, %{device_id: device_id, command: command, attrs: attrs}}
    end
  end

  test "delegates to configured client module" do
    Application.put_env(:net_auto, :network_client, FakeClient)
    on_exit(fn -> Application.delete_env(:net_auto, :network_client) end)

    assert {:ok, %{device_id: 42, command: "show run", attrs: %{requested_by: "alice"}}} =
             Network.execute_command(42, "show run", %{requested_by: "alice"})

    assert_received {:fake_client_called, 42, "show run", %{requested_by: "alice"}}
  end

  test "local runner inserts pending run for device" do
    Application.delete_env(:net_auto, :network_client)

    device = InventoryFixtures.device_fixture()

    handler_ids =
      for event <- [[:net_auto, :runner, :start], [:net_auto, :runner, :stop]] do
        id = "runner-telemetry-#{inspect(event)}-#{System.unique_integer()}"
        :telemetry.attach(id, event, fn ^event, measurements, metadata, _ ->
          send(self(), {:telemetry_event, event, measurements, metadata})
        end, nil)

        id
      end

    on_exit(fn -> Enum.each(handler_ids, &:telemetry.detach/1) end)

    assert {:ok, run} =
             Network.execute_command(device.id, "show version", %{requested_by: "buildbot"})

    assert run.device_id == device.id
    assert run.command == "show version"
    assert run.status == :pending
    assert run.requested_by == "buildbot"
    assert %DateTime{} = run.requested_at
    device_id = device.id
    run_id = run.id
    assert_receive {:telemetry_event, [:net_auto, :runner, :start], %{count: 1}, %{device_id: ^device_id}}
    assert_receive {
      :telemetry_event,
      [:net_auto, :runner, :stop],
      %{duration_ms: _duration, bytes: 0, count: 1},
      %{device_id: ^device_id, run_id: ^run_id}
    }
  end
end
