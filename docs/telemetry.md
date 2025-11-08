# Telemetry Reference

## SSH Adapter (`[:net_auto, :protocols, :ssh, *]`)

| Event | Measurements | Metadata |
| --- | --- | --- |
| `[:net_auto, :protocols, :ssh, :start]` | `%{}` | `%{device_id, hostname, cred_ref}` |
| `[:net_auto, :protocols, :ssh, :chunk]` | `%{bytes: byte_size(chunk)}` | `%{device_id, hostname, cred_ref}` |
| `[:net_auto, :protocols, :ssh, :stop]` | `%{bytes: total_bytes}` | `%{device_id, hostname, cred_ref, exit_code}` |
| `[:net_auto, :protocols, :ssh, :error]` | `%{}` | `%{device_id, hostname, cred_ref, reason}` |

Use these events to track SSH latency, throughput, and failure rates. Listeners should avoid logging secret material; only `cred_ref` is exposed for debugging.

## Run Server (`[:net_auto, :run, *]`)

RunServer emits:

- `[:net_auto, :run, :start]` with `%{system_time: native}` and metadata `%{run_id, device_id, site}`.
- `[:net_auto, :run, :chunk]` with `%{bytes}` and metadata `%{run_id, device_id, site, seq}`.
- `[:net_auto, :run, :stop]` with `%{bytes, duration}` and metadata `%{run_id, device_id, site, status}`.

Attach handlers via `:telemetry.attach/4` to stream run progress to PromEx, Oban dashboards, or logging backends.
