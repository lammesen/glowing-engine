# WS09 Observability Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Wire PromEx dashboards and telemetry so we capture runner lifecycle, LiveView performance, and command throughput with bundled Grafana JSON.

**Architecture:** Add a `NetAuto.PromEx` module configuring PromEx plugins + custom metrics, emit missing Telemetry events in automation/runner code, and commit generated dashboards under `lib/net_auto/prom_ex/dashboards/`. PromEx supervises under the application tree and pushes dashboards to Grafana when configured.

**Tech Stack:** Elixir 1.17, PromEx 1.10, Telemetry, Phoenix LiveView 1.1, Grafana JSON dashboards.

---

### Task 1: Scaffold PromEx module & supervision

**Files:**
- Create: `net_auto/lib/net_auto/prom_ex.ex`
- Modify: `net_auto/lib/net_auto/application.ex`
- Modify: `net_auto/config/config.exs`
- Modify: `net_auto/config/runtime.exs`
- Test: `net_auto/test/net_auto/prom_ex_test.exs`

1. Write failing test ensuring `NetAuto.PromEx` defines `plugins/1` and `dashboards/0`.
2. Run `mix test test/net_auto/prom_ex_test.exs` → expect undefined module failure.
3. Implement `NetAuto.PromEx` using `use PromEx, otp_app: :net_auto`, include `PromEx.Plugins.{Phoenix, Ecto, Oban, PhoenixLiveView}` and stubs for custom plugin `NetAuto.PromEx.ObservabilityPlugin`.
4. Register PromEx in `NetAuto.Application` children with `prom_ex_args = [[grafana: [host: {:system, "PROMEX_GRAFANA_URL"}, auth_token: {:system, "PROMEX_GRAFANA_API_KEY"}, upload_dashboards_on_start: true]]]`.
5. Add base config in `config/config.exs` (`config :net_auto, NetAuto.PromEx, grafana: [host: nil, auth_token: nil, upload_dashboards_on_start: false]`). In `runtime.exs`, override from env vars.
6. Re-run tests; ensure compilation and config work.

### Task 2: Emit telemetry for runner lifecycle & commands

**Files:**
- Modify: `net_auto/lib/net_auto/automation.ex`
- Modify: `net_auto/lib/net_auto/automation/run.ex` (if needed)
- Modify: `net_auto/lib/net_auto/network.ex`
- Modify: `net_auto/lib/net_auto/automation/run_server.ex` (if exists; otherwise add placeholder module)
- Tests: `net_auto/test/net_auto/automation_test.exs`, `net_auto/test/net_auto/network_test.exs`

1. Add Telemetry events: `[:net_auto, :runner, :start]`, `:stop`, `:error` inside runner execution pipeline (update `NetAuto.Network.LocalRunner.execute_command/3` temporarily to emit start/stop with timestamps until WS05 runner is live). Include metadata: `%{run_id, device_id, protocol, site}`; measurements: `%{duration: ms, bytes: int}`.
2. Emit `[:net_auto, :run, :created]` inside `Automation.create_run/1` with metadata `%{device_id, protocol, site}`.
3. Update tests to assert `:telemetry_test.attach_event_handlers` receives events.
4. Run targeted tests.

### Task 3: Custom PromEx plugin for runner metrics

**Files:**
- Create: `net_auto/lib/net_auto/prom_ex/runner_plugin.ex`
- Modify: `net_auto/lib/net_auto/prom_ex.ex`
- Test: `net_auto/test/net_auto/prom_ex/runner_plugin_test.exs`

1. Write failing test verifying plugin defines counters/summaries for `:runner` events (`active_runs`, `run_duration_ms`, `runner_errors_total`). Use `PromEx.Plugin` macros in test to assert metric definitions exist (`capture_log` to ensure compile works).
2. Implement plugin with `use PromEx.Plugin`. Define `event_metrics` with `counter` + `summary` definitions hooking to Telemetry events.
3. Add plugin module to `NetAuto.PromEx.plugins/1` list.
4. Run tests, ensuring `mix prom_ex.metrics` outputs definitions.

### Task 4: LiveView + command throughput metrics

**Files:**
- Modify: `net_auto/lib/net_auto_web/live/run_live.ex`
- Modify: `net_auto/lib/net_auto/automation.ex`
- Tests: `net_auto/test/net_auto_web/live/run_live_test.exs`, `net_auto/test/net_auto/automation_test.exs`

1. Add Telemetry span around RunLive mount/handle_event to record latency/exception counts (`:telemetry.span`). Emit `[:net_auto, :liveview, :mount]` with duration measurement.
2. Add throughput counters for runs/chunks (maybe reusing Task 2 events) if needed.
3. Extend tests to attach telemetry handler and assert event fired when LiveView mounts and when command form submits.

### Task 5: Generate & commit dashboards

**Files:**
- Directory: `net_auto/lib/net_auto/prom_ex/dashboards/`
- Add: `runner_overview.json`, `liveview_health.json`, `command_throughput.json`

1. Run `cd net_auto && mix prom_ex.dashboard.create NetAuto.PromEx runner_overview` etc., customizing panel definitions to include counters from custom plugin.
2. Verify generated JSON references correct metrics/panels.
3. Include snapshot instructions in repo (these files are auto-loaded by PromEx).

### Task 6: Documentation & README updates

**Files:**
- Modify: `README.md`
- Modify: `project.md` (WS09 status if needed)
- Add: `docs/observability.md` (optional) describing env vars (`PROMEX_GRAFANA_URL`, `PROMEX_GRAFANA_API_KEY`) and how to run Grafana locally (`docker run grafana/grafana`).

1. Document how to start PromEx + dashboards locally.
2. Mention new Telemetry events for other WS owners.
3. Update `project.md` WS09 row to note dashboards implemented.

---

Once plan is approved, execute sequentially using TDD + `superpowers:executing-plans` or `superpowers:subagent-driven-development` as needed.
