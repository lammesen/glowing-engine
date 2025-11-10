defmodule NetAuto.Protocols.SSHAdapter do
  @moduledoc "Executes commands over SSH using Erlang's :ssh client."
  @behaviour NetAuto.Protocols.Adapter

  require Logger

  alias NetAuto.Inventory.Device
  alias NetAuto.Secrets
  alias NetAuto.Secrets.Credential

  @default_port 22
  @default_connect_timeout 5_000
  @default_cmd_timeout 30_000

  @impl true
  def run(%Device{} = device, command, opts \\ [], on_chunk \\ &Function.identity/1) do
    metadata = telemetry_metadata(device)
    emit(:start, %{}, metadata)

    with {:ok, credential} <- Secrets.fetch(device.cred_ref),
         {:ok, host} <- resolve_host(device),
         {:ok, connect_opts, cleanup} <- build_connect_opts(device, credential, opts) do
      connect_and_exec(host, device, command, connect_opts, cleanup, opts, on_chunk, metadata)
    else
      {:error, reason} ->
        emit(:error, %{}, Map.put(metadata, :reason, reason))
        {:error, reason}
    end
  end

  defp connect_and_exec(host, device, command, connect_opts, cleanup, opts, on_chunk, metadata) do
    case ssh().connect(host, port(device, opts), connect_opts) do
      {:ok, conn} ->
        try do
          result = exec(conn, command, opts, on_chunk, metadata)
          handle_result(result, metadata)
        after
          ssh().close(conn)
          cleanup.()
        end

      {:error, reason} ->
        cleanup.()
        emit(:error, %{}, Map.put(metadata, :reason, reason))
        {:error, reason}
    end
  end

  defp exec(conn, command, opts, on_chunk, metadata) do
    timeout = Keyword.get(opts, :cmd_timeout, @default_cmd_timeout)

    with {:ok, channel_id} <- ssh().session_channel_open(conn, timeout) do
      case ssh().exec(conn, channel_id, String.to_charlist(command), timeout) do
        result when result in [:ok, :success] ->
          try do
            loop(conn, channel_id, on_chunk, %{bytes: 0, exit_code: nil}, timeout, metadata)
          after
            ssh().close_channel(conn, channel_id)
          end

        {:error, reason} ->
          {:error, reason}

        {:failure, reason} ->
          {:error, reason}
      end
    end
  end

  defp loop(conn, channel_id, on_chunk, state, timeout, metadata) do
    receive do
      {:ssh_cm, ^conn, {:data, ^channel_id, _type, data}} ->
        on_chunk.(data)
        chunk_bytes = byte_size(data)
        emit(:chunk, %{bytes: chunk_bytes}, metadata)

        loop(
          conn,
          channel_id,
          on_chunk,
          %{state | bytes: state.bytes + chunk_bytes},
          timeout,
          metadata
        )

      {:ssh_cm, ^conn, {:exit_status, ^channel_id, status}} ->
        loop(conn, channel_id, on_chunk, %{state | exit_code: status}, timeout, metadata)

      {:ssh_cm, ^conn, {:exit_signal, ^channel_id, signal, _, _}} ->
        {:error, {:exit_signal, signal}}

      {:ssh_cm, ^conn, {:closed, ^channel_id}} ->
        {:ok, state.exit_code || 0, state.bytes}

      {:ssh_cm, ^conn, {:channel_close, ^channel_id}} ->
        {:ok, state.exit_code || 0, state.bytes}

      _ ->
        loop(conn, channel_id, on_chunk, state, timeout, metadata)
    after
      timeout -> {:error, :cmd_timeout}
    end
  end

  defp build_connect_opts(device, %Credential{} = credential, opts) do
    username = credential.username || device.username

    if is_nil(username) do
      {:error, :missing_username}
    else
      base =
        [
          user: to_charlist(username),
          user_interaction: false,
          connect_timeout: Keyword.get(opts, :connect_timeout, @default_connect_timeout),
          silently_accept_hosts: Keyword.get(opts, :silently_accept_hosts, false)
        ]
        |> maybe_put(:password, credential.password && to_charlist(credential.password))

      maybe_add_identity(base, credential.private_key)
    end
  end

  defp maybe_add_identity(opts, nil), do: {:ok, opts, fn -> :ok end}

  defp maybe_add_identity(opts, private_key) do
    dir = temp_dir()
    key_path = Path.join(dir, "id_rsa")
    File.mkdir_p!(dir)
    File.write!(key_path, private_key)
    File.chmod(key_path, 0o600)

    opts =
      opts
      |> Keyword.put(:identity, String.to_charlist(key_path))
      |> Keyword.put_new(:user_dir, String.to_charlist(dir))

    {:ok, opts, fn -> File.rm_rf(dir) end}
  end

  defp temp_dir do
    Path.join(System.tmp_dir!(), "net_auto_ssh_#{System.unique_integer([:positive])}")
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp resolve_host(%Device{ip: ip}) when is_binary(ip), do: {:ok, String.to_charlist(ip)}

  defp resolve_host(%Device{hostname: host}) when is_binary(host),
    do: {:ok, String.to_charlist(host)}

  defp resolve_host(_), do: {:error, :missing_host}

  defp port(%Device{port: nil}, opts), do: Keyword.get(opts, :port, @default_port)
  defp port(%Device{port: port}, opts), do: Keyword.get(opts, :port, port)

  defp handle_result({:ok, exit_code, bytes} = result, metadata) do
    emit(:stop, %{bytes: bytes}, Map.put(metadata, :exit_code, exit_code))
    result
  end

  defp handle_result({:error, reason} = error, metadata) do
    emit(:error, %{}, Map.put(metadata, :reason, reason))
    error
  end

  defp telemetry_metadata(device) do
    %{
      device_id: device.id,
      hostname: device.hostname,
      cred_ref: device.cred_ref
    }
  end

  defp emit(event, measurements, metadata) do
    :telemetry.execute([:net_auto, :protocols, :ssh, event], measurements, metadata)
  end

  defp ssh do
    Application.get_env(:net_auto, __MODULE__, ssh: NetAuto.Protocols.SSHEx)
    |> Keyword.fetch!(:ssh)
  end
end
