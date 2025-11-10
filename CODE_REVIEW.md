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
  - Credo reports missing `@moduledoc` tags, alias ordering, and deeply nested `cond` blocks.
  - Dialyzer surfaces missing struct types and impossible pattern matches in RetentionWorker.
  - Sobelow highlights missing CSP headers and potential traversal/String.to_atom issues in `Inventory` and SSH adapter.
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
| CR-01 | Tooling | `mix credo --strict` fails with readability/refactor issues | Credo 1.7.13 output (2025-11-10) listing missing `@moduledoc`, alias order, cond misuse, etc. | Lint gate currently red; refactors required before CI passes | Address Credo warnings (module docs, alias ordering, refactors) or triage waivers | Add regression tests for modules touched |
| CR-02 | Tooling | Dialyzer reports type errors + missing specs | `mix dialyzer` (2025-11-10) flagged pattern matches in RetentionWorker + unknown types for `Run.t`, `Device.t`, `Adapter` specs | Type safety guardrail failing; blocks precommit + CI | Add `@type t` for key structs, fix pattern matches, add dialyzer ignores only if justified | Ensure dialyzer runs in CI |
| CR-03 | Security | Sobelow finds missing CSP + unsafe File/String usage | `mix sobelow -i Config.HTTPS --exit` (2025-11-10) flagged Config.CSP (High) + traversal/String.to_atom warnings | Security gate red; CSP + file handling need remediation before release | Implement CSP headers, sanitize file paths, avoid `String.to_atom` | Add regression tests / security checks |
| CR-04 | Testing | Coverage gate failing (`mix test --cover`) | Coverage 79.84% < 90% threshold; printed by mix test run on 2025-11-10 | Violates modernization guardrail; risks regressions | Raise coverage via focused tests (LiveView flows, contexts) before PR gating | Add tests for `/`, `/devices`, `/bulk/<ref>` plus context coverage |
| CR-05 | Testing | Inventory fixtures not isolated | `NetAuto.InventoryTest.list_devices/0` expected single record but seeds produced 5 records (2025-11-10) | Flaky tests due to seed leakage; undermines trust | Ensure tests own data (use sandbox + fixtures, avoid seeding in test env) | Add regression tests ensuring clean DB per test |

## Verification & Evidence Links
List telemetry screenshots, CI logs, and PRs that substantiate each finding once available.
