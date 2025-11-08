# WS02 Database & Schemas Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Model every table in `project.md` (devices, groups, templates, runs, run_chunks) with Ecto migrations, schemas, and tested context APIs so downstream workstreams can rely on stable data contracts.

**Architecture:** Keep Inventory concerns under `lib/net_auto/inventory/**` and Automation under `lib/net_auto/automation/**`. Each context owns migrations, schemas with enums, and CRUD helpers. Tests run via `mix test` (requires Postgres running with env vars from `.env.sample`).

**Tech Stack:** Elixir 1.17, Phoenix 1.8, Ecto SQL/PostgreSQL, ExUnit, Mox-ready fixtures.

---

### Task 1: Draft migrations for all tables

**Files:**
- Create: `priv/repo/migrations/*_create_devices.exs`, `*_create_device_groups.exs`, `*_create_device_group_memberships.exs`, `*_create_command_templates.exs`, `*_create_runs.exs`, `*_create_run_chunks.exs`

1. Run `mix ecto.gen.migration create_devices` (repeat for each table). Expected: six empty migration files.
2. In `*_create_devices.exs`, define columns (`hostname`, `ip`, `protocol` string default "ssh", `port`, `username`, `cred_ref`, `vendor`, `model`, `site`, `tags` map default `%{}`, `metadata` map) + `timestamps(type: :utc_datetime)`.
3. Add indexes: `unique_index(:devices, [:hostname, :site], name: :devices_hostname_site_index)`, plus indexes on `:cred_ref` and `:protocol`.
4. Fill other migrations with fields from `project.md` (enums stored as strings, boolean defaults, foreign keys with `on_delete` rules) and required indexes (unique template names, membership unique pair, run chunk unique `[run_id, seq]`).
5. Run `mix format` to keep migrations tidy (hotkey `mix format priv/repo/migrations/*create_*.exs`).
6. Commit: `git add priv/repo/migrations && git commit -m "feat(ws02): add migrations"`.

### Task 2: Implement Inventory schemas and changesets

**Files:**
- Create: `lib/net_auto/inventory/device.ex`, `device_group.ex`, `device_group_membership.ex`, `command_template.ex`

1. Define each schema with matching fields (`Ecto.Enum` for protocols/modes/roles, map defaults for tags/metadata, `has_many`/`belongs_to` relationships).
2. Write changesets enforcing `validate_required`, `unique_constraint`, number bounds (port range, etc.), and assoc constraints.
3. Commit after running `mix format`. Message: `feat(ws02): add inventory schemas`.

### Task 3: Build Automation schemas for runs and chunks

**Files:**
- Create: `lib/net_auto/automation/run.ex`, `run_chunk.ex`

1. Model `Run` with `Ecto.Enum` status (`:pending/:running/:ok/:error`), timestamp fields, `belongs_to :device` and optional `belongs_to :command_template`.
2. Model `RunChunk` with `:seq`, `:data`, `belongs_to :run`, `timestamps(updated_at: false)`, unique constraint.
3. Add validations for bytes >= 0, seq >= 0, etc.
4. `mix format && git add && git commit -m "feat(ws02): add automation schemas"`.

### Task 4: Expose context APIs + fixtures + tests

**Files:**
- Create: `lib/net_auto/inventory.ex`, `lib/net_auto/automation.ex`
- Create: `test/support/fixtures/inventory_fixtures.ex`, `automation_fixtures.ex`
- Create: `test/net_auto/inventory_test.exs`, `test/net_auto/automation_test.exs`

1. Inventory context: CRUD/list helpers for devices, groups, memberships, templates, with optional preload support.
2. Automation context: CRUD for runs, chunk append/list helpers with `order_by(:seq)`.
3. Fixtures: helper functions returning persisted structs (call context functions).
4. Tests: cover success + error paths (missing required fields, duplicate membership), chunk ordering, assoc constraints. Use `errors_on` + fixtures.
5. Run `mix test` (requires Postgres running). Expect some tests to fail until contexts compile; fix issues before continuing.
6. Commit all new code/tests: `git add lib/net_auto/{inventory,automation}.ex ... && git commit -m "feat(ws02): add contexts and tests"`.

### Task 5: Wire auth tests + docs for schema usage

**Files:**
- Modify: `test/net_auto_web/controllers/page_controller_test.exs` to log in via helper (since `/` requires auth).
- Modify: `lib/net_auto_web/user_auth.ex` to continue exposing `@current_user` assign for tests/UI convenience.
- Update: `README.md` (root + `net_auto/README.md`) with a “Database setup” section referencing `.env.sample` and `mix ecto.setup`.

1. Adjust auth test helper pipeline (call `register_and_log_in_user`).
2. Add `assign(:current_user, user)` in `fetch_current_scope_for_user/2` so LiveViews/tests don’t break.
3. Document DB steps for other workstreams.
4. `mix format && PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH" mix test` (should be green).
5. Commit: `git commit -am "chore(ws02): doc db usage"` (or similar).

