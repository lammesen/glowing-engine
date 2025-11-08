defmodule NetAuto.Repo.Migrations.CreateDeviceGroups do
  use Ecto.Migration

  def change do
    create table(:device_groups) do
      add :name, :string, null: false
      add :description, :text
      add :site, :string
      add :tags, :map, null: false, default: %{}
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:device_groups, [:name])
    create index(:device_groups, [:site])
  end
end
