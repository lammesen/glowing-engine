# WS03 Secrets Adapter – Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:writing-plans after this design is approved.

**Goal:** Resolve credentials at runtime via env variables so DB rows only store `cred_ref`. Provide a behavior + Env adapter other workstreams can depend on, with typed structs, telemetry, and tests.

**Architecture:**
- `NetAuto.Secrets` behavior defines `@callback fetch(cred_ref, opts) :: {:ok, Credential.t()} | {:error, term}`.
- `NetAuto.Secrets.Credential` struct holds user-facing fields (username optional, password, private_key, passphrase, metadata). No secrets stored in DB; only resolved on demand.
- Env adapter builds keys like `NET_AUTO_<REF>_USERNAME`, `_PASSWORD`, `_PRIVKEY`, `_PRIVKEY_BASE64`, `_PASSPHRASE`. Supports password-only, key-only, or both.
- Configuration via `config :net_auto, NetAuto.Secrets, adapter: NetAuto.Secrets.Env` with fallback `NetAuto.Secrets.Dummy` (returns error) for tests.
- Telemetry event `[:net_auto, :secrets, :fetch]` with measurements `%{duration: native_time}` and metadata `%{cred_ref, result: :ok | :error}`.

**Key flows:**
1. Inventory/Automation calls `NetAuto.Secrets.fetch("LAB_DEFAULT")`.
2. Secrets module delegates to adapter module from config.
3. Env adapter normalizes `cred_ref` to uppercase slug, fetches env vars, builds struct or returns descriptive error.
4. Caller uses struct to connect via SSH; errors bubble up with safe messages.

**Security requirements:** never log secrets; ensure env var names documented in `.env.sample`; add tests verifying missing envs produce {:error, :not_found}.

**Open questions:** None – strictly Env adapter per plan.

