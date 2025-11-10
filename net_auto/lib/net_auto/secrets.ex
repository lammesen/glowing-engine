defmodule NetAuto.Secrets do
  @moduledoc """
  Secrets facade; delegates to configured adapter (Env by default).
  """

  alias NetAuto.Secrets.Credential

  @callback fetch(String.t(), keyword()) :: {:ok, Credential.t()} | {:error, term()}

  def fetch(cred_ref, opts \\ []) when is_binary(cred_ref) do
    {adapter, normalized_ref} = adapter_for(cred_ref)
    start = System.monotonic_time()

    case adapter.fetch(normalized_ref, opts) do
      {:ok, _credential} = result ->
        emit_telemetry(start, cred_ref, result)
        result

      {:error, _reason} = result ->
        emit_telemetry(start, cred_ref, result)
        result
    end
  end

  defp adapter_for(cred_ref) do
    config = Application.get_env(:net_auto, __MODULE__, [])
    default = Keyword.get(config, :adapter, NetAuto.Secrets.Dummy)
    adapters = adapters_map(Keyword.get(config, :adapters, []))

    case split_prefix(cred_ref) do
      {prefix, rest} ->
        case Map.get(adapters, prefix) do
          nil -> {default, cred_ref}
          module -> {module, rest}
        end

      :default ->
        {default, cred_ref}
    end
  end

  defp adapters_map(list) do
    Enum.into(list, %{}, fn
      {key, module} when is_atom(key) -> {Atom.to_string(key), module}
      {key, module} when is_binary(key) -> {key, module}
    end)
  end

  defp split_prefix(ref) do
    case String.split(ref, ":", parts: 2) do
      [prefix, rest] when rest != "" -> {prefix, rest}
      _ -> :default
    end
  end

  defp emit_telemetry(start, cred_ref, result) do
    duration = System.monotonic_time() - start
    metadata = %{cred_ref: cred_ref, result: normalize_result(result)}

    :telemetry.execute([:net_auto, :secrets, :fetch], %{duration: duration}, metadata)
  end

  defp normalize_result(:ok), do: :ok
  defp normalize_result(:error), do: :error
  defp normalize_result({:ok, _}), do: :ok
  defp normalize_result({:error, _}), do: :error
  defp normalize_result(_), do: :unknown
end
