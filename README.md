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

## Next steps

- Start Postgres before running `mix ecto.create`/`mix test`; the sandbox uses env vars defined above.
- Add additional docs/tests per workstream requirements in `project.md` and `agents.md`.
