# Glowing Engine – NetAuto WS01 Bootstrap

This repo hosts the Network Automation Platform reboot (Phoenix + LiveView + Mishka Chelekom). The WS01 deliverable scaffolds the Phoenix app, auth, HTTPS, and baseline docs so other workstreams can build on top.

## Quick start

1. `cd net_auto`
2. Copy `.env.sample` to `.env` (or export `PGUSER`, `PGPASSWORD`, `PGHOST`, `PGDATABASE`).
3. Ensure Postgres is running locally and create the DB: `mix setup`.
4. Start the server: `mix phx.server` (HTTP `localhost:4000`, HTTPS `https://localhost:4001`).
5. Visit `https://localhost:4001/users/register` to create the first account, then you’ll land on the auth-guarded home page.

*Need certificates?* Run `mix phx.gen.cert` inside `net_auto/` to refresh `priv/cert/*.pem` (ignored by git).

## Workstreams bootstrapped

- **WS01:** Phoenix 1.8 app, LiveView, Argon2 auth via `phx.gen.auth`, HTTPS dev config, Mishka Chelekom dependency.
- **WS02+** can now add migrations/schemas under `net_auto/lib/net_auto/*` and `priv/repo`. Respect directory scopes listed in `agents.md`.
- **WS06** should run Mishka generators (`mix mishka.ui.gen.components --import --helpers --global --yes`) when ready.
- **WS07/WS08** can replace the placeholder dashboard (`/`) with Devices/Run LiveViews; routes already require authenticated users.
- **WS08 preview:** create a device record, then visit `/devices/:id` to filter run history, submit commands, and stream chunk output live while the runner broadcasts to `"run:<run_id>"`.

## Next steps

- Start Postgres before running `mix ecto.create`/`mix test`; the sandbox uses env vars defined above.
- To try the run workspace, set `NET_AUTO_<CRED_REF>_*` vars, create a device via `NetAuto.Inventory.create_device/1`, and call `NetAuto.Network.execute_command/3` (or use the `/devices/:id` form) to watch the output stream.
- Add additional docs/tests per workstream requirements in `project.md` and `agents.md`.

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
- See `docs/secrets.md` for the complete matrix and telemetry event details.

## Telemetry

- Protocol-layer events are listed in `docs/telemetry.md` (`[:net_auto, :protocols, :ssh, *]`).
- Run-layer events remain under `[:net_auto, :run, *]` and are documented alongside the SSH adapter.
