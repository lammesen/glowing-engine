# Fly.io + Neon Deploy Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deploy `net_auto/` to Fly.io as a Mix release backed by Neon Postgres, with proper runtime env handling, migrations, and docs.

**Architecture:** Use a two-stage Dockerfile (hexpm Elixir build → Debian runtime) to produce a Mix release that Fly launches via `/app/bin/net_auto start`. Production config pulls `DATABASE_URL`, `SECRET_KEY_BASE`, etc., from environment variables. Fly’s deploy command runs release migrations before starting machines.

**Tech Stack:** Elixir 1.19 / OTP 27, Phoenix 1.8, Fly.io, Neon Postgres, Docker.

---

### Task 1: Replace Dockerfile with Fly-ready release build

**Files:**
- Update: `Dockerfile`

**Steps:**
1. Overwrite with the provided multi-stage definition (hexpm build image + Debian runtime) using Elixir 1.19.0 / OTP 27.1 tag, installing Node/npm in build stage.
2. Ensure assets builds (`npm --prefix assets ci`) guard works even if package.json missing.
3. Confirm runtime stage copies release to `/app` and starts with `CMD ["/app/bin/net_auto","start"]`, exposing port 8080.

### Task 2: Ensure runtime.exs handles Fly env vars

**Files:**
- Modify: `net_auto/config/runtime.exs`

**Steps:**
1. Inside the `if config_env() == :prod` block, add (or confirm) the `DATABASE_URL` fetch with descriptive error.
2. Parse `POOL_SIZE`, default 5.
3. Configure `NetAuto.Repo` with `url`, `pool_size`, and `ssl: true`.
4. Configure `NetAutoWeb.Endpoint` URL + HTTP binding on `0.0.0.0:port`, default 8080, with `PHX_HOST` fallback `localhost`.
5. Add `if System.get_env("PHX_SERVER")` guard to enable server, and fetch `SECRET_KEY_BASE` with raise on missing.

### Task 3: Release helper for migrations

**Files:**
- Create: `net_auto/lib/net_auto/release.ex`

**Steps:**
1. Define module `NetAuto.Release` with `@app :net_auto`.
2. Implement `migrate/0` loading app, iterating `Application.fetch_env!(@app, :ecto_repos)`.
3. For each repo, run `Ecto.Migrator.with_repo(repo, fn repo -> Ecto.Migrator.run(repo, :up, all: true) end)`.

### Task 4: Fly config

**Files:**
- Create/update: `fly.toml` at repo root

**Steps:**
1. Set `app = "netauto"`.
2. Under `[env]`, define `PHX_SERVER = "true"` and `PORT = "8080"`.
3. `[build]` points to `dockerfile = "Dockerfile"`.
4. `[http_service]` block per requirements (internal_port 8080, force_https true, auto start/stop, min machines 1).
5. `[deploy]` release command invoking the migration helper: `/app/bin/net_auto eval 'Elixir.NetAuto.Release.migrate()'`.

### Task 5: Deployment docs

**Files:**
- Create: `docs/fly.md`

**Steps:**
1. Document one-time commands (app create, secrets set w/ Neon URL, SECRET_KEY_BASE, PHX_HOST, PHX_SERVER, POOL_SIZE).
2. Document deploy loop (`flyctl deploy --config ./fly.toml --detach`, `flyctl status`, `flyctl logs`).
3. Add smoke test snippet (curl first 5 lines).
4. Mention migration release command automatically runs via `[deploy]`.

### Task 6: Remove legacy Node start paths

**Files:**
- Search repo for `npm start`, `Procfile`, or other Node-based boot instructions.

**Steps:**
1. Delete any obsolete files (e.g., root `Procfile` or scripts referencing `npm start`).
2. Update docs (if necessary) to point to Fly release start, ensuring no conflicting instructions remain.
3. Verify README/other docs don’t instruct to run `npm start` for prod.

### Task 7: Verification

**Steps:**
1. Run `cd net_auto && MIX_ENV=prod mix release` (optional) to ensure Docker build inputs compile locally.
2. Run `flyctl deploy --config ./fly.toml --dry-run` if available, or at least `docker build -f Dockerfile .` to catch syntax issues (skip if environment lacks docker).
3. `mix test` to confirm no regressions.
4. Summarize commands required to set Fly secrets.
