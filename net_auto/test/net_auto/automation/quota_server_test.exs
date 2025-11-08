defmodule NetAuto.Automation.QuotaServerTest do
  use ExUnit.Case, async: false

  alias NetAuto.Automation.QuotaServer

  setup do
    server = Module.concat(__MODULE__, Instance)

    start_supervised!({
      QuotaServer,
      name: server,
      global_limit: 2,
      site_limits: %{"chi1" => 1},
      default_site_limit: 1
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
end
