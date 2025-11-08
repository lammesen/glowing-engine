defmodule NetAuto.Repo.Migrations.CreateRunChunks do
  use Ecto.Migration

  def change do
    create table(:run_chunks) do
      add :seq, :bigint, null: false
      add :data, :text, null: false
      add :run_id, references(:runs, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:run_chunks, [:run_id, :seq])
  end
end
