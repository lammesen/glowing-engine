# DX_GUIDE.md

## Status Snapshot
| Area | Baseline | Current Risk | Next Action |
|------|----------|--------------|-------------|
| Developer Onboarding | Pending | Unknown | Capture current setup pain points |

## Purpose & Scope
Document developer workflows, scripts, secrets hygiene, and required tooling so contributors can land PRs that meet NetAuto’s modernization guardrails.

## Sources & Evidence
- CODE_REVIEW + REFACTOR_PLAN requirements
- `docs/shared/metrics.md` (Table DX-01)
- `agents.md`, `net_auto/AGENTS.md`, existing scripts in `bin/`

## 1. Setup & Toolchain
List required versions (Elixir 1.19, OTP, Postgres), installation methods (asdf, direnv, devcontainer), and environment files (`.env`, `.envrc`).

- Baseline (2025-11-10): Tooling expects Elixir 1.19.2 / OTP 28.1.1. Ensure OpenSSL + Postgres available. Credo/Dialyzer/Sobelow deps now installed; first runs take time (dialyzer builds PLT ~45s).

## 2. Commands & Scripts
Document `mix setup`, `mix precommit`, `bin/dev`, Cisco simulator scripts, Makefile targets (if added), and expected outputs.

- Observed command behavior (2025-11-10):
  - `mix test --cover` fails due to `NetAuto.InventoryTest.list_devices/0` expecting isolated data; seeds insert five devices. Capture fixtures per test (CR-05).
  - Coverage output 80.78% after LiveView + context tests; still below ≥85% guardrail, so keep treating as failing build until addressed.
  - `mix credo --strict` now runs but reports missing `@moduledoc` tags, alias ordering issues, and nested `cond` blocks (CR-01).
  - `mix dialyzer` builds PLTs then fails on missing type specs (`Run.t`, `Device.t`) and impossible matches in RetentionWorker (CR-02).
  - `mix sobelow -i Config.HTTPS --exit` highlights missing CSP header plus potential traversal/string-to-atom vectors (CR-03/SEC-01..03).

## 3. Secrets Hygiene
Explain `NET_AUTO_<CRED_REF>_*` expectations, how to populate env vars locally, and redaction rules.

## 4. CI Expectations
Describe GitHub Actions workflow stages (format, credo, dialyzer, sobelow, tests, release build, Docker) and how to reproduce locally.

- CI must run `mix format --check-formatted`, `mix credo --strict`, `mix dialyzer`, `mix sobelow -i Config.HTTPS --exit`, and `mix test --cover`. Cache PLTs to keep runtimes reasonable.

## 5. PR & CHANGELOG Workflow
Detail Conventional Commit prefixes per PR wave, evidence requirements (Finding IDs + links), and CHANGELOG update steps.

## Verification & Evidence Links
Provide onboarding session notes, screenshots, and successful run logs once collected.
