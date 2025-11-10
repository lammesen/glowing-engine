# Glowing Engine – NetAuto WS01 Bootstrap

This repo hosts the Network Automation Platform reboot (Phoenix + LiveView + Mishka Chelekom). The WS01 deliverable scaffolds the Phoenix app, auth, HTTPS, and baseline docs so other workstreams can build on top.

## Quick start

1. `cd net_auto`
2. Copy `.env.sample` to `.env` (or export `PGUSER`, `PGPASSWORD`, `PGHOST`, `PGDATABASE`).
3. Ensure Postgres is running locally and create the DB: `mix setup`.
4. (First run only) Generate trusted dev certs: `mkcert -install` (if you haven’t yet) and `mkcert -key-file priv/cert/localhost-key.pem -cert-file priv/cert/localhost-cert.pem localhost 127.0.0.1 ::1`.
5. Start the server: `mix phx.server` (HTTP `localhost:4000`, HTTPS `https://localhost:4001`).
6. Visit `https://localhost:4001/users/register` to create the first account, then you’ll land on the auth-guarded home page.
7. Open [`https://localhost:4001/devices`](https://localhost:4001/devices) to browse inventory, launch commands, and start bulk runs; monitor fan-out progress in real time at `/bulk/<ref>` once a job is enqueued.

### Quality gates (run inside `net_auto/`)
- `mix format --check-formatted`
- `mix credo --strict`
- `mix dialyzer` (first run builds PLTs; cache `_build`, `deps`, and `dialyxir_*`)
- `mix sobelow -i Config.HTTPS --exit`
- `mix test --cover`
The `precommit` alias chains all of the above (plus compile warnings, deps unlock check). Expect current failures from coverage (CR-04/CR-05), Credo (CR-01), Dialyzer (CR-02), and Sobelow (CR-03/SEC-01..03) until remediation PRs land.

### Root automation tooling
- Run `npm install` at the repo root to install the shared `@opencode-ai/sdk` helper dependency (recorded in `package-lock.json`).
- The `node_modules/` directory is ignored by Git—rerun `npm install` after every fresh clone or whenever the lockfile changes.
- Future workflow scripts will live under `bin/` or `scripts/` and can import the SDK; document any new commands in this section when they land.

### Manually capturing UI screenshots
1. Run `mix phx.server` in `net_auto/` so HTTPS endpoints are available.
2. Sign in and visit `/devices`; select a few rows and open the bulk modal so both the table and dialog are visible. Use your OS shortcut (`⌘⇧4` on macOS, `Win+Shift+S` on Windows, `Shift+PrintScreen` on GNOME) to grab the screenshot.
3. Kick off a bulk run to land on `/bulk/<ref>` and capture the progress dashboard the same way. Save the images under `docs/screenshots/` (gitignored) and attach them to PRs/issues as needed.

*Need certificates?* Run `mkcert -install` (once per machine) and then `mkcert -key-file priv/cert/localhost-key.pem -cert-file priv/cert/localhost-cert.pem localhost 127.0.0.1 ::1` inside `net_auto/` to refresh `priv/cert/*.pem` (ignored by git).

## Dev HTTPS

mkcert keeps the local certificate authority in your user keychain and writes project-specific PEMs that Phoenix can load directly:

1. Install mkcert (Homebrew: `brew install mkcert`) and trust the local CA: `mkcert -install`.
2. Inside `net_auto/`, generate the HTTPS cert/key:\
   `mkcert -key-file priv/cert/localhost-key.pem -cert-file priv/cert/localhost-cert.pem localhost 127.0.0.1 ::1`
3. Start Phoenix via `mix phx.server` and visit `https://localhost:4001`. Modern browsers should trust the certificate automatically.

The PEMs live under `priv/cert/` and remain gitignored—regenerate them whenever they expire or if you need to add more hostnames.

## Workstreams bootstrapped

- **WS01:** Phoenix 1.8 app, LiveView, Argon2 auth via `phx.gen.auth`, HTTPS dev config, Mishka Chelekom dependency.
- **WS02+** can now add migrations/schemas under `net_auto/lib/net_auto/*` and `priv/repo`. Respect directory scopes listed in `agents.md`.
- **WS06** should run Mishka generators (`mix mishka.ui.gen.components --import --helpers --global --yes`) when ready.
- **WS07/WS08** can replace the placeholder dashboard (`/`) with Devices/Run LiveViews; routes already require authenticated users.
- **WS08 preview:** create a device record, then visit `/devices/:id` to filter run history, submit commands, and stream chunk output live while the runner broadcasts to `"run:<run_id>"`.

## Retention & bulk configuration

Configure purge cadence and fan-out defaults via env vars (already read in `config/runtime.exs`):

| Variable | Default | Purpose |
| --- | --- | --- |
| `NET_AUTO_RUN_MAX_DAYS` | `30` | Maximum age (in days) before runs/chunks are purged |
| `NET_AUTO_RUN_MAX_BYTES` | `1073741824` | Per-device byte ceiling; oldest runs trimmed once exceeded |
| `NET_AUTO_RETENTION_CRON` | `@daily` | Cron string used by Oban to schedule the retention worker |

Reload the app (or restart the release) after changing these knobs so Oban picks up the new schedule.

## Next steps

- Start Postgres before running `mix ecto.create`/`mix test`; the sandbox uses env vars defined above.
- To try the run workspace, set `NET_AUTO_<CRED_REF>_*` vars, create a device via `/devices`, then run commands either from the Devices table (bulk) or the device detail page (`/devices/:id`) to watch streamed output.
- Observability/PromEx: set `PROMEX_GRAFANA_URL`, `PROMEX_GRAFANA_API_KEY`, and `PROMEX_GRAFANA_FOLDER` to upload the bundled dashboards (`lib/net_auto/prom_ex/dashboards/`). See `docs/observability.md` for how to run Grafana locally and which Telemetry events back the metrics.
- Add additional docs/tests per workstream requirements in `project.md` and `agents.md`.

## Cisco simulator lab

Use the open-source simulator fleet under `sim_devices/` to test SSH workflows without proprietary images:

1. `bin/launch-cisco-sims.sh` – builds the image and starts 10 containers listening on ports `2201`–`2210` (username/password `netops`).
2. Export `NET_AUTO_LAB_SIM_USERNAME=netops`, `NET_AUTO_LAB_SIM_PASSWORD=netops`, and `NET_AUTO_SIM_CRED_REF=env:LAB_SIM` (legacy `NETAUTO_SIM_CRED_REF` still works) so `NetAuto.Secrets` knows how to resolve `cred_ref`.
3. `cd net_auto && mix run priv/repo/seeds.exs` – seeds 10 devices pointing at `127.0.0.1` with the correct SSH ports.
4. When finished, run `bin/destroy-cisco-sims.sh` to tear everything down.

The CLI responses are defined in `sim_devices/commands/base.yml` plus per-device overrides in `sim_devices/devices/device*.yml`, so you can adjust outputs without rebuilding.

## Secrets

- Credentials live in environment variables named `NET_AUTO_<CRED_REF>_USERNAME`, `_PASSWORD`, `_PRIVKEY`, `_PRIVKEY_BASE64`, `_PASSPHRASE`.
- Example for `cred_ref` \"LAB_DEFAULT\":
  ```bash
  export NET_AUTO_LAB_DEFAULT_USERNAME=netops
  export NET_AUTO_LAB_DEFAULT_PASSWORD=changeme
  # or key-based auth
  export NET_AUTO_LAB_DEFAULT_PRIVKEY_BASE64=\"$(base64 -w0 ~/.ssh/id_rsa)\"
  export NET_AUTO_LAB_DEFAULT_PASSPHRASE=
  ```
- Secrets are resolved at runtime via `NetAuto.Secrets.fetch/2`; nothing sensitive is stored in the database.
- See `docs/secrets.md` for the complete matrix and telemetry event details. Use prefixes like `env:LAB_DEFAULT` or `vault:path/to/secret` to route lookups to other adapters.

## Telemetry

- Protocol-layer events are listed in `docs/telemetry.md` (`[:net_auto, :protocols, :ssh, *]`).
- Run-layer events remain under `[:net_auto, :run, *]` and are documented alongside the SSH adapter.
