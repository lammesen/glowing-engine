# NetAuto

To start your Phoenix server:

* Copy `.env.sample` to `.env` (or export `PGUSER`, `PGPASSWORD`, `PGHOST`, `PGDATABASE`) so Ecto can connect.
* Run `mix setup` to install dependencies and prepare the database (`mix ecto.create` requires Postgres running locally).
* Generate dev certificates once with `mix phx.gen.cert` (already committed) if you need to refresh them.
* Start Phoenix endpoint with `mix phx.server` (or `iex -S mix phx.server`). This serves HTTP on `localhost:4000` and HTTPS on [`https://localhost:4001`](https://localhost:4001).

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
