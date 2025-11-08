defmodule NetAuto.Repo.Migrations.CreateDeviceGroupMemberships do
  use Ecto.Migration

  def change do
    create table(:device_group_memberships) do
      add :role, :string, null: false, default: "member"
      add :device_id, references(:devices, on_delete: :delete_all), null: false
      add :device_group_id, references(:device_groups, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:device_group_memberships, [:device_id, :device_group_id],
             name: :devices_device_groups_unique
           )

    create index(:device_group_memberships, [:device_group_id])
  end
end
