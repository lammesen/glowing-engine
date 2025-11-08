defmodule NetAuto.Repo.Migrations.CreateCommandTemplates do
  use Ecto.Migration

  def change do
    create table(:command_templates) do
      add :name, :string, null: false
      add :body, :text, null: false
      add :mode, :string, null: false, default: "read"
      add :variables, :map, null: false, default: %{}
      add :enabled, :boolean, null: false, default: true
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:command_templates, [:name])
  end
end
