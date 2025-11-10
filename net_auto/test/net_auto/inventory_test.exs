defmodule NetAuto.InventoryTest do
  use NetAuto.DataCase, async: true

  alias NetAuto.Inventory
  alias NetAuto.InventoryFixtures

  describe "devices" do
    test "create_device/1 with valid data" do
      assert {:ok, device} =
               Inventory.create_device(%{
                 hostname: "sw1",
                 ip: "192.0.2.5",
                 protocol: :ssh,
                 port: 22,
                 username: "netops",
                 cred_ref: "LAB01"
               })

      assert device.hostname == "sw1"
    end

    test "create_device/1 with invalid data returns error changeset" do
      assert {:error, changeset} = Inventory.create_device(%{})
      assert %{hostname: ["can't be blank"]} = errors_on(changeset)
    end

    test "list_devices/0 returns stored devices" do
      device = InventoryFixtures.device_fixture()
      assert Enum.any?(Inventory.list_devices(), &(&1.id == device.id))
    end

    test "search_devices/1 filters and sorts results" do
      _first = InventoryFixtures.device_fixture(%{hostname: "alpha"})
      _second = InventoryFixtures.device_fixture(%{hostname: "bravo"})

      results = Inventory.search_devices(%{query: "alpha"})
      assert Enum.map(results, & &1.hostname) == ["alpha"]

      sorted = Inventory.search_devices(%{sort_by: "hostname", sort_dir: "desc"})
      assert Enum.map(sorted, & &1.hostname) |> Enum.take(2) == ["bravo", "alpha"]

      fallback = Inventory.search_devices(%{sort_by: "not-a-field"})
      names = Enum.map(fallback, & &1.hostname)
      assert names == Enum.sort(names)
    end

    test "delete_device/1 removes record" do
      device = InventoryFixtures.device_fixture()
      assert {:ok, _} = Inventory.delete_device(device)
      refute Enum.any?(Inventory.list_devices(), &(&1.id == device.id))
    end

    test "change_device/2 returns changeset" do
      device = InventoryFixtures.device_fixture()
      assert %Ecto.Changeset{} = Inventory.change_device(device, %{hostname: "updated"})
    end
  end

  describe "device groups" do
    test "create_device_group/1 requires name" do
      assert {:error, changeset} = Inventory.create_device_group(%{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "device_group CRUD" do
      {:ok, group} = Inventory.create_device_group(%{name: "core", description: "Core"})
      assert %{} = Inventory.get_device_group!(group.id)

      {:ok, updated} = Inventory.update_device_group(group, %{description: "Backbone"})
      assert updated.description == "Backbone"

      assert {:ok, %Inventory.DeviceGroup{}} = Inventory.delete_device_group(updated)
    end
  end

  describe "memberships" do
    test "add_device_to_group/1 enforces uniqueness" do
      membership = InventoryFixtures.membership_fixture()

      assert {:error, changeset} =
               Inventory.add_device_to_group(%{
                 device_id: membership.device_id,
                 device_group_id: membership.device_group_id
               })

      assert %{device_id: ["device already added to this group"]} = errors_on(changeset)
    end

    test "list and remove memberships" do
      membership = InventoryFixtures.membership_fixture()
      assert Enum.any?(Inventory.list_memberships(), &(&1.id == membership.id))
      assert {:ok, _} = Inventory.remove_device_from_group(membership)
      refute Enum.any?(Inventory.list_memberships(), &(&1.id == membership.id))
    end
  end

  describe "command templates" do
    test "create_command_template/1" do
      assert {:ok, template} =
               Inventory.create_command_template(%{name: "show", body: "show", mode: :read})

      assert template.enabled
    end

    test "invalid mode rejected" do
      assert {:error, changeset} =
               Inventory.create_command_template(%{name: "bad", body: "noop", mode: :write})

      assert %{mode: ["is invalid"]} = errors_on(changeset)
    end

    test "list and change command templates" do
      template = InventoryFixtures.command_template_fixture()
      assert Enum.any?(Inventory.list_command_templates(), &(&1.id == template.id))
      assert %Ecto.Changeset{} = Inventory.change_command_template(template, %{name: "updated"})
    end
  end
end
