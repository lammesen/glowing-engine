defmodule NetAuto.Inventory do
  @moduledoc """
  Data layer for devices, groups, and command templates.
  """

  import Ecto.Query, warn: false
  alias NetAuto.Repo

  alias NetAuto.Inventory.{
    Device,
    DeviceGroup,
    DeviceGroupMembership,
    CommandTemplate
  }

  # Devices -----------------------------------------------------------------

  def list_devices(opts \\ []) do
    Device
    |> maybe_preload(opts)
    |> Repo.all()
  end

  def get_device!(id, opts \\ []) do
    Device
    |> maybe_preload(opts)
    |> Repo.get!(id)
  end

  def create_device(attrs \\ %{}) do
    %Device{}
    |> Device.changeset(attrs)
    |> Repo.insert()
  end

  def update_device(%Device{} = device, attrs) do
    device
    |> Device.changeset(attrs)
    |> Repo.update()
  end

  def delete_device(%Device{} = device), do: Repo.delete(device)

  def change_device(%Device{} = device, attrs \\ %{}) do
    Device.changeset(device, attrs)
  end

  # Device Groups -----------------------------------------------------------

  def list_device_groups(opts \\ []) do
    DeviceGroup
    |> maybe_preload(opts)
    |> Repo.all()
  end

  def get_device_group!(id, opts \\ []) do
    DeviceGroup
    |> maybe_preload(opts)
    |> Repo.get!(id)
  end

  def create_device_group(attrs \\ %{}) do
    %DeviceGroup{}
    |> DeviceGroup.changeset(attrs)
    |> Repo.insert()
  end

  def update_device_group(%DeviceGroup{} = group, attrs) do
    group
    |> DeviceGroup.changeset(attrs)
    |> Repo.update()
  end

  def delete_device_group(%DeviceGroup{} = group), do: Repo.delete(group)

  def change_device_group(%DeviceGroup{} = group, attrs \\ %{}) do
    DeviceGroup.changeset(group, attrs)
  end

  # Memberships -------------------------------------------------------------

  def list_memberships do
    Repo.all(DeviceGroupMembership)
  end

  def add_device_to_group(attrs) do
    %DeviceGroupMembership{}
    |> DeviceGroupMembership.changeset(attrs)
    |> Repo.insert()
  end

  def update_membership(%DeviceGroupMembership{} = membership, attrs) do
    membership
    |> DeviceGroupMembership.changeset(attrs)
    |> Repo.update()
  end

  def remove_device_from_group(%DeviceGroupMembership{} = membership), do: Repo.delete(membership)

  def change_membership(%DeviceGroupMembership{} = membership, attrs \\ %{}) do
    DeviceGroupMembership.changeset(membership, attrs)
  end

  # Command templates -------------------------------------------------------

  def list_command_templates, do: Repo.all(CommandTemplate)

  def get_command_template!(id), do: Repo.get!(CommandTemplate, id)

  def create_command_template(attrs \\ %{}) do
    %CommandTemplate{}
    |> CommandTemplate.changeset(attrs)
    |> Repo.insert()
  end

  def update_command_template(%CommandTemplate{} = template, attrs) do
    template
    |> CommandTemplate.changeset(attrs)
    |> Repo.update()
  end

  def delete_command_template(%CommandTemplate{} = template), do: Repo.delete(template)

  def change_command_template(%CommandTemplate{} = template, attrs \\ %{}) do
    CommandTemplate.changeset(template, attrs)
  end

  # Helpers -----------------------------------------------------------------

  defp maybe_preload(queryable, opts) do
    case Keyword.get(opts, :preload) do
      nil -> queryable
      preload -> preload(queryable, ^preload)
    end
  end
end
