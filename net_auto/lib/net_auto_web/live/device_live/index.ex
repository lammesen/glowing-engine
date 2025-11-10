defmodule NetAutoWeb.DeviceLive.Index do
  @moduledoc """
  Devices inventory dashboard with unified search, modals, and bulk actions.
  """

  use NetAutoWeb, :live_view

  alias MapSet
  alias NetAuto.Accounts
  alias NetAuto.Automation
  alias NetAuto.Inventory
  alias NetAuto.Inventory.Device

  @default_filters %{query: "", sort_by: :hostname, sort_dir: :asc}

  @impl true
  def mount(params, session, socket) do
    filters = filters_from_params(params, @default_filters)
    current_user = fetch_current_user(session)
    devices = Inventory.search_devices(filters)

    socket =
      socket
      |> assign(:page_title, "Devices")
      |> assign(:filters, filters)
      |> assign(:current_user, current_user)
      |> assign(:selected_ids, MapSet.new())
      |> assign(:bulk_form, %{"command" => ""})
      |> assign(:modal_device, %Device{})
      |> assign(:modal_title, nil)
      |> assign(:command_error, nil)
      |> assign(:selected_count, 0)
      |> stream(:devices, devices, reset: true)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(NetAuto.PubSub, "inventory:devices")
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = filters_from_params(params, socket.assigns.filters || @default_filters)

    socket =
      socket
      |> assign(:filters, filters)
      |> assign(:page_title, page_title(socket.assigns.live_action))

    socket = socket |> assign_modal_state(params) |> load_devices()
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    filters = Map.put(socket.assigns.filters, :query, query)

    socket =
      socket
      |> assign(:filters, filters)

    {:noreply, push_patch(socket, to: ~p"/devices?q=#{query}")}
  end

  def handle_event("open_new", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/devices/new")}
  end

  def handle_event("edit_device", %{"id" => id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/devices/#{id}/edit")}
  end

  def handle_event("toggle_device", %{"id" => id}, socket) do
    device_id = parse_id(id)
    selected_ids = toggle_selection(socket.assigns.selected_ids, device_id)

    socket =
      socket
      |> assign(:selected_ids, selected_ids)
      |> assign(:selected_count, MapSet.size(selected_ids))

    {:noreply, socket}
  end

  def handle_event("open_bulk_modal", _params, %{assigns: %{selected_count: 0}} = socket),
    do: {:noreply, socket}

  def handle_event("open_bulk_modal", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/devices/bulk")}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/devices")}
  end

  def handle_event(
        "submit_bulk",
        %{"command" => command},
        %{assigns: %{selected_ids: ids}} = socket
      ) do
    device_ids = MapSet.to_list(ids)

    if device_ids == [] do
      {:noreply, put_flash(socket, :error, "Select at least one device.")}
    else
      start_bulk(socket, command, device_ids)
    end
  end

  defp start_bulk(socket, command, device_ids) do
    case Automation.bulk_enqueue(command, device_ids, requested_by: current_user_email(socket)) do
      {:ok, %{bulk_ref: bulk_ref}} ->
        count = length(device_ids)

        socket =
          socket
          |> assign(:selected_ids, MapSet.new())
          |> assign(:selected_count, 0)
          |> assign(:bulk_form, %{"command" => ""})
          |> put_flash(:info, "Bulk run started for #{count} device(s)")

        {:noreply, push_navigate(socket, to: ~p"/bulk/#{bulk_ref}")}

      {:error, :invalid_command} ->
        {:noreply, assign(socket, :command_error, "Command is required")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Unable to start bulk run: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({NetAutoWeb.DeviceLive.FormComponent, {:saved, device}}, socket) do
    message = if socket.assigns.live_action == :new, do: "Device saved", else: "Device updated"

    socket =
      socket
      |> put_flash(:info, message)
      |> push_patch(to: ~p"/devices")
      |> stream_insert(:devices, device, at: 0)

    {:noreply, socket}
  end

  def handle_info({:device, :created, device}, socket) do
    {:noreply, stream_insert(socket, :devices, device, at: 0)}
  end

  def handle_info({:device, :updated, device}, socket) do
    {:noreply, stream_insert(socket, :devices, device)}
  end

  def handle_info({:device, :deleted, device}, socket) do
    selected_ids = MapSet.delete(socket.assigns.selected_ids, device.id)

    socket =
      socket
      |> stream_delete(:devices, device)
      |> assign(:selected_ids, selected_ids)
      |> assign(:selected_count, MapSet.size(selected_ids))

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />
    <section class="mx-auto flex max-w-6xl flex-col gap-6 px-6 py-10">
      <header class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <p class="text-sm text-base-content/70">Inventory</p>
          <h1 class="text-3xl font-semibold text-base-content">Devices</h1>
        </div>
        <div class="flex w-full flex-col gap-3 md:w-auto md:flex-row md:items-center">
          <.form id="device-search-form" for={%{}} phx-change="search" class="flex-1">
            <label class="input input-bordered flex items-center gap-2">
              <input
                type="search"
                name="q"
                value={@filters.query}
                placeholder="Search hostname, IP, site..."
                class="grow"
              />
            </label>
          </.form>
          <div class="flex gap-2">
            <button type="button" class="btn btn-soft btn-primary" phx-click="open_new">
              Add Device
            </button>
          </div>
        </div>
      </header>

      <div class="rounded-xl border border-base-200 bg-base-100">
        <div class="flex items-center justify-between border-b border-base-200 px-4 py-3">
          <div class="text-sm text-base-content/70">
            Selected: {@selected_count}
          </div>
          <button
            id="bulk-run-button"
            type="button"
            phx-click="open_bulk_modal"
            class="btn btn-primary btn-sm"
            disabled={@selected_count == 0}
          >
            Run Bulk Command
          </button>
        </div>

        <div class="overflow-x-auto">
          <table class="table" id="devices-table">
            <thead>
              <tr>
                <th></th>
                <th>Hostname</th>
                <th>IP</th>
                <th>Protocol</th>
                <th>Site</th>
                <th>Owner</th>
                <th></th>
              </tr>
            </thead>
            <tbody id="devices-stream" phx-update="stream">
              <tr :for={{dom_id, device} <- @streams.devices} id={dom_id} data-role="device-row">
                <td class="align-top">
                  <input
                    id={"device-select-#{device.id}"}
                    type="checkbox"
                    class="checkbox checkbox-sm"
                    phx-click="toggle_device"
                    phx-value-id={device.id}
                    checked={MapSet.member?(@selected_ids, device.id)}
                  />
                </td>
                <td class="align-top font-semibold" id={"device-row-#{device.id}"}>
                  {device.hostname}
                  <p class="font-normal text-sm text-base-content/60">{device.vendor || "Unknown"}</p>
                </td>
                <td class="align-top font-mono text-sm">{device.ip}</td>
                <td class="align-top">
                  <span class="badge badge-outline">{String.upcase(to_string(device.protocol))}</span>
                </td>
                <td class="align-top">{device.site || "n/a"}</td>
                <td class="align-top">{device.username || "n/a"}</td>
                <td class="align-top text-right">
                  <button
                    type="button"
                    data-role="edit"
                    data-device-id={device.id}
                    class="btn btn-ghost btn-xs"
                    phx-click="edit_device"
                    phx-value-id={device.id}
                  >
                    Edit
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div :if={modal_open?(@live_action)} id="device-modal" class="modal modal-open">
        <div class="modal-box space-y-4">
          <header class="flex items-start justify-between">
            <div>
              <p class="text-sm text-base-content/70">Inventory</p>
              <h2 class="text-xl font-semibold text-base-content">{modal_title(@live_action)}</h2>
            </div>
            <button type="button" class="btn btn-circle btn-ghost btn-sm" phx-click="close_modal">
              ✕
            </button>
          </header>

          <div :if={@live_action in [:new, :edit]}>
            <.live_component
              module={NetAutoWeb.DeviceLive.FormComponent}
              id="device-form-component"
              device={@modal_device}
              action={@live_action}
              patch={~p"/devices"}
            />
          </div>

          <form :if={@live_action == :bulk} id="bulk-command-form" phx-submit="submit_bulk">
            <label class="text-sm font-medium">Command</label>
            <textarea
              name="command"
              class="textarea textarea-bordered mt-1 h-32 w-full font-mono"
              placeholder="show version"
              required
            >{@bulk_form["command"]}</textarea>
            <p :if={@command_error} class="text-sm text-error">{@command_error}</p>
            <div class="mt-4 flex justify-end gap-2">
              <button type="button" class="btn btn-ghost" phx-click="close_modal">Cancel</button>
              <button type="submit" class="btn btn-primary">
                Run on {@selected_count} device(s)
              </button>
            </div>
          </form>
        </div>
        <div class="modal-backdrop" phx-click="close_modal" />
      </div>
    </section>
    """
  end

  defp modal_open?(action) when action in [:new, :edit, :bulk], do: true
  defp modal_open?(_), do: false

  defp modal_title(:new), do: "Add Device"
  defp modal_title(:edit), do: "Edit Device"
  defp modal_title(:bulk), do: "Run Bulk Command"
  defp modal_title(_), do: nil

  defp assign_modal_state(socket, params) do
    case socket.assigns.live_action do
      :edit ->
        id = params["device_id"] || params["id"]
        device = Inventory.get_device!(id)
        assign(socket, :modal_device, device)

      :new ->
        assign(socket, :modal_device, %Device{})

      :bulk ->
        assign(socket, :command_error, nil)

      _ ->
        socket
    end
  end

  defp load_devices(socket) do
    devices = Inventory.search_devices(socket.assigns.filters)
    stream(socket, :devices, devices, reset: true)
  end

  defp page_title(:new), do: "Add Device"
  defp page_title(:edit), do: "Edit Device"
  defp page_title(:bulk), do: "Bulk Command"
  defp page_title(_), do: "Devices"

  defp filters_from_params(params, defaults) do
    %{
      query: Map.get(params, "q", defaults.query || ""),
      sort_by: defaults.sort_by || :hostname,
      sort_dir: defaults.sort_dir || :asc
    }
  end

  defp toggle_selection(selected_ids, nil), do: selected_ids

  defp toggle_selection(selected_ids, id) do
    if MapSet.member?(selected_ids, id) do
      MapSet.delete(selected_ids, id)
    else
      MapSet.put(selected_ids, id)
    end
  end

  defp parse_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_id(value) when is_integer(value), do: value
  defp parse_id(_), do: nil

  defp fetch_current_user(session) do
    with token when is_binary(token) <- session["user_token"],
         {user, _inserted_at} <- Accounts.get_user_by_session_token(token) do
      user
    else
      _ -> nil
    end
  end

  defp current_user_email(socket) do
    socket.assigns
    |> Map.get(:current_user)
    |> case do
      %{email: email} -> email
      _ -> nil
    end
  end
end
