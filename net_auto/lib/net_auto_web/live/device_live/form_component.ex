defmodule NetAutoWeb.DeviceLive.FormComponent do
  @moduledoc """
  Modal form for creating or editing devices.
  """

  use NetAutoWeb, :live_component

  alias Ecto.Enum, as: EctoEnum
  alias Jason
  alias NetAuto.Inventory
  alias NetAuto.Inventory.Device

  @impl true
  def update(%{device: device} = assigns, socket) do
    changeset = Inventory.change_device(device)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"device" => device_params}, socket) do
    changeset =
      socket.assigns.device
      |> Inventory.change_device(normalize_params(device_params))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"device" => device_params}, socket) do
    save_device(socket, socket.assigns.action, normalize_params(device_params))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        id="device-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="space-y-4"
      >
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <.input field={@form[:hostname]} label="Hostname" required />
          <.input field={@form[:ip]} label="IP Address" required />
          <.input
            field={@form[:protocol]}
            type="select"
            label="Protocol"
            options={protocol_options()}
          />
          <.input field={@form[:port]} label="Port" type="number" min="1" max="65535" />
          <.input field={@form[:username]} label="Username" required />
          <.input field={@form[:cred_ref]} label="Credential Reference" required />
          <.input field={@form[:vendor]} label="Vendor" />
          <.input field={@form[:model]} label="Model" />
          <.input field={@form[:site]} label="Site" />
          <.input
            field={@form[:tags]}
            type="textarea"
            label="Tags (JSON map)"
            value={tags_input_value(@form[:tags].value)}
          />
        </div>
        <div class="flex justify-end">
          <button type="submit" class="btn btn-primary" phx-disable-with="Saving...">
            {if @action == :new, do: "Save Device", else: "Update Device"}
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp save_device(socket, :new, params) do
    case Inventory.create_device(params) do
      {:ok, device} ->
        notify_parent({:saved, device})
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_device(socket, :edit, params) do
    case Inventory.update_device(socket.assigns.device, params) do
      {:ok, device} ->
        notify_parent({:saved, device})
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp normalize_params(params) do
    params
    |> Map.update("tags", %{}, &decode_tags/1)
  end

  defp decode_tags(tags) when is_map(tags), do: tags

  defp decode_tags(tags) when is_binary(tags) do
    trimmed = String.trim(tags)

    if trimmed == "" do
      %{}
    else
      case Jason.decode(trimmed) do
        {:ok, map} when is_map(map) -> map
        _ -> trimmed
      end
    end
  end

  defp decode_tags(_), do: %{}

  defp tags_input_value(%{} = tags) when map_size(tags) == 0, do: ""
  defp tags_input_value(%{} = tags), do: Jason.encode!(tags)
  defp tags_input_value(other) when is_binary(other), do: other
  defp tags_input_value(_), do: ""

  defp protocol_options do
    Device
    |> EctoEnum.values(:protocol)
    |> Enum.map(&{String.upcase(to_string(&1)), &1})
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
