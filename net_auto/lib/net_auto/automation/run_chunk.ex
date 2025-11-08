defmodule NetAuto.Automation.RunChunk do
  @moduledoc """
  Stores streamed output for a run.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias NetAuto.Automation.Run

  schema "run_chunks" do
    field :seq, :integer
    field :data, :string

    belongs_to :run, Run

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(chunk, attrs) do
    chunk
    |> cast(attrs, [:seq, :data, :run_id])
    |> validate_required([:seq, :data, :run_id])
    |> validate_number(:seq, greater_than_or_equal_to: 0)
    |> assoc_constraint(:run)
    |> unique_constraint(:seq, name: :run_chunks_run_id_seq_index)
  end
end
