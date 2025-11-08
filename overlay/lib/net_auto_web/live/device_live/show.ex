defmodule NetAutoWeb.DeviceLive.Show do
  use NetAutoWeb, :live_view
  alias NetAuto.{Inventory, Network}
  alias Phoenix.PubSub

  def mount(%{"id" => id}, _session, socket) do
    device = Inventory.get_device!(id)
    {:ok, socket
      |> assign(:device, device)
      |> assign(:command, "")
      |> assign(:run, nil)
      |> stream(:output, [])
    }
  end

  def handle_event("change_cmd", %{"command" => cmd}, socket) do
    {:noreply, assign(socket, :command, cmd)}
  end

  def handle_event("run", _params, %{assigns: %{device: d, command: cmd, current_user: u}} = socket) do
    {:ok, run} = Network.execute_command(d.id, cmd, %{requested_by: u.id})
    topic = "run:#{run.id}"
    if connected?(socket), do: PubSub.subscribe(NetAuto.PubSub, topic)
    {:noreply, socket |> assign(:run, run) |> stream(:output, [], reset: true)}
  end

  def handle_info({:chunk, _run_id, seq, chunk}, socket) do
    {:noreply, stream_insert(socket, :output, %{id: seq, line: chunk})}
  end

  def handle_info({:done, _run_id, code}, socket) do
    {:noreply, put_flash(socket, :info, "Finished with exit code #{code}")}
  end

  def handle_info({:error, _run_id, reason}, socket) do
    {:noreply, put_flash(socket, :error, "Run error: #{inspect(reason)}")}
  end
end
