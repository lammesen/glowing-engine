defmodule NetAuto.Secrets.Env do
  @moduledoc """
  Fetches credentials from OS environment variables.

  Expected keys per `cred_ref`:
  - `NET_AUTO_<REF>_USERNAME`
  - `NET_AUTO_<REF>_PASSWORD`
  - `NET_AUTO_<REF>_PRIVKEY`
  - `NET_AUTO_<REF>_PRIVKEY_BASE64`
  - `NET_AUTO_<REF>_PASSPHRASE`
  """

  @behaviour NetAuto.Secrets

  alias NetAuto.Secrets.Credential

  @impl true
  def fetch(cred_ref, opts \\ []) when is_binary(cred_ref) do
    prefix = Keyword.get(opts, :prefix, "NET_AUTO")
    slug = normalize(cred_ref)
    key = prefix <> "_" <> slug

    username = Keyword.get(opts, :username) || env(key <> "_USERNAME")
    password = env(key <> "_PASSWORD")
    passphrase = env(key <> "_PASSPHRASE")
    private_key = resolve_private_key(key)

    credentials_present? = Enum.any?([password, private_key], &(&1 && &1 != ""))

    if credentials_present? do
      credential = %Credential{
        cred_ref: cred_ref,
        username: username,
        password: password,
        private_key: private_key,
        passphrase: passphrase,
        metadata: %{source: :env}
      }

      {:ok, credential}
    else
      {:error, :missing_secret}
    end
  end

  defp env(name) do
    case System.get_env(name) do
      nil -> nil
      value when value == "" -> nil
      value -> value
    end
  end

  defp normalize(ref) do
    ref
    |> String.upcase()
    |> String.replace(~r/[^A-Z0-9]/, "_")
  end

  defp resolve_private_key(base_key) do
    case {env(base_key <> "_PRIVKEY"), env(base_key <> "_PRIVKEY_BASE64")} do
      {key, nil} when is_binary(key) ->
        key

      {nil, encoded} when is_binary(encoded) ->
        case Base.decode64(encoded) do
          {:ok, decoded} -> decoded
          :error -> nil
        end

      {key, _encoded} when is_binary(key) ->
        key

      _ ->
        nil
    end
  end
end
