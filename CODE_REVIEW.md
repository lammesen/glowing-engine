# CODE_REVIEW.md

## Status Snapshot
| Area | Baseline | Current Risk | Next Action |
|------|----------|--------------|-------------|
| Overall | Pending baseline | Unknown | Complete inventory + populate findings |

## Purpose & Scope
Capture architectural, dependency, performance, and security findings for NetAuto. This document is the single source of truth for modernization risks and feeds every other deliverable.

## Sources & Evidence
- `docs/shared/context-map.md`
- `docs/shared/metrics.md`
- Mix env inventory (Elixir, OTP, Phoenix, LiveView versions)
- Test, perf, and security tool outputs (mix test/cover, PromEx dashboards, Sobelow)

## 1. Executive Summary
- Build baseline (2025-11-10): `mix compile --warnings-as-errors` completed cleanly on existing Elixir/OTP toolchain; no warnings observed.
- Tooling guardrails now wired up but red:
  - Credo clean locally (2025-11-10); keep watch via CI.
  - Dialyzer passes after adding struct typespecs and RetentionWorker fixes.
  - Sobelow highlights missing CSP headers and potential traversal/String.to_atom issues in `Inventory` and SSH adapter.
- Seeds no longer pollute test data: `priv/repo/seeds.exs` now skips inserts when `Mix.env() == :test`, and Inventory tests rely on fixtures.
- Test runner stability: Oban peers/plugins disabled in `:test`, so `mix test --cover` no longer crashes the SQL sandbox.
- Coverage improved from 79.84% → 81.25% via LiveView smoke tests and context fixtures, but still below the ≥85% guardrail.
Summarize top five findings with severity and impacted workstreams.

## 2. Stack Gap Matrix

| Component | Current (2025-11-10) | Target | Gap/Risk |
|-----------|----------------------|--------|----------|
| Elixir | 1.19.2 (OTP 28) | 1.19.0 | ✔ – already ≥ target; verify OTP 28 support matrix |
| Erlang/OTP | 28.1.1 | Prefer 27 (or 26 if incompat) | ⚠ – running newer OTP than validated target; confirm compatibility |
| Phoenix | 1.8.1 | 1.8.1 | ✔ |
| Phoenix LiveView | 1.1.17 | Latest compatible w/ 1.8.1 | ⚠ – upgrade pending |
| Oban | 2.20.1 | ≥2.17 (per scope) | ✔ |
| PromEx | 1.11.0 | 1.11.x | ✔ |

Update this table as additional components (Tailwind, Req, etc.) are validated.

## 3. Dependency Graph Overview
Reference diagrams in `docs/shared/context-map.md`, highlighting contexts, LiveViews, PubSub topics, and external systems.

## 4. Detailed Findings
| ID | Component | Issue | Evidence | Impact | Recommendation | Tests Needed |
|----|-----------|-------|----------|--------|----------------|--------------|
| CR-01 | Tooling | `mix credo --strict` fails with readability/refactor issues | Credo 1.7.13 output (2025-11-10) listing missing `@moduledoc`, alias order, cond misuse, etc. | **Resolved locally (2025-11-10)** – lint passes after module docs/alias cleanup; leave finding for monitoring until merged | Keep docs/alias hygiene enforced; run credo in CI | Add regression tests for modules touched |
| CR-02 | Tooling | Dialyzer reports type errors + missing specs | `mix dialyzer` (2025-11-10) initially flagged pattern matches + missing types; now fixed and gate passes locally | **Resolved locally (2025-11-10)** – keep Dialyzer in CI to prevent regressions | Enforce struct typespecs for new schemas | Ensure dialyzer runs in CI |
| CR-03 | Security | Sobelow finds missing CSP + unsafe File/String usage | `mix sobelow -i Config.HTTPS --exit` (2025-11-10) flagged Config.CSP (High) + traversal/String.to_atom warnings | Security gate red; CSP + file handling need remediation before release | Implement CSP headers, sanitize file paths, avoid `String.to_atom` | Add regression tests / security checks |
| CR-04 | Testing | Coverage gate failing (`mix test --cover`) | Coverage 81.25% (2025-11-10) < 90% threshold; Oban sandbox stabilized but guardrail unmet | Violates modernization guardrail; risks regressions | Continue adding LiveView flows (/devices bulk events) and context unit tests until ≥85% | Add tests for `/`, `/devices`, `/bulk/<ref>` plus context coverage |
| CR-05 | Testing | Inventory fixtures not isolated | `NetAuto.InventoryTest` previously relied on seeded data; seeds now skipped in test env (2025-11-10) | Mitigated, but enforce fixture usage in future suites | Keep seeds guarded; rely on fixtures + sandbox helpers | Add regression tests ensuring clean DB per test |

## Verification & Evidence Links
List telemetry screenshots, CI logs, and PRs that substantiate each finding once available.
