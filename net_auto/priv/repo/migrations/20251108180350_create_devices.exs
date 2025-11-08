defmodule NetAuto.Repo.Migrations.CreateDevices do
  use Ecto.Migration

  def change do
    create table(:devices) do
      add :hostname, :string, null: false
      add :ip, :string, null: false
      add :protocol, :string, null: false, default: "ssh"
      add :port, :integer, null: false, default: 22
      add :username, :string, null: false
      add :cred_ref, :string, null: false
      add :vendor, :string
      add :model, :string
      add :site, :string
      add :tags, :map, null: false, default: %{}
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:devices, [:hostname, :site], name: :devices_hostname_site_index)
    create index(:devices, [:cred_ref])
    create index(:devices, [:protocol])
  end
end
