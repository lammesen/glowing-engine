defmodule NetAuto.InventoryFixtures do
  @moduledoc """
  Test helpers for creating devices, groups, and templates.
  """

  alias NetAuto.Inventory

  def device_fixture(attrs \\ %{}) do
    defaults = %{
      hostname: "lab-#{System.unique_integer()}",
      ip: "192.0.2.#{System.unique_integer([:positive]) |> rem(200)}",
      protocol: :ssh,
      port: 22,
      username: "netops",
      cred_ref: "LAB_DEFAULT",
      vendor: "acme",
      model: "edge",
      site: "dc1",
      tags: %{}
    }

    {:ok, device} = attrs |> Enum.into(defaults) |> Inventory.create_device()
    device
  end

  def device_group_fixture(attrs \\ %{}) do
    defaults = %{
      name: "core-#{System.unique_integer()}",
      description: "Core switches",
      site: "dc1"
    }

    {:ok, group} = attrs |> Enum.into(defaults) |> Inventory.create_device_group()
    group
  end

  def command_template_fixture(attrs \\ %{}) do
    defaults = %{
      name: "show-version-#{System.unique_integer()}",
      body: "show version",
      mode: :read,
      variables: %{}
    }

    {:ok, template} = attrs |> Enum.into(defaults) |> Inventory.create_command_template()
    template
  end

  def membership_fixture(attrs \\ %{}) do
    device = Map.get(attrs, :device) || device_fixture()
    group = Map.get(attrs, :device_group) || device_group_fixture()

    defaults = %{device_id: device.id, device_group_id: group.id, role: :member}

    {:ok, membership} =
      attrs
      |> Map.drop([:device, :device_group])
      |> Enum.into(defaults)
      |> Inventory.add_device_to_group()

    membership
  end
end
