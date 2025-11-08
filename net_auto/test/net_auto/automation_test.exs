defmodule NetAuto.AutomationTest do
  use NetAuto.DataCase, async: true

  alias NetAuto.Automation
  alias NetAuto.AutomationFixtures
  alias NetAuto.InventoryFixtures

  describe "runs" do
    test "create_run/1 requires command and device" do
      assert {:error, changeset} = Automation.create_run(%{})
      assert %{command: ["can't be blank"], device_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "list_runs/0 returns stored run" do
      run = AutomationFixtures.run_fixture()
      assert [fetched] = Automation.list_runs()
      assert fetched.id == run.id
    end

    test "update_run/2" do
      run = AutomationFixtures.run_fixture()
      assert {:ok, updated} = Automation.update_run(run, %{status: :running})
      assert updated.status == :running
    end
  end

  describe "run chunks" do
    test "append_chunk/1 inserts chunk" do
      run = AutomationFixtures.run_fixture(%{command: "show"})
      assert {:ok, chunk} = Automation.append_chunk(%{run_id: run.id, seq: 0, data: "line"})
      assert chunk.seq == 0
    end

    test "list_run_chunks/1 orders by seq" do
      run = AutomationFixtures.run_fixture()
      Automation.append_chunk(%{run_id: run.id, seq: 2, data: "c"})
      Automation.append_chunk(%{run_id: run.id, seq: 1, data: "b"})

      assert [%{seq: 1}, %{seq: 2}] = Automation.list_run_chunks(run.id)
    end
  end

  describe "foreign keys" do
    test "command_template optional" do
      template = InventoryFixtures.command_template_fixture()
      device = InventoryFixtures.device_fixture()

      assert {:ok, run} =
               Automation.create_run(%{
                 command: template.body,
                 status: :pending,
                 device_id: device.id,
                 command_template_id: template.id
               })

      assert run.command_template_id == template.id
    end
  end
end
