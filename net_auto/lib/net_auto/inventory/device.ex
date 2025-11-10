defmodule NetAuto.Inventory.Device do
  @moduledoc """
  Represents a managed network device.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias NetAuto.Automation.Run
  alias NetAuto.Inventory.DeviceGroupMembership

  @protocol_values [:ssh, :telnet]

  @typedoc "Managed network device metadata"
  @type protocol :: :ssh | :telnet
  @type t :: %__MODULE__{
          id: integer() | nil,
          hostname: String.t() | nil,
          ip: String.t() | nil,
          protocol: protocol(),
          port: integer() | nil,
          username: String.t() | nil,
          cred_ref: String.t() | nil,
          vendor: String.t() | nil,
          model: String.t() | nil,
          site: String.t() | nil,
          tags: map(),
          metadata: map()
        }

  schema "devices" do
    field :hostname, :string
    field :ip, :string
    field :protocol, Ecto.Enum, values: @protocol_values, default: :ssh
    field :port, :integer, default: 22
    field :username, :string
    field :cred_ref, :string
    field :vendor, :string
    field :model, :string
    field :site, :string
    field :tags, :map, default: %{}
    field :metadata, :map, default: %{}

    has_many :group_memberships, DeviceGroupMembership
    has_many :runs, Run

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(device, attrs) do
    device
    |> cast(attrs, [
      :hostname,
      :ip,
      :protocol,
      :port,
      :username,
      :cred_ref,
      :vendor,
      :model,
      :site,
      :tags,
      :metadata
    ])
    |> validate_required([:hostname, :ip, :protocol, :port, :username, :cred_ref])
    |> validate_inclusion(:protocol, @protocol_values)
    |> validate_number(:port, greater_than: 0, less_than_or_equal_to: 65_535)
    |> unique_constraint(:hostname, name: :devices_hostname_site_index)
    |> validate_tags()
  end

  defp validate_tags(changeset) do
    case fetch_change(changeset, :tags) do
      {:ok, tags} when is_map(tags) -> changeset
      {:ok, _bad} -> add_error(changeset, :tags, "must be a map of metadata")
      :error -> changeset
    end
  end
end
