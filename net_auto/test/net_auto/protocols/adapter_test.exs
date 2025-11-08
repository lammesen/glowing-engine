defmodule NetAuto.Protocols.AdapterTest do
  use ExUnit.Case, async: true

  alias NetAuto.Inventory.Device
  alias NetAuto.Protocols.Adapter

  defmodule StubAdapter do
    @behaviour NetAuto.Protocols.Adapter

    @impl true
    def run(device, command, opts, on_chunk) do
      send(opts[:caller], {:stub_called, device, command, opts})
      on_chunk.("chunk")
      {:ok, %{exit_code: 0, bytes: 5}}
    end
  end

  setup do
    original = Application.get_env(:net_auto, NetAuto.Protocols)
    Application.put_env(:net_auto, NetAuto.Protocols, adapter: StubAdapter)

    on_exit(fn -> Application.put_env(:net_auto, NetAuto.Protocols, original) end)
    :ok
  end

  test "run/4 delegates to configured adapter and forwards callback" do
    device =
      struct(Device,
        id: 1,
        hostname: "lab-sw1",
        ip: "192.0.2.10",
        protocol: :ssh,
        port: 22,
        username: "netops",
        cred_ref: "LAB_DEFAULT"
      )

    assert {:ok, %{exit_code: 0, bytes: 5}} =
             Adapter.run(device, "show version", [caller: self()], fn chunk ->
               send(self(), {:chunk, chunk})
             end)

    assert_receive {:stub_called, ^device, "show version", [caller: _caller]}
    assert_receive {:chunk, "chunk"}
  end

  test "run/2 uses default chunk handler" do
    device =
      struct(Device,
        hostname: "lab-sw2",
        ip: "192.0.2.20",
        protocol: :ssh,
        port: 22,
        cred_ref: "LAB_DEFAULT"
      )

    assert {:ok, %{exit_code: 0, bytes: 5}} = Adapter.run(device, "show clock", caller: self())
    assert_receive {:stub_called, ^device, "show clock", [caller: _caller]}
  end
end
