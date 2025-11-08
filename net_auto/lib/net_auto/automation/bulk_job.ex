defmodule NetAuto.Automation.BulkJob do
  @moduledoc """
  Oban worker that fans out a command to multiple devices.
  """

  use Oban.Worker, queue: :bulk, max_attempts: 3

  alias Ecto.UUID
  alias NetAuto.Network
  alias Phoenix.PubSub

  @impl true
  def perform(%Oban.Job{args: %{"device_ids" => device_ids, "command" => command} = args}) do
    bulk_ref = Map.get(args, "bulk_ref", UUID.generate())
    attrs = build_command_attrs(args)

    summary =
      Enum.reduce(device_ids, %{ok: 0, error: 0}, fn device_id, acc ->
        case Network.execute_command(device_id, command, attrs) do
          {:ok, run} ->
            emit_device(:ok, bulk_ref, device_id)
            broadcast_progress(bulk_ref, device_id, :ok, run.id, nil)
            %{acc | ok: acc.ok + 1}

          {:error, reason} ->
            emit_device(:error, bulk_ref, device_id, reason)
            broadcast_progress(bulk_ref, device_id, :error, nil, format_reason(reason))
            %{acc | error: acc.error + 1}
        end
      end)

    broadcast_summary(bulk_ref, summary)
    emit_summary(bulk_ref, summary)
    :ok
  end

  defp build_command_attrs(args) do
    %{}
    |> maybe_put_attr(:requested_by, Map.get(args, "requested_by"))
    |> maybe_put_attr(:requested_for, Map.get(args, "requested_for"))
    |> maybe_put_attr(:command_template_id, Map.get(args, "command_template_id"))
  end

  defp maybe_put_attr(map, _key, nil), do: map
  defp maybe_put_attr(map, key, value), do: Map.put(map, key, value)

  defp bulk_topic(bulk_ref), do: "bulk:#{bulk_ref}"

  defp broadcast_progress(bulk_ref, device_id, status, run_id, error) do
    payload = %{
      bulk_ref: bulk_ref,
      device_id: device_id,
      run_id: run_id,
      status: status,
      error: error
    }

    PubSub.broadcast(NetAuto.PubSub, bulk_topic(bulk_ref), {:bulk_progress, payload})
  end

  defp broadcast_summary(bulk_ref, %{ok: ok, error: error}) do
    payload = %{bulk_ref: bulk_ref, ok: ok, error: error}
    PubSub.broadcast(NetAuto.PubSub, bulk_topic(bulk_ref), {:bulk_summary, payload})
  end

  defp emit_device(status, bulk_ref, device_id, reason \\ nil) do
    metadata =
      %{
        bulk_ref: bulk_ref,
        device_id: device_id,
        status: status
      }
      |> maybe_put_attr(:reason, reason)

    :telemetry.execute([:net_auto, :bulk, :device], %{count: 1}, metadata)
  end

  defp emit_summary(bulk_ref, %{ok: ok, error: error}) do
    measurements = %{ok: ok, error: error}
    metadata = %{bulk_ref: bulk_ref}
    :telemetry.execute([:net_auto, :bulk, :summary], measurements, metadata)
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_reason({:error, inner}), do: format_reason(inner)
  defp format_reason(%{__struct__: _} = struct), do: inspect(struct)
  defp format_reason(other), do: inspect(other)
end
