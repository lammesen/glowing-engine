defmodule NetAuto.Protocols.Adapter do
  @moduledoc """
  Behaviour + convenience entry point for protocol adapters.
  """

  alias NetAuto.Inventory.Device

  @callback run(Device.t(), String.t(), keyword() | map(), (binary() -> any())) ::
              {:ok, integer(), non_neg_integer()} | {:error, term()}

  @doc """
  Invokes the configured protocol adapter (defaults to `SSHAdapter`).
  """
  @spec run(Device.t(), String.t(), keyword() | map(), (binary() -> any())) ::
          {:ok, integer(), non_neg_integer()} | {:error, term()}
  def run(device, command, opts \\ [], on_chunk \\ &__MODULE__.default_chunk_handler/1) do
    adapter().run(device, command, opts, on_chunk)
  end

  def default_chunk_handler(chunk), do: chunk

  defp adapter do
    Application.get_env(:net_auto, NetAuto.Protocols, adapter: NetAuto.Protocols.SSHAdapter)
    |> Keyword.fetch!(:adapter)
  end
end
