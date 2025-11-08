defmodule NetAuto.SecretsTest do
  use ExUnit.Case, async: true

  alias NetAuto.Secrets
  alias NetAuto.Secrets.Credential
  alias NetAuto.Secrets.Env

  defmodule StubAdapter do
    @behaviour NetAuto.Secrets

    @impl true
    def fetch(_cred_ref, _opts), do: {:ok, %Credential{cred_ref: "TEST", password: "secret"}}
  end

  defmodule VaultAdapter do
    @behaviour NetAuto.Secrets

    @impl true
    def fetch("path/to/secret", _opts), do: {:ok, %Credential{cred_ref: "vault", password: "vault-secret"}}
  end

  setup do
    original = Application.get_env(:net_auto, NetAuto.Secrets)
    Application.put_env(:net_auto, NetAuto.Secrets, adapter: StubAdapter)

    on_exit(fn -> Application.put_env(:net_auto, NetAuto.Secrets, original) end)
  end

  test "fetch/2 delegates to configured adapter" do
    assert {:ok, %Credential{cred_ref: "TEST", password: "secret"}} = Secrets.fetch("TEST")
  end

  test "telemetry fires" do
    :telemetry.attach_many(
      "secrets-test",
      [[:net_auto, :secrets, :fetch]],
      fn event, measurements, metadata, pid ->
        send(pid, {:telemetry, event, measurements, metadata})
      end,
      self()
    )

    Secrets.fetch("TEST")

    assert_receive {:telemetry, [:net_auto, :secrets, :fetch], %{duration: _},
                    %{cred_ref: "TEST", result: :ok}}

    :telemetry.detach("secrets-test")
  end

  describe "Env adapter" do
    setup do
      keys = [
        "NET_AUTO_LAB_DEFAULT_USERNAME",
        "NET_AUTO_LAB_DEFAULT_PASSWORD",
        "NET_AUTO_LAB_DEFAULT_PRIVKEY",
        "NET_AUTO_LAB_DEFAULT_PRIVKEY_BASE64",
        "NET_AUTO_LAB_DEFAULT_PASSPHRASE"
      ]

      snapshot =
        Enum.map(keys, fn key ->
          {key, System.get_env(key)}
        end)

      on_exit(fn ->
        Enum.each(snapshot, fn
          {key, nil} -> System.delete_env(key)
          {key, value} -> System.put_env(key, value)
        end)
      end)

      Enum.each(keys, &System.delete_env/1)
      :ok
    end

    test "fetch/2 returns password credentials" do
      System.put_env("NET_AUTO_LAB_DEFAULT_PASSWORD", "hunter2")

      assert {:ok, %Credential{password: "hunter2", private_key: nil}} = Env.fetch("lab-default")
    end

    test "fetch/2 decodes base64 private key" do
      key = "----BEGIN KEY----\nabc123"
      System.put_env("NET_AUTO_LAB_DEFAULT_PRIVKEY_BASE64", Base.encode64(key))

      assert {:ok, %Credential{private_key: ^key}} = Env.fetch("Lab Default")
    end

    test "fetch/2 errors when neither password nor key present" do
      assert {:error, :missing_secret} = Env.fetch("missing")
    end
  end

  test "prefixed adapters route to configured module" do
    Application.put_env(:net_auto, NetAuto.Secrets,
      adapter: StubAdapter,
      adapters: [{"vault", VaultAdapter}, {:env, StubAdapter}]
    )

    assert {:ok, %Credential{password: "vault-secret"}} = Secrets.fetch("vault:path/to/secret")
    assert {:ok, %Credential{password: "secret"}} = Secrets.fetch("env:TEST")
    assert {:ok, %Credential{password: "secret"}} = Secrets.fetch("TEST")
  end
end
