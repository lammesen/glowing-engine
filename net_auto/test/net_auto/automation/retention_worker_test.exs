defmodule NetAuto.Automation.RetentionWorkerTest do
  use NetAuto.DataCase, async: false

  import Ecto.Query

  alias NetAuto.Automation.RetentionWorker
  alias NetAuto.Automation.Run
  alias NetAuto.AutomationFixtures
  alias NetAuto.InventoryFixtures
  alias NetAuto.Repo
  alias Oban.Job

  @telemetry_event [:net_auto, :retention, :purge]

  setup do
    original = Application.get_env(:net_auto, NetAuto.Automation.Retention)

    on_exit(fn ->
      Application.put_env(:net_auto, NetAuto.Automation.Retention, original)
      :telemetry.detach(__MODULE__)
    end)

    :telemetry.attach(
      __MODULE__,
      @telemetry_event,
      fn _event, meas, meta, _config ->
        send(self(), {:retention_event, meas, meta})
      end,
      nil
    )

    :ok
  end

  test "purges runs older than configured age" do
    Application.put_env(:net_auto, NetAuto.Automation.Retention, %{
      max_age_days: 5,
      max_total_bytes: :infinity
    })

    device = InventoryFixtures.device_fixture()
    stale = AutomationFixtures.run_fixture(%{device: device, bytes: 10})
    fresh = AutomationFixtures.run_fixture(%{device: device, bytes: 5})

    set_run_timestamp(stale, 30)
    set_run_timestamp(fresh, 1)

    assert :ok = RetentionWorker.perform(%Job{})
    refute Repo.get(Run, stale.id)
    assert Repo.get(Run, fresh.id)

    assert_receive {:retention_event, %{runs_deleted: 1, bytes_deleted: 10}, %{type: :age}}
    assert_receive {:retention_event, %{runs_deleted: 0}, %{type: :bytes}}
  end

  test "purges oldest runs per device when total bytes exceed limit" do
    Application.put_env(:net_auto, NetAuto.Automation.Retention, %{
      max_age_days: 365,
      max_total_bytes: 10
    })

    device = InventoryFixtures.device_fixture()

    r1 = AutomationFixtures.run_fixture(%{device: device, bytes: 4})
    r2 = AutomationFixtures.run_fixture(%{device: device, bytes: 7})
    r3 = AutomationFixtures.run_fixture(%{device: device, bytes: 2})

    set_run_timestamp(r1, 10)
    set_run_timestamp(r2, 9)
    set_run_timestamp(r3, 1)

    assert :ok = RetentionWorker.perform(%Job{})

    remaining_ids =
      Run
      |> where(device_id: ^device.id)
      |> select([r], r.id)
      |> Repo.all()

    assert Enum.sort(remaining_ids) == Enum.sort([r2.id, r3.id])

    total_bytes =
      Run
      |> where(device_id: ^device.id)
      |> Repo.all()
      |> Enum.reduce(0, fn run, acc -> acc + (run.bytes || 0) end)

    assert total_bytes <= 10

    assert_receive {:retention_event, _meas, %{type: :age}}
    assert_receive {:retention_event, %{runs_deleted: 1, bytes_deleted: 4}, %{type: :bytes}}
  end

  defp set_run_timestamp(run, days_ago) do
    timestamp =
      DateTime.utc_now()
      |> DateTime.add(-days_ago * 86_400, :second)
      |> DateTime.truncate(:second)

    from(r in Run, where: r.id == ^run.id)
    |> Repo.update_all(set: [inserted_at: timestamp, finished_at: timestamp])
  end
end
