# NetAuto

To start your Phoenix server:

* Copy `.env.sample` to `.env` (or export `PGUSER`, `PGPASSWORD`, `PGHOST`, `PGDATABASE`) so Ecto can connect.
* Run `mix setup` to install dependencies and prepare the database (`mix ecto.create` requires Postgres running locally).
* Generate dev certificates once with `mix phx.gen.cert` (already committed) if you need to refresh them.
* Start Phoenix endpoint with `mix phx.server` (or `iex -S mix phx.server`). This serves HTTP on `localhost:4000` and HTTPS on [`https://localhost:4001`](https://localhost:4001).

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Secrets

- Configure runtime credentials via env vars named `NET_AUTO_<CRED_REF>_USERNAME`, `_PASSWORD`, `_PRIVKEY`, `_PRIVKEY_BASE64`, `_PASSPHRASE`.
- Example:
  ```bash
  export NET_AUTO_LAB_DEFAULT_USERNAME=netops
  export NET_AUTO_LAB_DEFAULT_PASSWORD=changeme
  export NET_AUTO_LAB_DEFAULT_PRIVKEY_BASE64=\"$(base64 -w0 ~/.ssh/id_rsa)\"
  ```
- The Secrets adapter reads these values when a device/run executes; do not persist passwords or keys in the database. See `../docs/secrets.md` for the complete reference. Prefix a `cred_ref` with `env:` (default) or another adapter key such as `vault:` to route lookups.

## Telemetry

- SSH adapter + RunServer events live in `../docs/telemetry.md`.

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
