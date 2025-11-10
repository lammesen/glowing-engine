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
  - Update once further findings are captured.
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
| CR-01 | Tooling | `mix credo --strict` task missing | `mix credo --strict` → "task credo could not be found" (2025-11-10) | Cannot enforce lint guardrail required by scope | Add `{:credo, "~> 1.7", only: [:dev, :test], runtime: false}` and configure; ensure CI job runs | Add CI job + local script to run Credo |
| CR-02 | Tooling | `mix dialyzer` task missing | `mix dialyzer` → "task dialyzer could not be found" (2025-11-10) | Dialyzer gate in checklist can’t run; no typespec enforcement | Add Dialyzer dependency (`:dialyxir`) and CI job; configure PLT caching | Add dialyzer run in CI |
| CR-03 | Tooling | `mix sobelow` task missing | `mix sobelow -i Config.HTTPS --exit` → "task sobelow could not be found" (2025-11-10) | Cannot run required security gate; no automated CSP/CSRF checks | Add `{:sobelow, "~> 0.13", only: :dev}` and CI job | Add sobelow stage |
| CR-04 | Testing | Coverage gate failing (`mix test --cover`) | Coverage 79.84% < 90% threshold; printed by mix test run on 2025-11-10 | Violates modernization guardrail; risks regressions | Raise coverage via focused tests (LiveView flows, contexts) before PR gating | Add tests for `/`, `/devices`, `/bulk/<ref>` plus context coverage |
| CR-05 | Testing | Inventory fixtures not isolated | `NetAuto.InventoryTest.list_devices/0` expected single record but seeds produced 5 records (2025-11-10) | Flaky tests due to seed leakage; undermines trust | Ensure tests own data (use sandbox + fixtures, avoid seeding in test env) | Add regression tests ensuring clean DB per test |

## Verification & Evidence Links
List telemetry screenshots, CI logs, and PRs that substantiate each finding once available.
