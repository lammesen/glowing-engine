defmodule NetAutoWeb.BulkLive.Show do
  @moduledoc """
  Live view for tracking bulk execution progress.
  """

  use NetAutoWeb, :live_view

  alias Phoenix.PubSub

  @impl true
  def mount(%{"bulk_ref" => bulk_ref}, _session, socket) do
    if connected?(socket), do: PubSub.subscribe(NetAuto.PubSub, topic(bulk_ref))

    socket =
      socket
      |> assign(:bulk_ref, bulk_ref)
      |> assign(:summary, %{ok: 0, error: 0})
      |> assign(:devices, %{})

    {:ok, socket}
  end

  @impl true
  def handle_info(
        {:bulk_progress, %{bulk_ref: bulk_ref} = payload},
        %{assigns: %{bulk_ref: bulk_ref}} = socket
      ) do
    devices = Map.put(socket.assigns.devices, payload.device_id, payload)
    {:noreply, assign(socket, :devices, devices)}
  end

  def handle_info(
        {:bulk_summary, %{bulk_ref: bulk_ref} = payload},
        %{assigns: %{bulk_ref: bulk_ref}} = socket
      ) do
    summary = %{ok: payload.ok, error: payload.error}
    {:noreply, assign(socket, :summary, summary)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />
    <section class="mx-auto flex max-w-5xl flex-col gap-6 px-6 py-10">
      <header>
        <p class="text-sm text-base-content/70">Bulk Job</p>
        <h1 class="text-3xl font-semibold text-base-content">Bulk reference {@bulk_ref}</h1>
      </header>

      <div class="grid gap-4 sm:grid-cols-2">
        <div class="rounded-xl border border-base-200 bg-base-100 p-4">
          <p class="text-sm text-base-content/70">Completed</p>
          <p class="text-3xl font-semibold text-base-content">{@summary.ok}</p>
        </div>
        <div class="rounded-xl border border-base-200 bg-base-100 p-4">
          <p class="text-sm text-base-content/70">Failed</p>
          <p class="text-3xl font-semibold text-error">{@summary.error}</p>
        </div>
      </div>

      <div class="rounded-xl border border-base-200 bg-base-100">
        <div class="overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>Device</th>
                <th>Status</th>
                <th>Run ID</th>
                <th>Error</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={{device_id, progress} <- Enum.sort_by(@devices, fn {id, _} -> id end)}
                id={"bulk-device-#{device_id}"}
              >
                <td class="font-mono text-sm">#{device_id}</td>
                <td>
                  <span class={[
                    "badge",
                    progress.status == :ok && "badge-success",
                    progress.status == :error && "badge-error"
                  ]}>
                    {status_label(progress.status)}
                  </span>
                </td>
                <td>
                  <.link :if={progress.run_id} navigate={~p"/devices/#{device_id}"} class="link">
                    #{progress.run_id}
                  </.link>
                  <span :if={!progress.run_id} class="text-base-content/50">pending</span>
                </td>
                <td class="text-sm text-error">{progress.error || "—"}</td>
              </tr>
              <tr :if={map_size(@devices) == 0}>
                <td colspan="4" class="py-4 text-center text-base-content/60">
                  Waiting for progress updates…
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>
    """
  end

  defp topic(ref), do: "bulk:#{ref}"

  defp status_label(:ok), do: "OK"
  defp status_label(:error), do: "ERROR"
  defp status_label(other), do: other |> to_string() |> String.upcase()
end
