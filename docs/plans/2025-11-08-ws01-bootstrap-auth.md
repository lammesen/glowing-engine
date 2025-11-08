# WS01 Bootstrap & Auth Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Scaffold the Phoenix 1.8 `net_auto` app with Postgres, LiveView, HTTPS, and `phx.gen.auth` so other workstreams can build on it.

**Architecture:** Generate a fresh Phoenix project in `net_auto/`, configure core deps (Phoenix, LiveView, Ecto, Oban, PromEx, Mishka Chelekom), and enable HTTPS + auth routes. This creates the Accounts context plus baseline layouts that gate all routes behind authentication.

**Tech Stack:** Elixir 1.17, Phoenix 1.8, LiveView 1.1, Ecto SQL/PostgreSQL, Argon2, Oban 2.17, PromEx 1.10, Mishka Chelekom 0.0.8.

---

### Task 1: Initialize Phoenix project

**Files:**
- Create: `net_auto/*` (Phoenix generator output)
- Modify: root README after generation
- Test: n/a yet

1. Run `mix phx.new net_auto --database postgres --install` from repo root (accept defaults). Expected output: deps installed, assets built.
2. Enter `net_auto` and run `mix setup` (ensures deps + DB create). Expected `Created database net_auto_dev`.
3. Commit scaffold: `git add net_auto` → `git commit -m "chore(ws01): bootstrap phoenix app"`.

### Task 2: Lock required dependencies

**Files:**
- Modify: `net_auto/mix.exs`, `net_auto/mix.lock`

1. In `mix.exs`, adjust deps list to exactly:
```elixir
defp deps do
  [
    {:phoenix, "~> 1.7.14"},
    {:phoenix_ecto, "~> 4.4"},
    {:ecto_sql, "~> 3.11"},
    {:postgrex, ">= 0.0.0"},
    {:phoenix_live_view, "~> 1.1"},
    {:floki, ">= 0.30.0", only: :test},
    {:phoenix_html, "~> 4.1"},
    {:phoenix_live_reload, "~> 1.5", only: :dev},
    {:esbuild, "~> 0.9", runtime: Mix.env() == :dev},
    {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
    {:telemetry_metrics, "~> 0.6"},
    {:telemetry_poller, "~> 1.1"},
    {:gettext, "~> 0.24"},
    {:jason, "~> 1.4"},
    {:plug_cowboy, "~> 2.7"},
    {:argon2_elixir, "~> 4.0"},
    {:oban, "~> 2.17"},
    {:prom_ex, "~> 1.10", only: [:dev, :prod]},
    {:mishka_chelekom, "~> 0.0.8", only: :dev}
  ]
end
```
2. Add `:ssl` and `:ssh` to `extra_applications` in the same file:
```elixir
extra_applications: [:logger, :runtime_tools, :ssl, :ssh]
```
3. Run `mix deps.get` to update `mix.lock`.
4. Commit dependency updates: `git add mix.exs mix.lock` → `git commit -m "chore(ws01): add platform deps"`.

### Task 3: Configure Repo & runtime

**Files:**
- Modify: `net_auto/config/dev.exs`, `config/test.exs`, `config/runtime.exs`
- Create: `.env.sample` sentinel referencing DB creds

1. Update `config/dev.exs` Repo config to point to local Postgres (username/password env driven). Example snippet:
```elixir
config :net_auto, NetAuto.Repo,
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", ""),
  hostname: System.get_env("PGHOST", "localhost"),
  database: "net_auto_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
```
2. Mirror minimal changes in `config/test.exs` (pool_size 5, database `net_auto_test`).
3. Ensure `config/runtime.exs` loads `DATABASE_URL` for prod release per Phoenix default. Keep secrets out of repo.
4. Create `.env.sample` at repo root describing `PGUSER`, `PGPASSWORD`, `PGHOST`. No secrets.
5. Run `mix ecto.create` to ensure config works.
6. Commit: `git add config .env.sample` → `git commit -m "chore(ws01): configure repo env"`.

### Task 4: Generate auth scaffold

**Files:**
- Modify/Create: `net_auto/lib/net_auto/accounts/*`, `lib/net_auto_web/controllers/*`, `lib/net_auto_web/templates/*`, `lib/net_auto_web/router.ex`, `priv/repo/migrations/*`
- Tests: `net_auto/test/net_auto_web/controllers/user_auth_*`, etc.

1. Run `mix phx.gen.auth Accounts User users`.
2. Follow generator instructions:
   - Update `lib/net_auto_web/router.ex` pipelines and scope blocks per printed diff.
   - Add `net_auto/lib/net_auto/mailer.ex` config to `config/dev.exs` and `config/test.exs` (Swoosh local adapter).
3. Run `mix deps.get` if generator adds Swoosh.
4. Run `mix ecto.migrate` to create `users` table.
5. Update root layout `lib/net_auto_web/components/layouts/root.html.heex` to include nav links (Home, Log out) in header.
6. Ensure `mix test` passes. Expected: tests compile and pass (0 failures).
7. Commit: `git add .` (scoped to generator output) → `git commit -m "feat(ws01): add auth scaffold"`.

### Task 5: Secure default routes & HTTPS docs

**Files:**
- Modify: `lib/net_auto_web/router.ex`, `lib/net_auto_web/controllers/page_controller.ex`, `lib/net_auto_web/templates/page/home.html.heex`, `config/dev.exs`, `README.md`

1. Update router root scope so `/` requires authenticated user and points to `PageController.home` inside `:browser` + `:require_authenticated_user` pipeline.
2. Adjust `PageController` to fetch `conn.assigns.current_user` and render placeholder dashboard.
3. Edit `home.html.heex` to show logged-in user email and TODO text for future dashboard.
4. Confirm dev HTTPS config remains active: ensure `config/dev.exs` includes `https: [port: 4001,... cipher_suite: :strong, ... keyfile: "priv/cert/selfsigned_key.pem", certfile: "priv/cert/selfsigned.pem"]`.
5. In README, document how to run `mix phx.server` (https on 4001) plus how to regenerate certs via `mix phx.gen.cert`.
6. Run `mix phx.server` briefly to verify app boots; `CTRL+C` to stop.
7. Commit: `git add lib/net_auto_web config/dev.exs README.md` → `git commit -m "feat(ws01): gate root route behind auth"`.

### Task 6: Final verification & handoff notes

**Files:**
- Modify: `README.md` (add “Next steps for other WS”) and `net_auto/.gitignore` if needed

1. Run `mix test` and `mix dialyzer` (if dialyzer configured) to ensure clean slate.
2. Run `mix format` for entire project.
3. Document in README a short section “Workstreams Bootstrapped” listing WS01 deliverables and instructions for WS02+ (e.g., `cd net_auto && mix ecto.gen.migration ...`).
4. Tag tasks as complete in project tracking (if applicable).
5. Commit final polish: `git add README.md` etc → `git commit -m "chore(ws01): finalize bootstrap notes"`.

