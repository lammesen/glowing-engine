defmodule NetAuto.Automation.RetentionWorker do
  @moduledoc """
  Oban worker that enforces retention policies for automation runs.
  """

  use Oban.Worker, queue: :retention, max_attempts: 1, priority: 0

  import Ecto.Query
  alias Decimal

  alias NetAuto.Automation
  alias NetAuto.Automation.Run
  alias NetAuto.Repo

  @seconds_in_day 86_400

  @impl true
  def perform(%Oban.Job{}) do
    config = Automation.retention_config()

    {age_deleted, age_bytes} = purge_by_age(config.max_age_days)
    emit(:age, age_deleted, age_bytes)

    {bytes_deleted, byte_volume} = purge_by_bytes(config.max_total_bytes)
    emit(:bytes, bytes_deleted, byte_volume)

    :ok
  end

  defp purge_by_age(days) when is_integer(days) and days > 0 do
    cutoff =
      DateTime.utc_now()
      |> DateTime.add(-days * @seconds_in_day, :second)

    query =
      from r in Run,
        where:
          fragment(
            "coalesce(?, ?) < ?",
            r.finished_at,
            r.inserted_at,
            ^cutoff
          )

    bytes = Repo.aggregate(query, :sum, :bytes) |> normalize_number()
    {deleted, _} = Repo.delete_all(query)
    {deleted, bytes}
  end

  defp purge_by_age(_), do: {0, 0}

  defp purge_by_bytes(:infinity), do: {0, 0}

  defp purge_by_bytes(limit) when is_integer(limit) and limit > 0 do
    device_totals(limit)
    |> Enum.reduce({0, 0}, fn {device_id, total_bytes}, {run_acc, byte_acc} ->
      excess = total_bytes - limit

      if excess > 0 do
        {deleted, bytes_deleted} = prune_device_runs_by_bytes(device_id, excess)
        {run_acc + deleted, byte_acc + bytes_deleted}
      else
        {run_acc, byte_acc}
      end
    end)
  end

  defp purge_by_bytes(_), do: {0, 0}

  defp device_totals(limit) do
    from(r in Run,
      group_by: r.device_id,
      having: sum(r.bytes) > ^limit,
      select: {r.device_id, sum(r.bytes)}
    )
    |> Repo.all()
    |> Enum.map(fn {device_id, total} -> {device_id, normalize_number(total)} end)
  end

  defp prune_device_runs_by_bytes(_device_id, bytes_to_remove) when bytes_to_remove <= 0,
    do: {0, 0}

  defp prune_device_runs_by_bytes(device_id, bytes_to_remove) do
    query =
      from r in Run,
        where: r.device_id == ^device_id,
        order_by: [asc: fragment("coalesce(?, ?)", r.finished_at, r.inserted_at)],
        select: %{id: r.id, bytes: fragment("coalesce(?, 0)", r.bytes)}

    {ids, bytes_deleted} =
      Repo.all(query)
      |> Enum.reduce_while({[], 0}, fn %{id: id, bytes: bytes}, {acc_ids, acc_bytes} ->
        if acc_bytes >= bytes_to_remove do
          {:halt, {acc_ids, acc_bytes}}
        else
          next_bytes = acc_bytes + normalize_number(bytes)
          {:cont, {[id | acc_ids], next_bytes}}
        end
      end)

    case ids do
      [] ->
        {0, 0}

      _ ->
        {deleted, _} =
          from(r in Run, where: r.id in ^ids)
          |> Repo.delete_all()

        {deleted, bytes_deleted}
    end
  end

  defp emit(type, runs_deleted, bytes_deleted) do
    measurements = %{runs_deleted: runs_deleted, bytes_deleted: bytes_deleted}
    metadata = %{type: type}
    :telemetry.execute([:net_auto, :retention, :purge], measurements, metadata)
  end

  defp normalize_number(nil), do: 0
  defp normalize_number(%Decimal{} = decimal), do: Decimal.to_integer(decimal)
  defp normalize_number(number) when is_integer(number), do: number
  defp normalize_number(number) when is_float(number), do: trunc(number)

  defp normalize_number(number) when is_binary(number) do
    case Integer.parse(number) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp normalize_number(_), do: 0
end
