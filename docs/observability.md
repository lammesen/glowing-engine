# Observability

NetAuto ships PromEx instrumentation so you can monitor runners, LiveViews, and
command throughput.

## PromEx runtime

PromEx starts as part of `NetAuto.Application`. By default it only exposes the
`/metrics` endpoint on the metrics server started by PromEx; dashboards are not
uploaded unless Grafana credentials are provided.

Set the following environment variables before starting the app to push the
bundled dashboards automatically:

```
export PROMEX_GRAFANA_URL="http://localhost:3000"
export PROMEX_GRAFANA_API_KEY="<grafana-api-key>"
export PROMEX_GRAFANA_FOLDER="NetAuto"
```

PromEx looks for Grafana at `PROMEX_GRAFANA_URL` and uses the API key to
upload the JSON dashboards stored under
`lib/net_auto/prom_ex/dashboards/` (runner overview, live view health, command
throughput).

To spin up a local Grafana instance:

```
docker run --rm -d -p 3000:3000 --name grafana grafana/grafana-enterprise
```

After setting the environment variables above, run `mix phx.server` and the
dashboards will appear under the configured Grafana folder.

## Telemetry events

The following Telemetry events are emitted and converted to Prometheus metrics:

| Event name | Measurements | Metadata |
|------------|--------------|----------|
| `[:net_auto, :runner, :start]` | `count` | `device_id`, `source`, `requested_by` |
| `[:net_auto, :runner, :stop]` | `duration_ms`, `bytes`, `count` | `device_id`, `run_id`, `requested_by` |
| `[:net_auto, :runner, :error]` | `count` | `device_id`, `requested_by` |
| `[:net_auto, :run, :created]` | `count` | `run_id`, `device_id`, `site`, `protocol` |
| `[:net_auto, :run, :chunk_appended]` | `count`, `bytes` | `run_id`, `seq` |
| `[:net_auto, :liveview, :mount]` | `duration_ms`, `count` | `view`, `device_id` |
| `[:net_auto, :liveview, :command_submitted]` | `count` | `device_id`, `requested_by`, `command` |

These metrics show up in the PromEx web metrics endpoint and fuel the bundled
Grafana dashboards.
