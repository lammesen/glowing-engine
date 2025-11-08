defmodule NetAuto.Automation.QuotaServerTest do
  use ExUnit.Case, async: false

  alias NetAuto.Automation.QuotaServer

  setup do
    server = Module.concat(__MODULE__, Instance)

    start_supervised!({
      QuotaServer,
      name: server, global_limit: 2, site_limits: %{"chi1" => 1}, default_site_limit: 1
    })

    %{server: server}
  end

  describe "check_out/3" do
    test "grants reservation when under caps", %{server: server} do
      assert {:ok, ref} = QuotaServer.check_out(server, "chi1", %{run_id: 1})

      assert %{
               global: %{active: 1},
               sites: %{"chi1" => %{active: 1}}
             } = QuotaServer.debug_state(server)

      assert :ok = QuotaServer.check_in(server, ref)

      assert %{
               global: %{active: 0},
               sites: %{"chi1" => %{active: 0}}
             } = QuotaServer.debug_state(server)
    end

    test "returns error when global cap reached", %{server: server} do
      assert {:ok, _} = QuotaServer.check_out(server, "chi1", %{})
      assert {:ok, _} = QuotaServer.check_out(server, "sfo2", %{})

      assert {:error, {:quota_exceeded, :global}} =
               QuotaServer.check_out(server, "dfw1", %{})
    end

    test "returns error when site cap reached", %{server: server} do
      assert {:ok, _} = QuotaServer.check_out(server, "chi1", %{})

      assert {:error, {:quota_exceeded, {:site, "chi1"}}} =
               QuotaServer.check_out(server, "chi1", %{})
    end
  end

  describe "cleanup" do
    test "releases reservation when owner dies", %{server: server} do
      parent = self()

      pid =
        spawn(fn ->
          send(parent, QuotaServer.check_out(server, "chi1", %{}))
          Process.sleep(:infinity)
        end)

      msg =
        receive do
          received -> received
        end

      assert {:ok, _ref} = msg
      assert %{global: %{active: 1}} = QuotaServer.debug_state(server)

      Process.exit(pid, :kill)

      assert eventually(fn ->
               state = QuotaServer.debug_state(server)
               state.global.active == 0 and get_in(state, [:sites, "chi1", :active]) == 0
             end)
    end
  end

  describe "telemetry" do
    test "emits events on checkout and checkin", %{server: server} do
      handler = attach_telemetry()

      assert {:ok, ref} = QuotaServer.check_out(server, "chi1", %{run_id: 1})

      assert_receive {:telemetry_event, [:net_auto, :quota, :checked_out], meas, meta}
      assert meas.global_active == 1
      assert meas.site_active == 1
      assert meta.site == "chi1"
      assert meta.meta == %{run_id: 1}

      assert :ok = QuotaServer.check_in(server, ref)

      assert_receive {:telemetry_event, [:net_auto, :quota, :checked_in], meas2, meta2}
      assert meas2.global_active == 0
      assert meas2.site_active == 0
      assert meta2.reason == :normal

      detach_telemetry(handler)
    end
  end

  defp eventually(fun, attempts \\ 10)

  defp eventually(_fun, 0), do: flunk("condition not met")

  defp eventually(fun, attempts) do
    if fun.() do
      true
    else
      Process.sleep(10)
      eventually(fun, attempts - 1)
    end
  end

  defp attach_telemetry do
    handler_id = {:quota_test, System.unique_integer([:positive])}
    test_pid = self()

    :telemetry.attach_many(
      handler_id,
      [
        [:net_auto, :quota, :checked_out],
        [:net_auto, :quota, :checked_in]
      ],
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    handler_id
  end

  defp detach_telemetry(handler_id) do
    :telemetry.detach(handler_id)
  end
end
