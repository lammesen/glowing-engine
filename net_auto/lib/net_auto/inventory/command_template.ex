defmodule NetAuto.Inventory.CommandTemplate do
  @moduledoc """
  Stores reusable command templates applied to devices.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @mode_values [:read, :change]

  schema "command_templates" do
    field :name, :string
    field :body, :string
    field :mode, Ecto.Enum, values: @mode_values, default: :read
    field :variables, :map, default: %{}
    field :enabled, :boolean, default: true
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(template, attrs) do
    template
    |> cast(attrs, [:name, :body, :mode, :variables, :enabled, :notes])
    |> validate_required([:name, :body, :mode])
    |> validate_inclusion(:mode, @mode_values)
    |> unique_constraint(:name)
  end
end
