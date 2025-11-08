# WS10 Bulk & Retention – Design (2025-11-08)

## 1. Oban Wiring
- Enable Oban globally: add `config :net_auto, Oban, repo: NetAuto.Repo, queues: [default: 10, retention: 5, bulk: 5], plugins: [{Oban.Plugins.Cron, crontab: [{"@daily", NetAuto.Automation.RetentionWorker}]}]` in `config/config.exs`.
- `NetAuto.Application` starts Oban via `{Oban, Application.fetch_env!(:net_auto, Oban)}` before Repo-dependent workers. Telemetry attaches in `NetAutoWeb.Telemetry` for visibility.

## 2. Retention Worker
- Config knobs (documented in README/plan) sourced from env vars `NET_AUTO_RUN_MAX_DAYS`, `NET_AUTO_RUN_MAX_BYTES`, `NET_AUTO_RETENTION_CRON`:
  ```elixir
  config :net_auto, NetAuto.Automation.Retention,
    max_age_days: {:system, "NET_AUTO_RUN_MAX_DAYS", 30},
    max_total_bytes: {:system, "NET_AUTO_RUN_MAX_BYTES", 1_073_741_824}, # 1 GiB
    schedule: {:system, "NET_AUTO_RETENTION_CRON", "@daily"}
  ```
- `NetAuto.Automation.RetentionWorker` (Oban worker on `:retention` queue) loads config, then:
  1. Deletes runs older than `max_age_days` (based on `finished_at || inserted_at`) in batches (e.g., 200) using Ecto `delete_all` to cascade run_chunks.
  2. Enforces byte caps per device: aggregate `sum(bytes)` grouped by device, and for devices above `max_total_bytes`, iteratively delete oldest runs until within threshold.
- Emits telemetry (`[:net_auto, :retention, :purge]`) with counts/durations for observability.

## 3. Bulk Fan-Out Job + LiveView Hooks
- `NetAuto.Automation.BulkJob` (Oban worker on `:bulk` queue) accepts `%{"device_ids" => [...], "command" => "...", "requested_by" => user_email}`.
- `NetAuto.Automation.Bulk.enqueue/3` validates devices, chunks large lists (e.g., 50 IDs per job) to keep payloads small, and enqueues jobs.
- Worker loops device IDs, calling `Network.execute_command/3` with `requested_by` metadata. Errors per device are logged and reported via telemetry (`[:net_auto, :bulk, status]`).
- Existing WS07/WS08 LiveViews expose a new “Run command on selected devices” UI:
  - Devices index gains multi-select (checkbox per row) plus a Chelekom modal to enter the command.
  - On submit, LiveView calls `NetAuto.Automation.Bulk.enqueue/3`, flashes success, and navigates to `/bulk/<ref>`.
- `/bulk/:bulk_ref` mounts `NetAutoWeb.BulkLive.Show`, which subscribes to `"bulk:<ref>"` and streams `{:bulk_progress, ...}` / `{:bulk_summary, ...}` messages so operators can watch fan-out in real time.
- Run workspace remains focused on per-device execution; bulk dashboards stay optional yet immediately useful since WS07/WS08 are already present.

## 4. Testing & Docs
- Add DataCase tests for `RetentionWorker` (seed runs/chunks, run worker, assert deletions) using `Oban.Testing`. Bulk job tests validate chunking + `Network.execute_command/3` invocation (use Mox for `NetAuto.Network.Client`).
- Document knobs and cron schedule in `README.md` + `docs/plans/ws10`. Mention how to trigger bulk runs via UI and CLI (`mix run -e 'NetAuto.Automation.Bulk.enqueue(...)'`).
