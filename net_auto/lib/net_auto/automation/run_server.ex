defmodule NetAuto.Automation.RunServer do
  @moduledoc """
  GenServer responsible for executing a single automation run.

  It coordinates with the protocol adapter, persists streamed chunks, updates
  the run record, and releases any reserved quota when finished.
  """

  use GenServer, restart: :temporary

  alias NetAuto.Automation
  alias NetAuto.Automation.QuotaServer

  @type option ::
          {:run, Automation.Run.t()}
          | {:device, NetAuto.Inventory.Device.t()}
          | {:adapter, module()}
          | {:command, String.t()}
          | {:adapter_opts, map()}
          | {:quota_server, atom() | pid()}
          | {:reservation, reference()}
          | {:site, String.t()}

  @default_quota_server NetAuto.Automation.QuotaServer

  def child_spec(opts) do
    run = Keyword.fetch!(opts, :run)

    %{
      id: {__MODULE__, run.id},
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary,
      shutdown: 5_000
    }
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    run = Keyword.fetch!(opts, :run)
    device = Keyword.fetch!(opts, :device)
    adapter = Keyword.fetch!(opts, :adapter)
    command = Keyword.get(opts, :command, run.command)
    adapter_opts = Keyword.get(opts, :adapter_opts, %{})
    site = Keyword.get(opts, :site, device.site)
    reservation = Keyword.get(opts, :reservation)
    quota_server = Keyword.get(opts, :quota_server, @default_quota_server)

    {:ok, run} =
      Automation.update_run(run, %{
        status: :running,
        started_at: DateTime.utc_now()
      })

    parent = self()

    {:ok, adapter_pid} =
      Task.start(fn ->
        chunk_cb = fn data -> send(parent, {:adapter_chunk, data}) end
        result = safe_run_adapter(adapter, device, command, adapter_opts, chunk_cb)
        send(parent, {:adapter_result, self(), result})
      end)

    adapter_ref = Process.monitor(adapter_pid)

    state = %{
      run: run,
      device: device,
      command: command,
      adapter: adapter,
      adapter_opts: adapter_opts,
      adapter_pid: adapter_pid,
      adapter_ref: adapter_ref,
      reservation: reservation,
      quota_server: quota_server,
      site: site,
      seq: 0,
      bytes: 0,
      finished: false
    }

    {:ok, state}
  end

  @impl true
  def handle_info({:adapter_chunk, data}, state) do
    case Automation.append_chunk(%{run_id: state.run.id, seq: state.seq, data: data}) do
      {:ok, _chunk} ->
        new_state = %{
          state
          | seq: state.seq + 1,
            bytes: state.bytes + byte_size(data)
        }

        {:noreply, new_state}

      {:error, reason} ->
        state = shutdown_adapter(state)
        finish({:error, {:chunk_store_failed, reason}}, state)
    end
  end

  def handle_info({:adapter_result, pid, result}, state) when pid == state.adapter_pid do
    state = demonitor_adapter(state)
    finish(result, state)
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{adapter_ref: ref} = state) do
    state = %{state | adapter_ref: nil, adapter_pid: nil}
    finish({:error, reason}, state)
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp safe_run_adapter(adapter, device, command, adapter_opts, chunk_cb) do
    adapter.run(device, command, adapter_opts, chunk_cb)
  rescue
    exception ->
      {:error, exception}
  catch
    kind, reason ->
      {:error, {kind, reason}}
  end

  defp finish(_result, %{finished: true} = state), do: {:stop, :normal, state}

  defp finish(result, state) do
    state = complete_run(result, state)
    {:stop, :normal, state}
  end

  defp complete_run(result, state) do
    updates =
      case result do
        {:ok, exit_code, _bytes} ->
          %{status: :ok, exit_code: exit_code}

        {:error, reason} ->
          %{status: :error, error_reason: format_reason(reason)}
      end
      |> Map.merge(%{
        bytes: state.bytes,
        finished_at: DateTime.utc_now()
      })

    {:ok, run} = Automation.update_run(state.run, updates)
    state = release_quota(state)

    %{state | run: run, finished: true}
  end

  defp release_quota(%{reservation: nil} = state), do: state

  defp release_quota(%{reservation: reservation, quota_server: quota_server} = state) do
    try do
      QuotaServer.check_in(quota_server, reservation)
    rescue
      _ -> :ok
    end

    %{state | reservation: nil}
  end

  defp demonitor_adapter(%{adapter_ref: nil} = state), do: %{state | adapter_pid: nil}

  defp demonitor_adapter(%{adapter_ref: ref} = state) do
    Process.demonitor(ref, [:flush])
    %{state | adapter_ref: nil, adapter_pid: nil}
  end

  defp shutdown_adapter(%{adapter_pid: nil} = state), do: state

  defp shutdown_adapter(%{adapter_pid: pid} = state) do
    Process.exit(pid, :shutdown)
    demonitor_adapter(state)
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_reason(%{__struct__: _} = reason), do: inspect(reason)
  defp format_reason(reason), do: inspect(reason)
end
