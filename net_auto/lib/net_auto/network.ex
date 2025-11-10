defmodule NetAuto.Network do
  @moduledoc """
  Boundary for executing commands against devices.

  The actual execution is delegated to the configured client module, which
  defaults to `NetAuto.Network.LocalRunner`. Later workstreams can provide a
  client that launches supervised runners without changing LiveView code.
  """

  alias NetAuto.Automation

  @type device_id :: pos_integer()

  defmodule Client do
    @moduledoc """
    Behaviour for network execution clients.
    """

    @callback execute_command(NetAuto.Network.device_id(), String.t(), map()) ::
                {:ok, Automation.Run.t()} | {:error, term()}
  end

  @allowed_attr_keys [:requested_by, :requested_at, :requested_for, :command_template_id]

  @doc """
  Execute `command` against the given `device_id` using the configured client.
  """
  @spec execute_command(device_id(), String.t(), map()) ::
          {:ok, Automation.Run.t()} | {:error, term()}
  def execute_command(device_id, command, attrs \\ %{})
      when is_integer(device_id) and device_id > 0 do
    client().execute_command(device_id, command, normalize_attrs(attrs))
  end

  defp client do
    Application.get_env(:net_auto, :network_client, NetAuto.Network.LocalRunner)
  end

  defp normalize_attrs(attrs) when is_map(attrs) do
    Enum.reduce(attrs, %{}, &maybe_put_normalized_attr/2)
  end

  defp normalize_attrs(_), do: %{}

  defp maybe_put_normalized_attr({key, value}, acc) when is_atom(key) do
    if key in @allowed_attr_keys, do: Map.put(acc, key, value), else: acc
  end

  defp maybe_put_normalized_attr({key, value}, acc) when is_binary(key) do
    case normalize_binary_key(key) do
      nil -> acc
      atom_key -> Map.put(acc, atom_key, value)
    end
  end

  defp maybe_put_normalized_attr(_entry, acc), do: acc

  defp normalize_binary_key("requested_by"), do: :requested_by
  defp normalize_binary_key("requested_at"), do: :requested_at
  defp normalize_binary_key("requested_for"), do: :requested_for
  defp normalize_binary_key("command_template_id"), do: :command_template_id
  defp normalize_binary_key(_), do: nil

  defmodule LocalRunner do
    @moduledoc """
    Default client that records a pending run without executing any protocol.

    This keeps WS08 aligned with the eventual RunServer implementation by
    returning the inserted `NetAuto.Automation.Run` record.
    """

    @behaviour NetAuto.Network.Client

    alias NetAuto.Automation

    @impl true
    def execute_command(device_id, command, attrs \\ %{}) do
      start_time = System.monotonic_time()
      telemetry_metadata = runner_metadata(device_id, attrs)

      :telemetry.execute([:net_auto, :runner, :start], %{count: 1}, telemetry_metadata)

      result =
        attrs
        |> Map.put(:command, String.trim(command))
        |> Map.put(:device_id, device_id)
        |> Map.put(:status, :pending)
        |> Map.put_new(:requested_at, DateTime.utc_now() |> DateTime.truncate(:second))
        |> Automation.create_run()

      case result do
        {:ok, run} ->
          duration = System.monotonic_time() - start_time

          measurements = %{
            duration_ms: System.convert_time_unit(duration, :native, :millisecond),
            bytes: run.bytes || 0,
            count: 1
          }

          :telemetry.execute(
            [:net_auto, :runner, :stop],
            measurements,
            Map.put(telemetry_metadata, :run_id, run.id)
          )

          {:ok, run}

        {:error, reason} = error ->
          metadata = Map.put(telemetry_metadata, :reason, reason)
          :telemetry.execute([:net_auto, :runner, :error], %{count: 1}, metadata)
          error
      end
    end

    defp runner_metadata(device_id, attrs) do
      %{
        device_id: device_id,
        requested_by: Map.get(attrs, :requested_by),
        source: :local_runner
      }
    end
  end
end
