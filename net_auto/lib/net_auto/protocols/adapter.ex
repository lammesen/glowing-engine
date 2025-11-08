defmodule NetAuto.Protocols.Adapter do
  @moduledoc """
  Behaviour for protocol adapters (SSH, Telnet, etc.).

  Adapters are invoked by `NetAuto.Automation.RunServer` to execute commands
  against a device and stream output chunks via the supplied callback.
  """

  alias NetAuto.Inventory.Device

  @callback run(Device.t(), String.t(), map(), (binary() -> any())) ::
              {:ok, integer(), non_neg_integer()} | {:error, term()}
end
