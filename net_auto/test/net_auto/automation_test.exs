defmodule NetAuto.AutomationTest do
  use NetAuto.DataCase, async: false

  alias NetAuto.Automation
  alias NetAuto.AutomationFixtures
  alias NetAuto.InventoryFixtures
  alias NetAuto.Inventory.Device
  alias NetAuto.Repo
  alias Oban.Job
  import Mox

  setup_all do
    ensure_started({Registry, keys: :unique, name: NetAuto.Automation.Registry})
    ensure_started(NetAuto.Automation.QuotaServer)
    ensure_started(NetAuto.Automation.RunSupervisor)
    :ok
  end

  setup :set_mox_global
  setup :verify_on_exit!

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

  describe "paginated_runs_for_device/2" do
    test "filters by status, operator, query, and date range" do
      device = InventoryFixtures.device_fixture(%{hostname: "core-1", site: "dc1"})
      _other_device = InventoryFixtures.device_fixture()

      base_time = DateTime.utc_now() |> DateTime.truncate(:second)

      create_run = fn attrs ->
        {:ok, run} =
          %{command: "show version", status: :ok, requested_by: "alice", requested_at: base_time}
          |> Map.merge(attrs)
          |> Map.put(:device_id, device.id)
          |> Automation.create_run()

        run
      end

      matching1 =
        create_run.(%{status: :running, requested_at: DateTime.add(base_time, 60, :second)})

      matching2 = create_run.(%{status: :ok, requested_at: DateTime.add(base_time, 120, :second)})
      matching3 = create_run.(%{status: :ok, requested_at: DateTime.add(base_time, 180, :second)})

      _different_operator = create_run.(%{requested_by: "bob", command: "show clock"})
      _different_command = create_run.(%{command: "configure terminal"})

      params = %{
        "page" => "1",
        "per_page" => "2",
        "statuses" => ["running", "ok"],
        "requested_by" => "alice",
        "query" => "version",
        "from" => DateTime.to_iso8601(DateTime.add(base_time, 30, :second)),
        "to" => DateTime.to_iso8601(DateTime.add(base_time, 190, :second))
      }

      %{entries: entries, total: total, page: page, per_page: per_page} =
        Automation.paginated_runs_for_device(device.id, params)

      assert total == 3
      assert page == 1
      assert per_page == 2
      assert Enum.map(entries, & &1.id) == [matching3.id, matching2.id]

      # Page 2 should return the last matching run
      %{entries: entries_page2} =
        Automation.paginated_runs_for_device(device.id, Map.put(params, "page", "2"))

      assert Enum.map(entries_page2, & &1.id) == [matching1.id]
    end
  end

  describe "latest_run_for_device/1" do
    test "returns the newest run for the device" do
      device = InventoryFixtures.device_fixture()

      {:ok, _older} =
        Automation.create_run(%{command: "show version", status: :ok, device_id: device.id})

      {:ok, newer} =
        Automation.create_run(%{
          command: "show inventory",
          status: :running,
          device_id: device.id,
          requested_at: DateTime.add(DateTime.utc_now(), 60, :second)
        })

      assert Automation.latest_run_for_device(device.id).id == newer.id
    end
  end

  describe "retention_config/0" do
    setup do
      original = Application.get_env(:net_auto, NetAuto.Automation.Retention)

      on_exit(fn ->
        Application.put_env(:net_auto, NetAuto.Automation.Retention, original)
      end)

      :ok
    end

    test "returns defaults when no config set" do
      Application.put_env(:net_auto, NetAuto.Automation.Retention, %{})
      assert %{max_age_days: 30, max_total_bytes: :infinity} = Automation.retention_config()
    end

    test "normalizes configured values" do
      Application.put_env(:net_auto, NetAuto.Automation.Retention, %{
        max_age_days: "10",
        max_total_bytes: "2048"
      })

      assert %{max_age_days: 10, max_total_bytes: 2048} = Automation.retention_config()
    end
  end

  describe "bulk_enqueue/3" do
    setup do
      Repo.delete_all(Job)
      :ok
    end

    test "validates command presence" do
      assert {:error, :invalid_command} = Automation.bulk_enqueue("  ", [1])
    end

    test "validates device ids" do
      assert {:error, :no_devices} = Automation.bulk_enqueue("show version", [])
      assert {:error, :invalid_devices} = Automation.bulk_enqueue("show version", "not a list")
    end

    test "chunks enqueued jobs and returns bulk ref" do
      device_ids =
        Enum.map(1..55, fn _ -> InventoryFixtures.device_fixture().id end)

      assert {:ok, %{bulk_ref: bulk_ref, jobs: jobs}} =
               Automation.bulk_enqueue("show version", device_ids, requested_by: "ops")

      assert length(jobs) == 2

      Enum.each(jobs, fn job ->
        assert job.args["bulk_ref"] == bulk_ref
        assert job.args["requested_by"] == "ops"
      end)

      assert Repo.aggregate(Job, :count, :id) == 2
    end

    test "accepts string device ids and deduplicates" do
      id = InventoryFixtures.device_fixture().id

      assert {:ok, %{jobs: [%{args: %{"device_ids" => ids}}]}} =
               Automation.bulk_enqueue("show version", ["  #{id}  ", id, %Device{id: id}])

      assert ids == [id]
    end

    test "normalizes chunk size option" do
      device_ids = Enum.map(1..3, fn _ -> InventoryFixtures.device_fixture().id end)

      assert {:ok, %{jobs: jobs}} =
               Automation.bulk_enqueue("show version", device_ids, chunk_size: 1)

      assert length(jobs) == 3
      assert Enum.all?(jobs, fn job -> length(job.args["device_ids"]) == 1 end)
    end
  end

  describe "execute_run/2" do
    setup do
      Application.put_env(:net_auto, NetAuto.Protocols, adapter: NetAuto.ProtocolsAdapterMock)
      on_exit(fn -> Application.delete_env(:net_auto, NetAuto.Protocols) end)
      :ok
    end

    test "creates run and starts run server" do
      device = InventoryFixtures.device_fixture(%{site: "chi1"})

      expect(NetAuto.ProtocolsAdapterMock, :run, fn ^device, "show version", _opts, chunk_cb ->
        chunk_cb.("chunk\n")
        {:ok, 0, 6}
      end)

      assert {:ok, run} =
               Automation.execute_run(device, %{command: "show version", requested_by: "ops"})

      assert eventually(fn -> Automation.get_run!(run.id).status == :ok end)
    end

    test "fails fast when quota exceeded and marks run error" do
      quota_name = Module.concat(__MODULE__, "Quota#{System.unique_integer([:positive])}")
      start_supervised!({NetAuto.Automation.QuotaServer, name: quota_name, global_limit: 0})
      device = InventoryFixtures.device_fixture(%{site: "chi1"})

      assert {:error, {:quota_exceeded, :global}} =
               Automation.execute_run(device, %{command: "show ip"}, quota_server: quota_name)

      [run] = Automation.list_runs()
      assert run.status == :error
      assert run.error_reason =~ "quota"
    end
  end

  describe "cancel_run/1" do
    setup do
      Application.put_env(:net_auto, NetAuto.Protocols, adapter: NetAuto.ProtocolsAdapterMock)
      on_exit(fn -> Application.delete_env(:net_auto, NetAuto.Protocols) end)
      :ok
    end

    test "cancels active run via RunServer" do
      device = InventoryFixtures.device_fixture()

      parent = self()

      expect(NetAuto.ProtocolsAdapterMock, :run, fn ^device, "show clock", _opts, _chunk_cb ->
        send(parent, :adapter_started)
        Process.sleep(:infinity)
      end)

      assert {:ok, run} =
               Automation.execute_run(device, %{command: "show clock", requested_by: "ops"})

      assert_receive :adapter_started
      assert :ok = Automation.cancel_run(run.id)
      assert eventually(fn -> Automation.get_run!(run.id).status == :error end)
    end
  end

  defp eventually(fun, attempts \\ 20)

  defp eventually(_fun, 0), do: flunk("condition not met")

  defp eventually(fun, attempts) do
    if fun.() do
      true
    else
      Process.sleep(50)
      eventually(fun, attempts - 1)
    end
  end

  defp ensure_started(spec) do
    case start_supervised(spec) do
      {:ok, pid} ->
        on_exit(fn -> Process.exit(pid, :normal) end)
        :ok

      {:error, {:already_started, _pid}} ->
        :ok
    end
  end

  describe "telemetry" do
    test "emits event on run creation" do
      event = [:net_auto, :run, :created]
      handler_id = "automation-run-created-#{System.unique_integer()}"

      :telemetry.attach(
        handler_id,
        event,
        fn ^event, measurements, metadata, _config ->
          send(self(), {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      run = AutomationFixtures.run_fixture()
      run_id = run.id

      assert_receive {:telemetry_event, ^event, %{count: 1}, %{run_id: ^run_id}}
    end

    test "emits event when chunks appended" do
      run = AutomationFixtures.run_fixture()
      event = [:net_auto, :run, :chunk_appended]
      handler_id = "automation-chunk-appended-#{System.unique_integer()}"

      :telemetry.attach(
        handler_id,
        event,
        fn ^event, measurements, metadata, _ ->
          send(self(), {:telemetry_event, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      {:ok, _chunk} = Automation.append_chunk(%{run_id: run.id, seq: 0, data: "data"})
      run_id = run.id

      assert_receive {
        :telemetry_event,
        ^event,
        %{count: 1, bytes: 4},
        %{run_id: ^run_id, seq: 0}
      }
    end
  end
end
