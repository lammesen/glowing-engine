defmodule NetAuto.Protocols.SSHAdapterTest do
  use ExUnit.Case, async: false

  import Mox

  alias NetAuto.Inventory.Device
  alias NetAuto.Protocols.SSHAdapter
  alias NetAuto.Secrets.Credential

  setup :verify_on_exit!

  defmodule SecretsStub do
    @behaviour NetAuto.Secrets
    alias NetAuto.Secrets.Credential

    @impl true
    def fetch(_ref, _opts),
      do: {:ok, %Credential{cred_ref: "LAB", username: "netops", password: "secret"}}
  end

  setup do
    original_secrets = Application.get_env(:net_auto, NetAuto.Secrets)
    original_adapter = Application.get_env(:net_auto, NetAuto.Protocols.SSHAdapter)

    Application.put_env(:net_auto, NetAuto.Secrets, adapter: SecretsStub)
    Application.put_env(:net_auto, NetAuto.Protocols.SSHAdapter, ssh: NetAuto.Protocols.SSHMock)

    on_exit(fn ->
      Application.put_env(:net_auto, NetAuto.Secrets, original_secrets)
      Application.put_env(:net_auto, NetAuto.Protocols.SSHAdapter, original_adapter)
    end)

    :ok
  end

  test "run streams chunks and returns exit code" do
    device = struct(Device, id: 1, hostname: "sw1", ip: "192.0.2.10", port: 22, cred_ref: "LAB")

    NetAuto.Protocols.SSHMock
    |> expect(:connect, fn ~c"192.0.2.10", 22, opts ->
      assert opts[:user] == ~c"netops"
      assert opts[:password] == ~c"secret"
      {:ok, :conn}
    end)
    |> expect(:session_channel_open, fn :conn, _ -> {:ok, :channel} end)
    |> expect(:exec, fn :conn, :channel, ~c"show version", _ ->
      send(self(), {:ssh_cm, :conn, {:data, :channel, 0, "chunk"}})
      send(self(), {:ssh_cm, :conn, {:exit_status, :channel, 0}})
      send(self(), {:ssh_cm, :conn, {:closed, :channel}})
      :ok
    end)
    |> expect(:close_channel, fn :conn, :channel -> :ok end)
    |> expect(:close, fn :conn -> :ok end)

    assert {:ok, 0, 5} =
             SSHAdapter.run(device, "show version", [], fn data ->
               send(self(), {:chunk, data})
             end)

    assert_receive {:chunk, "chunk"}
  end

  test "returns error when host missing" do
    device = struct(Device, cred_ref: "LAB")
    assert {:error, :missing_host} = SSHAdapter.run(device, "show clock", [])
  end

  test "propagates connect failures" do
    device = struct(Device, hostname: "sw1", cred_ref: "LAB")

    NetAuto.Protocols.SSHMock
    |> expect(:connect, fn _, _, _ -> {:error, :closed} end)

    assert {:error, :closed} = SSHAdapter.run(device, "show", [])
  end
end
