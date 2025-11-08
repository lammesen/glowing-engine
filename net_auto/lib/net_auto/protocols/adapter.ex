defmodule NetAuto.Protocols.Adapter do
  @moduledoc """
  Behaviour for automation protocol adapters (SSH, Telnet, etc.).

  Implementations run commands against devices and stream output chunks via the
  supplied callback.
  """

  alias NetAuto.Inventory.Device

  @callback run(Device.t(), String.t(), map(), (binary() -> any())) ::
              {:ok, integer(), non_neg_integer()} | {:error, term()}
end
