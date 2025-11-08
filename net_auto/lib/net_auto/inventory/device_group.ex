defmodule NetAuto.Inventory.DeviceGroup do
  @moduledoc """
  Logical grouping for devices.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias NetAuto.Inventory.DeviceGroupMembership

  schema "device_groups" do
    field :name, :string
    field :description, :string
    field :site, :string
    field :tags, :map, default: %{}
    field :metadata, :map, default: %{}

    has_many :memberships, DeviceGroupMembership
    has_many :devices, through: [:memberships, :device]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(group, attrs) do
    group
    |> cast(attrs, [:name, :description, :site, :tags, :metadata])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
