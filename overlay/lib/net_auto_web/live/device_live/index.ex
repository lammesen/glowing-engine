defmodule NetAutoWeb.DeviceLive.Index do
  use NetAutoWeb, :live_view
  alias NetAuto.Inventory

  def mount(_params, _session, socket) do
    {:ok, assign(socket, devices: Inventory.list_devices())}
  end
end
