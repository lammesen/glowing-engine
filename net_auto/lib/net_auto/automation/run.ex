defmodule NetAuto.Automation.Run do
  @moduledoc """
  Represents an execution request against a device.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias NetAuto.Automation.RunChunk
  alias NetAuto.Inventory.{CommandTemplate, Device}

  @status_values [:pending, :running, :ok, :error]

  @typedoc "Automation run record"
  @type status :: :pending | :running | :ok | :error
  @type t :: %__MODULE__{
          id: integer() | nil,
          command: String.t(),
          status: status(),
          bytes: integer() | nil,
          exit_code: integer() | nil,
          requested_by: String.t() | nil,
          requested_at: DateTime.t() | nil,
          started_at: DateTime.t() | nil,
          finished_at: DateTime.t() | nil,
          error_reason: String.t() | nil,
          device_id: integer() | nil,
          command_template_id: integer() | nil
        }

  schema "runs" do
    field :command, :string
    field :status, Ecto.Enum, values: @status_values, default: :pending
    field :bytes, :integer, default: 0
    field :exit_code, :integer
    field :requested_by, :string
    field :requested_at, :utc_datetime
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime
    field :error_reason, :string

    belongs_to :device, Device
    belongs_to :command_template, CommandTemplate
    has_many :chunks, RunChunk

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :command,
      :status,
      :bytes,
      :exit_code,
      :requested_by,
      :requested_at,
      :started_at,
      :finished_at,
      :error_reason,
      :device_id,
      :command_template_id
    ])
    |> validate_required([:command, :status, :device_id])
    |> validate_inclusion(:status, @status_values)
    |> validate_number(:bytes, greater_than_or_equal_to: 0)
    |> assoc_constraint(:device)
    |> assoc_constraint(:command_template)
  end
end
