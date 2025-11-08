# Secrets Adapter Guide

`NetAuto.Secrets` resolves runtime credentials via adapters. For WS03 we ship the Env adapter, which reads OS variables and never persists plaintext secrets.

## Naming convention

Given `cred_ref` = `LAB_DEFAULT`, set any of the following variables before running the app:

| Purpose | Env var |
| --- | --- |
| Username (optional, defaults to DB `username`) | `NET_AUTO_LAB_DEFAULT_USERNAME` |
| Password | `NET_AUTO_LAB_DEFAULT_PASSWORD` |
| Private key (literal) | `NET_AUTO_LAB_DEFAULT_PRIVKEY` |
| Private key (Base64) | `NET_AUTO_LAB_DEFAULT_PRIVKEY_BASE64` |
| Key passphrase | `NET_AUTO_LAB_DEFAULT_PASSPHRASE` |

> Provide **either** `_PASSWORD` **or** `_PRIVKEY`/`_PRIVKEY_BASE64`. If both are missing, the adapter returns `{:error, :missing_secret}`.

Example (password-based):

```bash
export NET_AUTO_LAB_DEFAULT_USERNAME=netops
export NET_AUTO_LAB_DEFAULT_PASSWORD=changeme
```

Example (key-based using Base64):

```bash
export NET_AUTO_LAB_DEFAULT_PRIVKEY_BASE64="$(base64 -w0 ~/.ssh/id_rsa)"
export NET_AUTO_LAB_DEFAULT_PASSPHRASE="super secret"
```

## Telemetry

Every `NetAuto.Secrets.fetch/2` call emits:

```
Event: [:net_auto, :secrets, :fetch]
Measurements: %{duration: native_time}
Metadata: %{cred_ref: String.t(), result: :ok | :error}
```

Hook this event via `:telemetry.attach/4` to track secret lookup latency and failure rates.

## Extending

Adapters implement the `NetAuto.Secrets` behavior. Override via config:

```elixir
config :net_auto, NetAuto.Secrets, adapter: MyApp.Secrets.Vault
```

Ensure new adapters emit the same telemetry and never log secret contents.
