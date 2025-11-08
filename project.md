# Network Automation Platform — Phoenix + LiveView + Mishka Chelekom (v2.1)
**Delivery Plan (project.md)**

> Clean‑slate rebuild of the Network Automation Platform on Elixir/Phoenix with LiveView UI built using the **Mishka Chelekom** component library. This plan is optimized for multiple Codex Agents to work in parallel without stepping on each other.

---

## 0) Goals & guardrails

- **Do fewer things, better**: first‑class SSH (Telnet behind a feature flag). Streamed output and trustworthy run history.
- **Security by default**: no plaintext secrets in DB; RBAC; HTTPS; production‑safe SSH defaults.
- **Isolation & resiliency**: one supervised process per device run; bounded concurrency & backpressure.
- **Extensible core**: protocol behaviors; chunked output storage; optional job queue for bulk/scheduling.
- **UI productivity**: generate LiveView components via **Mishka Chelekom** mix tasks; keep zero runtime dependency.

**Non‑goals (for v2.1):** NETCONF/gNMI drivers, topology visualization, multi‑tenant SSO, workflow designer. Design for these, do not implement.

---

## 1) Stack & versions

- **Phoenix**: 1.8+
- **LiveView**: 1.1+
- **Elixir / Erlang**: Elixir 1.17 / OTP 27
- **Tailwind**: 4+ (Phoenix default toolchain is fine)
- **DB**: PostgreSQL (Ecto SQL 3.11+)
- **Background jobs**: Oban (optional for bulk/scheduling)
- **UI components**: Mishka Chelekom (dev‑only; code generation into `lib/*_web/components`)
- **SSH**: Erlang `:ssh` (no plaintext secrets; prefer key‑based auth)

> Chelekom 0.0.8 supports Phoenix 1.8+, LiveView 1.1+, Tailwind 4+, Elixir 1.17/OTP 27. Use these as the default target versions.

---

## 2) High‑level architecture

```
NetAuto.Application
├─ NetAuto.Repo
├─ NetAutoWeb.Endpoint
├─ {Phoenix.PubSub, name: NetAuto.PubSub}
├─ {DynamicSupervisor, name: NetAuto.RunSupervisor}
├─ NetAuto.Automation.QuotaServer                      # backpressure & concurrency caps
└─ {Oban, ...} (optional; bulk jobs & schedules)
```

**Contexts**
- `Inventory` — devices, groups, templates (reusable commands)
- `Automation` — runs, run_chunks (append‑only stream), orchestration, quotas
- `Secrets` — resolves `cred_ref` to runtime credentials (ENV today, Vault‑ready)
- `Protocols` — `SSHAdapter` now; `TelnetAdapter` optional & disabled by default

**Data model (tables)**
- `devices` (hostname, ip, protocol enum, port, username, cred_ref, vendor, model, site, tags)
- `device_groups`, `device_group_memberships`
- `command_templates` (name, template, vars, mode: `:read | :change`, enabled)
- `runs` (device_id, template_id?, command, status enum, bytes, exit_code, started/finished, requested_by)
- `run_chunks` (run_id, seq, data)

---

## 3) Parallel workstreams (safe for multiple agents)

> Each workstream is **scoped to distinct directories** and flagged behind UI routes or feature flags. Use branch names like `wsXX-short-desc`.

| ID | Workstream | Scope (dirs) | Done when… |
|----|------------|--------------|------------|
| WS01 | Repo bootstrap & auth | `/` `/config` `/lib/*_web` | Phoenix app compiles, phx.gen.auth working, HTTPS locally |
| WS02 | DB & schemas | `/priv/repo` `/lib/net_auto/*` | Migrations + Ecto schemas for devices, runs, chunks |
| WS03 | Secrets adapter | `/lib/net_auto/secrets*` | `cred_ref` → ENV adapter with tests; no secrets in DB |
| WS04 | Protocol adapter (SSH) | `/lib/net_auto/protocols` | `SSHAdapter.run/4` streams chunks, timeouts honored |
| WS05 | Runner + quotas | `/lib/net_auto/automation` | `RunServer`, `QuotaServer`, Telemetry events |
| WS06 | UI foundation with Chelekom | `/lib/*_web/components` `/assets` | Chelekom installed; import file wired; base tokens/theme ok |
| WS07 | Devices UI | `/lib/*_web/live/device*` | Device list/table + create/edit forms (Chelekom forms) |
| WS08 | Run UI (streaming) | `/lib/*_web/live/run*` | Device show with “run” panel; live stream via PubSub; chunk viewer |
| WS09 | Observability | `/lib/*` `/config` | PromEx dashboards/metrics; Telemetry events wired |
| WS10 | Bulk & retention (optional) | `/lib/*` `/priv/repo` | Oban worker for purge; (optional) fan‑out bulk runner |

**Avoid collisions**
- WS06 only touches components/assets; WS07/WS08 only touch LiveViews/pages.
- WS02 owns migrations; WS05/WS08 can depend on WS02’s schema modules without editing migrations.
- If you must edit another WS area, open a PR to that WS branch instead of pushing directly.

