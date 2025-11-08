defmodule NetAuto.Protocols.SSHEx do
  @moduledoc false
  @behaviour NetAuto.Protocols.SSHClient

  @impl true
  def connect(host, port, opts), do: :ssh.connect(host, port, opts)

  @impl true
  def close(conn), do: :ssh.close(conn)

  @impl true
  def session_channel_open(conn, timeout), do: :ssh_connection.session_channel(conn, timeout)

  @impl true
  def exec(conn, channel_id, command, timeout) do
    :ssh_connection.exec(conn, channel_id, command, timeout)
  end

  @impl true
  def close_channel(conn, channel_id), do: :ssh_connection.close(conn, channel_id)
end
