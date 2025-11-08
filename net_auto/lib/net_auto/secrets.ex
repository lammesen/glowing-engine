defmodule NetAuto.Secrets do
  @moduledoc """
  Secrets facade; delegates to configured adapter (Env by default).
  """

  alias NetAuto.Secrets.Credential

  @callback fetch(String.t(), keyword()) :: {:ok, Credential.t()} | {:error, term()}

  def fetch(cred_ref, opts \\ []) when is_binary(cred_ref) do
    adapter = adapter()
    start = System.monotonic_time()

    case adapter.fetch(cred_ref, opts) do
      {:ok, _credential} = result ->
        emit_telemetry(start, cred_ref, :ok)
        result

      {:error, reason} = result ->
        emit_telemetry(start, cred_ref, {:error, reason})
        result
    end
  end

  defp adapter do
    Application.get_env(:net_auto, __MODULE__, adapter: NetAuto.Secrets.Dummy)
    |> Keyword.fetch!(:adapter)
  end

  defp emit_telemetry(start, cred_ref, result) do
    duration = System.monotonic_time() - start
    metadata = %{cred_ref: cred_ref, result: normalize_result(result)}

    :telemetry.execute([:net_auto, :secrets, :fetch], %{duration: duration}, metadata)
  end

  defp normalize_result(:ok), do: :ok
  defp normalize_result({:error, _}), do: :error
  defp normalize_result(_), do: :unknown
end