---

## 4) Bootstrap & wiring (step‑by‑step)

### 4.1 Create project
```bash
mix phx.new net_auto --database postgres --install
cd net_auto
mix ecto.create
mix phx.gen.auth Accounts User users
```

Add deps in `mix.exs`:
```elixir
defp deps do
  [
    {:phoenix, "~> 1.8"},
    {:phoenix_live_view, "~> 1.1"},
    {:ecto_sql, "~> 3.11"},
    {:postgrex, ">= 0.0.0"},
    {:oban, "~> 2.17", only: [:dev, :test, :prod]},   # optional; disable if unused
    {:prom_ex, "~> 1.10", only: [:dev, :prod]},       # optional
    {:argon2_elixir, "~> 4.0"},
    {:plug_cowboy, "~> 2.7"},

    # Chelekom is dev‑only (generates code, no runtime dep)
    {:mishka_chelekom, "~> 0.0.8", only: :dev}
  ]
end

def application do
  [extra_applications: [:logger, :runtime_tools, :ssl, :ssh]]
end
```

### 4.2 Install Mishka Chelekom & generate components
**Preferred (one command, global import):**
```bash
mix deps.get
mix mishka.ui.gen.components --import --helpers --global --yes
```
This generates all components into your project and globally replaces Phoenix core components with Chelekom’s import file.

**Optional (targeted set, safe for partial UI work):**
```bash
# Common set for our UI:
mix mishka.ui.gen.components alert,button,card,table,tabs,modal,toast,form_wrapper,input_field,select,textarea,spinner --import --helpers --yes
```
> You can always run the full generator later. Keep generated files under VCS.

**CSS customization (optional, Tailwind 4)**
```bash
mix mishka.ui.css.config --init
# After editing your overrides:
mix mishka.ui.css.config --regenerate
```

**Assets helper (if you need to adjust JS deps):**
```bash
# Example: ensure npm deps exist in /assets/package.json
mix mishka.assets.deps --npm --yes
```

### 4.3 Wire Chelekom imports
- The generator creates an **import file** and helper macros. Follow its printed instructions.
- In Phoenix 1.8, update `lib/net_auto_web.ex` to import Chelekom’s generated import (the `--global` flag automates this). Keep core component imports only if you intentionally need them.
- Commit all generated component files and import changes.

### 4.4 Data model & migrations
Create migrations for: `devices`, `device_groups`, `device_group_memberships`, `command_templates`, `runs`, `run_chunks`. Favor enums via `Ecto.Enum` in schemas; use JSONB for `tags`. Keep `run_chunks (run_id, seq, data)` append‑only.

### 4.5 Secrets adapter
Add `NetAuto.Secrets` with an ENV adapter. Store only `cred_ref` in DB. Map `NET_AUTO_<REF>_PASSWORD` and/or `_PRIVKEY` to runtime values. Never log secrets.

### 4.6 Protocol adapter (SSH)
Implement `NetAuto.Protocols.Adapter` behavior and `SSHAdapter.run/4` using `:ssh`. Stream `{:data, ...}` chunks to a callback; return `{:ok, exit_code, bytes}` or `{:error, reason}`. Telnet remains disabled by default behind the same behavior.

### 4.7 Runner & quotas
- `RunServer` (GenServer per run) under `RunSupervisor`.
- `QuotaServer` (GenServer) enforces global/per‑group caps.
- `Network.execute_command/2` creates a `Run` row and starts a child runner.
- Broadcast chunks on `"run:#{run.id}"` with Phoenix PubSub.
- Finalize runs with status, exit code, byte count.

### 4.8 LiveViews (with Chelekom components)
- **Devices Index**: Chelekom `table`, search/filter chip(s), “Add Device” button.
- **Device Form**: `form_wrapper`, `input_field`, `select`, validation messages.
- **Device Show / Run Panel**: command input + “Run” (primary button); streamed output inside `card` with monospaced content; status `badge`; confirmations via `modal`; transient messages via `toast`.
- **Run Show**: server‑side pagination over `run_chunks`; “Download full output” action.

### 4.9 Observability & retention
- Emit Telemetry: `net_auto.run.start|stop|error` with device_id/run_id/bytes/durations.
- PromEx dashboards (optional).
- Oban worker to purge old runs/chunks by age/size.

---

## 5) Security checklist

- [ ] `cred_ref` only in DB; secrets resolved at runtime (ENV/Vault).
- [ ] Env adapter naming + telemetry documented in `docs/secrets.md`; keep secrets out of Git.
- [ ] Key‑based SSH preferred; manage `known_hosts`; **do not** set `silently_accept_hosts: true` in prod.
- [ ] `phx.gen.auth` with Argon2; session/CSRF defaults; HTTPS/HSTS on.
- [ ] RBAC: roles (`viewer|operator|admin`); guard “Run” actions to `operator+`.
- [ ] Audit: who ran what, device, exit code, bytes; redact secrets and payloads in logs.
- [ ] Output retention policy (days/bytes) with purge job.

