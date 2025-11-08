defmodule NetAuto.Automation do
  @moduledoc """
  Data API for automation runs and streamed output chunks.
  """

  import Ecto.Query, warn: false
  alias NetAuto.Repo

  alias NetAuto.Automation.{Run, RunChunk}

  def list_runs(opts \\ []) do
    Run |> maybe_preload(opts) |> Repo.all()
  end

  def get_run!(id, opts \\ []) do
    Run |> maybe_preload(opts) |> Repo.get!(id)
  end

  def create_run(attrs \\ %{}) do
    %Run{}
    |> Run.changeset(attrs)
    |> Repo.insert()
  end

  def update_run(%Run{} = run, attrs) do
    run
    |> Run.changeset(attrs)
    |> Repo.update()
  end

  def delete_run(%Run{} = run), do: Repo.delete(run)

  def change_run(%Run{} = run, attrs \\ %{}) do
    Run.changeset(run, attrs)
  end

  # Run chunks --------------------------------------------------------------

  def list_run_chunks(run_id) do
    RunChunk
    |> where(run_id: ^run_id)
    |> order_by([c], asc: c.seq)
    |> Repo.all()
  end

  def append_chunk(attrs \\ %{}) do
    %RunChunk{}
    |> RunChunk.changeset(attrs)
    |> Repo.insert()
  end

  def change_run_chunk(%RunChunk{} = chunk, attrs \\ %{}) do
    RunChunk.changeset(chunk, attrs)
  end

  defp maybe_preload(queryable, opts) do
    case Keyword.get(opts, :preload) do
      nil -> queryable
      preload -> preload(queryable, ^preload)
    end
  end
end
