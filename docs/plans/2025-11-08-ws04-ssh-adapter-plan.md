# WS04 SSH Adapter Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement an SSH protocol adapter that executes commands via Erlang `:ssh`, streams output through a callback, enforces timeouts, emits telemetry, and retrieves credentials through `NetAuto.Secrets` so other vault providers can plug in later.

**Architecture:** Introduce a `NetAuto.Protocols.Adapter` behaviour and `NetAuto.Protocols.SSHAdapter` module. The adapter remains stateless, accepts connection opts, calls `NetAuto.Secrets.fetch/2` to obtain username/password/keys, and streams results by invoking `on_chunk.(chunk)` while tracking byte counts. Telemetry events describe start/stop/error. Configuration allows swapping `:ssh` implementation for tests.

**Tech Stack:** Elixir 1.17, OTP `:ssh`, Telemetry, ExUnit/Mox.

---

### Task 1: Protocol behaviour + config plumbing

**Files:**
- Create: `lib/net_auto/protocols/adapter.ex`
- Modify: `mix.exs` (add `:ssh` to extra applications already done), `lib/net_auto/application.ex` only if needed (likely no change)
- Test: `test/net_auto/protocols/adapter_test.exs`

1. Define behaviour: `@callback run(device :: map(), command :: binary(), opts :: keyword(), (binary() -> any())) :: {:ok, %{exit_code: integer, bytes: integer}} | {:error, term}`.
2. Provide helper `defdelegate run(device, command, opts \\ [], on_chunk \\ &Function.identity/1)` that fetches adapter module via `Application.get_env(:net_auto, NetAuto.Protocols, adapter: NetAuto.Protocols.SSHAdapter)`.
3. Add simple test verifying config delegation (use stub adapter module) and telemetry placeholder (if behaviour emits). Keep this minimal.
4. Commit `git add lib/net_auto/protocols/adapter.ex test/net_auto/protocols/adapter_test.exs mix.exs && git commit -m "feat(ws04): add protocols adapter behaviour"`.

### Task 2: SSH adapter implementation

**Files:**
- Create: `lib/net_auto/protocols/ssh_adapter.ex`
- Create: `lib/net_auto/protocols/ssh_ex.ex` (wrapper around `:ssh` for dependency injection)
- Tests: `test/net_auto/protocols/ssh_adapter_test.exs`, `test/support/mocks/ssh_mock.ex` using Mox

Steps:
1. Build adapter module with `@behaviour NetAuto.Protocols.Adapter`. Public `run/4` takes `%Device{}` (or map), command, opts, on_chunk.
2. Resolve credentials: `with {:ok, cred} <- NetAuto.Secrets.fetch(device.cred_ref)` choose auth method (password vs private key). Support username override from `device.username` falling back to credential.
3. Connect using injectable module: `ssh().connect(host, port, connect_opts)` where `ssh()` reads `Application.get_env(:net_auto, NetAuto.Protocols.SSHAdapter, ssh: NetAuto.Protocols.SSHEx)`.
4. After connection, open channel, request exec, subscribe to `:ssh_connection` messages. Stream data by calling `on_chunk.(chunk)` and increment byte counter. Respect `cmd_timeout` by using `receive` with timeout; on timeout, close channel and return `{:error, :cmd_timeout}`.
5. Ensure cleanup: close channel/session in `after` block; handle errors gracefully.
6. Emit telemetry per start/chunk/stop/error using `:telemetry.execute`.
7. Tests: using Mox to stub ssh module, simulate success and error flows, ensure `on_chunk` receives data and bytes counted. Focus on unit-level mocking rather than hitting actual SSH.
8. `mix format && mix test test/net_auto/protocols/ssh_adapter_test.exs`.
9. Commit with `git add lib/net_auto/protocols/ssh_adapter.ex lib/net_auto/protocols/ssh_ex.ex test/... && git commit -m "feat(ws04): implement ssh adapter"`.

### Task 3: Integrate with automation runner + config

**Files:**
- Modify: `lib/net_auto/automation/run_server.ex` (or whichever runner exists) to call `NetAuto.Protocols.Adapter.run/4` instead of stub. Add callback to stream chunk to RunServer -> PubSub.
- Modify: `lib/net_auto/automation.ex` or contexts to wire telemetry (if needed).
- Update: `config/config.exs` for adapter-specific defaults (timeouts, ssh wrapper).
- Tests: extend automation/run_server tests with Mox to ensure `NetAuto.Protocols.Adapter` invoked.

Steps:
1. In RunServer `handle_continue` or equivalent, fetch device + command, call adapter with `fn chunk -> broadcast chunk; append run chunk` end.
2. On success, finalize run with exit code, bytes; on error, set status :error with reason.
3. Add tests verifying adapter invocation + chunk streaming using Mox for adapter behaviour.
4. Update documentation referencing new dependency (maybe `docs/secrets.md` mention adapter). Ensure `mix test` entire suite.
5. Commit: `git add lib/net_auto/automation/run_server.ex test/net_auto/automation/run_server_test.exs config/config.exs && git commit -m "feat(ws04): wire ssh adapter into runner"`.

### Task 4: Docs + telemetry reference

**Files:**
- Update `docs/secrets.md` (mention SSH adapter consumption), `README.md` (note SSH adapter + timeouts), `project.md` (checklist tick).
- Optionally add `docs/telemetry.md` entry for SSH events.

Steps:
1. Document Telemetry events and configuration knobs (timeouts, host key handling) in new `docs/telemetry.md#ssh-adapter` or existing doc.
2. README snippet describing default timeouts + how to override via config.
3. Run `mix format`, `mix test` final time.
4. Commit docs update.