---

## 6) Definition of Done (per feature)

- Unit and LiveView tests added; `mix test` green.
- Credo/formatter clean; no compiler warnings.
- Telemetry events emitted where applicable.
- Chelekom components generated/used (no ad‑hoc HTML when a component exists).
- Docs updated (`README`, `CHANGELOG`, and `project.md` checkboxes ticked).
- Feature flag or route guard in place (if not GA).

---

## 7) Git workflow for Codex Agents

- **Branching**: one branch per WS or subtask, e.g., `ws07-devices-ui-table`.
- **Conventional Commits**: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`.
- **PRs**: small, focused, descriptive. Link to WS and include checklist.
- **Reviews**: at least one other agent; use review rubric in `agents.md`.

**PR template (drop into `.github/pull_request_template.md`)**
```md
## What & Why
- [ ] Linked WS: WSXX — <name>
- [ ] Scope: files & dirs
- [ ] User‑visible changes (screenshots if UI)

## How
- [ ] Added/Updated migrations? (yes/no)
- [ ] New Chelekom components generated? (list)
- [ ] Telemetry added? (events)

## Tests
- [ ] Unit/LiveView tests
- [ ] Manual steps to verify

## Risks
- [ ] Data migration risk
- [ ] Feature flagged?

## Checklist
- [ ] `mix format` / `mix test`
- [ ] No secrets committed
- [ ] Docs updated
```

---

## 8) Task prompts for Codex (copy/paste)

- **Install Chelekom and generate components**
  > Add `{:mishka_chelekom, "~> 0.0.8", only: :dev}` to `mix.exs`. Run `mix deps.get` then `mix mishka.ui.gen.components --import --helpers --global --yes`. Commit all generated files. Update `lib/net_auto_web.ex` only as instructed by the generator.

- **Create Ecto schemas & migrations**
  > Create migrations for `devices`, `device_groups`, `device_group_memberships`, `command_templates`, `runs`, `run_chunks`. Use `Ecto.Enum` for protocol and status fields. Add indexes described in the plan. Generate schemas with changesets and tests.

- **Implement SSH adapter**
  > Implement `NetAuto.Protocols.Adapter` behavior and `NetAuto.Protocols.SSHAdapter.run/4` using `:ssh.connect` and `:ssh_connection.exec`. Stream chunks to a callback, returning `{:ok, exit_code, bytes}` or `{:error, reason}`. Include connect and command timeouts, and never log secrets.

- **Runner and PubSub streaming**
  > Implement `NetAuto.Automation.RunServer` (GenServer) under a `DynamicSupervisor`. It loads the device, enforces `QuotaServer` limits, runs the adapter, appends `run_chunks`, broadcasts `{:chunk, run_id, seq, data}` to `"run:#{run.id}"`, and finalizes the run with status and metrics.

- **Devices LiveView with Chelekom table & forms**
  > Build `/devices` index with Chelekom `table`, search, and “Add Device” button. Build `/devices/:id` with a Chelekom `form_wrapper` using input/select components. Validate and show messages with Chelekom `toast`/`alert`.

- **Run LiveView with streamed output**
  > On “Run” submit call `Network.execute_command/2`; subscribe to `"run:#{run.id}"`; append chunks to a stream inside a Chelekom `card` with monospaced text. Use `badge` for status; `modal` for dangerous commands; `toast` for completion.

---

## 9) Local smoke test

```elixir
# IEx -S mix
alias NetAuto.{Inventory, Network}
{:ok, d} = Inventory.create_device(%{hostname: "lab-sw1", ip: "192.0.2.10", protocol: :ssh, port: 22, username: "netops", cred_ref: "LAB_DEFAULT"})
System.put_env("NET_AUTO_LAB_DEFAULT_PASSWORD", "changeme")
{:ok, run} = Network.execute_command(d.id, "show version")
# Visit /devices/:id and watch the stream.
```

---

## 10) “Don’t do this” list

- Don’t store secrets or passwords in the database.
- Don’t run network IO inside LiveView processes.
- Don’t bypass Chelekom when a suitable component is available.
- Don’t globally allow `silently_accept_hosts` in SSH in production.
- Don’t merge PRs without tests and Telemetry where applicable.

---

## 11) Milestone plan

1. WS01/WS02/WS06 in parallel (bootstrap, DB, Chelekom install).
2. WS04/WS05 (SSH adapter, runner, quotas).
3. WS07/WS08 (Devices UI, Run streaming UI).
4. WS09 (observability).
5. WS10 (retention + bulk, if needed).

---

## 12) Appendix: References you may need

- Chelekom README & install snippet (dev‑only dep and generators)
- Chelekom “Get Started” docs (one‑command global install, Phoenix 1.8+/LV 1.1+/Tailwind 4+)
- Chelekom Mix tasks API (`mishka.ui.gen.components`, `mishka.ui.css.config`, `mishka.assets.deps`)
