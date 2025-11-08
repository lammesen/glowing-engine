defmodule NetAuto.Protocols.SSHClient do
  @moduledoc false

  @callback connect(charlist(), :inet.port_number(), keyword()) ::
              {:ok, term()} | {:error, term()}

  @callback close(term()) :: :ok | {:error, term()}

  @callback session_channel_open(term(), timeout :: integer()) ::
              {:ok, term()} | {:error, term()}

  @callback exec(term(), term(), iodata(), timeout :: integer()) :: :ok | {:error, term()}

  @callback close_channel(term(), term()) :: :ok | {:error, term()}
end
