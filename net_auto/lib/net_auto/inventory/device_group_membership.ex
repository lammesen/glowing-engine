defmodule NetAuto.Inventory.DeviceGroupMembership do
  @moduledoc """
  Join table between devices and device groups.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias NetAuto.Inventory.{Device, DeviceGroup}

  @role_values [:member, :primary]

  schema "device_group_memberships" do
    field :role, Ecto.Enum, values: @role_values, default: :member

    belongs_to :device, Device
    belongs_to :device_group, DeviceGroup

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role, :device_id, :device_group_id])
    |> validate_required([:role, :device_id, :device_group_id])
    |> validate_inclusion(:role, @role_values)
    |> assoc_constraint(:device)
    |> assoc_constraint(:device_group)
    |> unique_constraint(:device_id,
      name: :devices_device_groups_unique,
      message: "device already added to this group"
    )
  end
end
