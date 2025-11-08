# WS04 SSH Adapter – Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:writing-plans after this design is validated.

## Goal
Implement `NetAuto.Protocols.SSHAdapter.run/4` (and supporting behavior) that executes commands against network devices via Erlang `:ssh`, streams output through callbacks/PubSub, honors timeouts, and never logs secrets. The adapter must retrieve credentials via `NetAuto.Secrets` so future providers (Vault, AWS, Bitwarden) can plug in.

## Architecture
- Define behavior `NetAuto.Protocols.Adapter` with callback `run(device, command, opts, on_chunk)` returning `{:ok, %{exit_code: integer, bytes: non_neg_integer}} | {:error, reason}`.
- Implement `NetAuto.Protocols.SSHAdapter` using `:ssh.connect/4` + `:ssh_connection.exec/4`. Provide configurable options: `connect_timeout`, `cmd_timeout`, `port`, `preferred_auth`.
- Secrets dependency: call `NetAuto.Secrets.fetch(device.cred_ref)` to obtain `%Credential{username, password/private_key}`. Support password auth and key auth (PEM). Never log credentials; only log `cred_ref` + device hostname if needed.
- Streaming: Accept callback `on_chunk.(binary())` invoked for every `stdout/stderr` chunk. Adapter also returns total bytes + exit code for finalizing runs.
- Telemetry: emit `[:net_auto, :protocols, :ssh, :start|:chunk|:stop|:error]` events with metadata (device_id, hostname, cred_ref, bytes, exit_code) to satisfy observability.
- Error handling: Map `:ssh` errors to friendly atoms (`:auth_failed`, `:timeout`, `:connect_refused`, etc.). Provide exponential backoff for channel open? (YAGNI for now; single attempt per command is fine.)
- Timeout strategy: use `:ssh_option` `connect_timeout` for handshake; wrap `:ssh_connection.exec` in `Task.await` or monitoring to enforce command timeout; kill channel on expiry.

## Components
1. **Protocols behavior** (`lib/net_auto/protocols/adapter.ex`): defines callback + shared types.
2. **SSHAdapter module**: orchestrates connection lifecycle, channel exec, chunk streaming, telemetry.
3. **Supervisor integration**: Runner (WS05) will own process; adapter should be stateless/pure and not hold global state.
4. **Testing**: Use Mox to stub `:ssh` interactions. Provide integration-style tests using fakes? (Optional for now; unit tests with `:ssh` behaviour replaced by mock/ :ssh_mock ). Provide configuration flag `Application.get_env(:net_auto, NetAuto.Protocols.SSHAdapter, ...)` to inject `:ssh` module (allows tests to use stub).

## Telemetry Events (proposal)
- `[:net_auto, :protocols, :ssh, :start]` with metadata `%{device_id, hostname}`.
- `[:net_auto, :protocols, :ssh, :chunk]` measurement `%{bytes: byte_size(chunk)}`.
- `[:net_auto, :protocols, :ssh, :stop]` metadata `%{exit_code, bytes}`.
- `[:net_auto, :protocols, :ssh, :error]` metadata `%{reason}`.

## Open Questions
- Do we need host key verification now? Project plan mentions “production-safe defaults”; we should honor known_hosts via `:silently_accept_hosts false`, store host key in DB? For WS04, default to `silently_accept_hosts: false` but allow dev override in config.
- Should adapter support `enable` or multi-command sequences? Out of scope for WS04; single command streaming.

