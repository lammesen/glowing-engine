# Agents Handbook (agents.md)
**How Codex Agents work together on this project**

This file gives you the tools, conventions, and checklists to execute `project.md` efficiently with multiple agents.

---

## 1) Roles & ownership (pick one or more)

- **Agent‑A (WS01)** — Phoenix bootstrap & auth; HTTPS; base routes
- **Agent‑B (WS02)** — DB & schemas/migrations
- **Agent‑C (WS03)** — Secrets adapter (ENV), redaction, tests
- **Agent‑D (WS04)** — SSH protocol adapter
- **Agent‑E (WS05)** — Runner + Quotas + Telemetry
- **Agent‑F (WS06)** — Chelekom install, import wiring, theme tokens
- **Agent‑G (WS07)** — Devices UI (index + forms)
- **Agent‑H (WS08)** — Run UI (streaming output + history)
- **Agent‑I (WS09)** — Observability (PromEx dashboards)
- **Agent‑J (WS10)** — Retention & bulk jobs (Oban)

> If you need to touch another role’s area, open a PR against that role’s branch rather than pushing directly.

---

## 2) Daily workflow

1. **Sync**: `git checkout main && git pull`
2. **Branch**: `git checkout -b wsXX-short-desc`
3. **Run**: `mix deps.get && mix ecto.setup && mix phx.server`
4. **Implement** scoped to your WS directories.
5. **Test**: `mix test` (+ LiveView tests where applicable)
6. **Format & lint**: `mix format`
7. **Commit** using Conventional Commits.
8. **PR** with the template (see below). Request review from another agent.
9. **Review** at least two PRs/day from others.

---

## 3) Tools you will use

### Mix tasks (Chelekom)
- Generate all components globally (preferred):
  ```bash
  mix mishka.ui.gen.components --import --helpers --global --yes
  ```
- Generate targeted components:
  ```bash
  mix mishka.ui.gen.components alert,button,card,table,tabs,modal,toast,form_wrapper,input_field,select,textarea,spinner --import --helpers --yes
  ```
- CSS overrides (optional):
  ```bash
  mix mishka.ui.css.config --init
  # after editing the generated config file
  mix mishka.ui.css.config --regenerate
  ```
- Assets deps helper (if needed):
  ```bash
  mix mishka.assets.deps --npm --yes
  ```

### App commands
```bash
mix phx.server            # run the server
IEx -S mix                # REPL
mix ecto.migrate         # run migrations
mix test                 # run tests
```

---

## 4) Branching, commits, and PRs

**Branch naming**: `ws07-devices-ui-table`, `ws05-runner-telemetry`

**Conventional Commits** examples:
- `feat(ui): devices index with Chelekom table`
- `feat(automation): add RunServer with PubSub streaming`
- `fix(security): redact cred_ref logs`
- `chore(ci): add pull_request_template`
- `test(protocols): unit tests for SSHAdapter timeouts`

**PR etiquette**
- Small scope, clear title, screenshots/GIFs for UI.
- Link WS ID and checklist. Request reviewer in a different WS.
- Resolve review comments quickly; keep PRs under ~400 lines when possible.

**PR template**: already in `project.md`; ensure it exists at `.github/pull_request_template.md`.

---

## 5) Review rubric

- **Correctness**: migrations reversible; schemas match migrations; adapters handle timeouts/errors.
- **Security**: no secrets in DB; no `silently_accept_hosts: true` in prod; RBAC checks.
- **Performance**: long‑running IO in supervised processes; no blocking LiveView.
- **Observability**: Telemetry added on start/stop/error; measurements included.
- **UI quality**: Chelekom components used instead of raw HTML; accessible labels; responsive layout.
- **Tests**: unit + LiveView tests; happy + failure paths.
- **Docs**: inline moduledocs; PR text complete.

---

## 6) Definition of Done (DoD) per WS

- Everything compiles; `mix test` green.
- Format clean; no warnings.
- Feature behind flag or guarded route if not GA.
- Telemetry events in place where applicable.
- Chelekom components generated/used; no custom CSS unless necessary.
- PR merged with at least one approving review.

---

## 7) How to avoid conflicts

- Respect directory scope (see WS table).
- Do not edit migrations from another branch; add a new migration if needed.
- For `lib/net_auto_web.ex`, only Agent‑F (WS06) edits global imports; others use local imports in their modules.
- If multiple agents need new components, coordinate: Agent‑F runs the generator; others **do not** re‑generate globally. Targeted generation in feature branches is fine—commit the generated files and mention them in the PR.

---

## 8) Security & secrets

- Store only `cred_ref` in DB.
- Use environment variables `NET_AUTO_<REF>_PASSWORD` / `_PRIVKEY` for local dev.
- Redact secret material from logs and crash reports.
- Add a `.env.sample` (no secrets) showing expected variables.

---

## 9) Testing guidance

- Use Mox for `Secrets` and `Protocols.Adapter` behaviors.
- LiveView tests: use `Phoenix.LiveViewTest` with stream assertions.
- For SSH adapter, prefer fakes/mocks; integration tests can use containerized `sshd` gated behind `:integration` tag.
- For `run_chunks`, assert append‑only ordering and pagination.

---

## 10) Troubleshooting

- **Chelekom components missing?** Re‑run the generator with `--import --helpers --global --yes` and commit the changes.
- **Tailwind errors after overrides?** Run `mix mishka.ui.css.config --validate`, then `--regenerate`.
- **PubSub not streaming?** Ensure subscription to `"run:#{run.id}"` happens after `execute_command/2`; check topic string and that the runner is under the supervisor.
- **SSH timeouts?** Confirm device reachability; raise `cmd_timeout` temporarily for diagnostics.

---

## 11) Copy‑ready prompts

- **Devices table with Chelekom**
  > Build `/devices` index LiveView using Chelekom `table` component, sortable columns (hostname, IP, protocol, site), and an “Add Device” primary button. Use Phoenix Streams for updates. Include unit tests.

- **Run streaming UI**
  > Build `/devices/:id` LiveView with a command input, primary “Run” button, streamed output in a Chelekom `card` with monospaced font, success/error `toast`, and a `badge` for status.

- **SSH adapter behavior**
  > Implement `NetAuto.Protocols.Adapter` and `SSHAdapter.run/4` that connects, executes a command, streams data via callback, and returns `{:ok, exit_code, bytes}` or `{:error, reason}`. Include timeouts and no secret logging.

---

## 12) Definition of Ready (DoR)

- WS issue created with scope, acceptance criteria, and dependencies.
- Designs or component selections listed (Chelekom names).
- Test approach outlined.
- Rollback/flag plan noted if user‑visible.
