# Changelog

## Unreleased
### Added
- Documentation scaffolding for modernization deliverables plus baseline inventory plan (refs CR-01–CR-05, PRF pending).
- Credo/Dialyzer/Sobelow dependencies, configs, and GitHub Actions workflow enforcing formatter, lint, type analysis, security scan, and coverage (refs CR-01–CR-03, SEC-01..03).
- Test data isolation (skip seeds in MIX_ENV=test) and expanded LiveView/context/unit suites for `/`, `/devices`, `/bulk/<ref>` plus Network/Automation/Inventory coverage (refs CR-04/CR-05).
### Known Issues
- Coverage (`mix test --cover`) at 79.84% with fixture leakage (CR-04/CR-05).
- Coverage (`mix test --cover`) now 80.78% after new tests; still < ≥85% gate (CR-04).
- Credo still fails due to missing `@moduledoc` tags/alias ordering (CR-01).
- Dialyzer fails on missing struct types + impossible pattern matches in RetentionWorker (CR-02).
- Sobelow flags missing CSP header + unsafe file ops (`Config.CSP`, traversal warnings) (CR-03, SEC-01..03).
