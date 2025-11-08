defmodule NetAuto.Repo.Migrations.CreateRuns do
  use Ecto.Migration

  def change do
    create table(:runs) do
      add :command, :text, null: false
      add :status, :string, null: false, default: "pending"
      add :bytes, :bigint, null: false, default: 0
      add :exit_code, :integer
      add :requested_by, :string
      add :requested_at, :utc_datetime
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime
      add :error_reason, :text
      add :device_id, references(:devices, on_delete: :restrict), null: false
      add :command_template_id, references(:command_templates, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:runs, [:device_id, :inserted_at])
    create index(:runs, [:status])
  end
end
