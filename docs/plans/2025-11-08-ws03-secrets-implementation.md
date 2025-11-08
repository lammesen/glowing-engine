# WS03 Secrets Adapter Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Provide a secrets behavior plus ENV adapter so callers can fetch credentials at runtime using `cred_ref`, never storing secrets in the DB.

**Architecture:** Define a Secrets behavior, Credential struct, and Env adapter that reads OS env vars `NET_AUTO_<REF>_*`. Add config to wire adapter, telemetry hooks, and tests for success/error paths. Inventory/Automation will inject the Secrets module later.

**Tech Stack:** Elixir 1.17, Ecto (already present), ExUnit, Telemetry.

---

### Task 1: Create Secrets behavior + credential struct

**Files:**
- Create: `lib/net_auto/secrets.ex`
- Create: `lib/net_auto/secrets/credential.ex`
- Test: `test/net_auto/secrets_test.exs`

1. Define `NetAuto.Secrets` module with `@callback fetch(binary(), keyword()) :: {:ok, Credential.t()} | {:error, term}`. Provide `fetch/2` public function that delegates to `adapter().fetch(ref, opts)` using `Application.compile_env(:net_auto, NetAuto.Secrets, adapter: NetAuto.Secrets.Dummy)`.
2. Implement `NetAuto.Secrets.Credential` struct with fields: `:cred_ref`, `:username`, `:password`, `:private_key`, `:passphrase`, `:metadata` (map), `:inserted_at` optional for auditing.
3. Add helper `defstruct` and type spec `@type t :: %Credential{...}`.
4. Write initial tests covering behavior: when adapter returns {:ok, ...} the wrapper returns same; when missing config, ensure default adapter (Dummy) is used and returns {:error, :not_configured}.
5. Commit: `git add lib/net_auto/secrets* test/net_auto/secrets_test.exs && git commit -m "feat(ws03): scaffold secrets behavior"`.

### Task 2: Implement Env adapter

**Files:**
- Create: `lib/net_auto/secrets/env.ex`
- Test: extend `test/net_auto/secrets_test.exs`

1. `NetAuto.Secrets.Env.fetch(cred_ref, opts \ [])` should normalize reference: `ref |> String.upcase() |> String.replace(~r/[^A-Z0-9]/, "_")` then build base key `"NET_AUTO_#{normalized}"`.
2. Read env vars using `System.get_env`: `USERNAME`, `PASSWORD`, `PRIVKEY`, `PRIVKEY_BASE64`, `PASSPHRASE`. Support key contents either inline or base64: if `PRIVKEY_BASE64` present decode via `Base.decode64!`.
3. Return `{:error, {:not_found, :username}}` if username missing? (Doc states DB stores username; but for safety, allow missing username). At minimum require at least password or privkey; otherwise return `{:error, :missing_secret}`.
4. Build `%Credential{cred_ref: ref, username: opts[:username_override] || System.get_env(key <> "_USERNAME"), password: pw, private_key: pk, passphrase: pass, metadata: %{source: :env}}`.
5. No secrets in logs; only debug log `Logger.debug("secrets env fetch ok", cred_ref: cred_ref)`.
6. Extend tests: use `System.put_env/2` to set dummy values; assert fetch returns struct; ensure encoded private key handled; ensure missing env returns error atoms.
7. Commit: `git add lib/net_auto/secrets/env.ex test/net_auto/secrets_test.exs && git commit -m "feat(ws03): env secrets adapter"`.

### Task 3: Wire adapter config + telemetry + docs

**Files:**
- Modify: `config/config.exs` add `config :net_auto, NetAuto.Secrets, adapter: NetAuto.Secrets.Env`
- Modify: `lib/net_auto/secrets.ex` to wrap `fetch/2` with telemetry measurement (`System.monotonic_time`)
- Update: `.env.sample` with sample keys (`NET_AUTO_LAB_DEFAULT_USERNAME`, `_PASSWORD`...)
- Update: `README.md` (+ `net_auto/README.md`) describing env var format and sample command.

1. Add telemetry call `:telemetry.execute([:net_auto, :secrets, :fetch], %{duration: native_diff}, %{cred_ref: cred_ref, result: :ok | :error})` around adapter call.
2. Update `.env.sample` to include documented placeholders (no secrets) for at least one `cred_ref`.
3. Document process in README: “Set NET_AUTO_<REF>_PASSWORD/PRIVKEY before running runner”.
4. `mix format` and `PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH" mix test` (ensures secrets tests run; DB not strictly needed but tests may hit Repo due to DataCase).
5. Commit: `git add config/config.exs lib/net_auto/secrets.ex .env.sample README.md net_auto/README.md && git commit -m "chore(ws03): wire secrets adapter"`.

### Task 4: Integration touchpoints + dev ergonomics

**Files:**
- Modify: `net_auto/lib/net_auto/automation/run.ex` (optional) or contexts once they use secrets – for now, add utility `NetAuto.Inventory` doc note referencing secrets usage.
- Add docs under `docs/secrets.md` summarizing env variable naming and Telemetry event.

1. Create `docs/secrets.md` with table mapping `cred_ref` to env vars, commands to export them, and mention telemetry event.
2. Cross-link in root README and `project.md` (if necessary) referencing the doc.
3. `mix test` (ensures doc addition doesn’t break due to doctests; none expected).
4. Commit: `git add docs/secrets.md README.md project.md && git commit -m "docs(ws03): document secrets env"`.

