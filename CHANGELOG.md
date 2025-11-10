# Changelog

## Unreleased
### Added
- Documentation scaffolding for modernization deliverables plus baseline inventory plan (refs CR-01–CR-05, PRF pending).
- Credo/Dialyzer/Sobelow dependencies, configs, and GitHub Actions workflow enforcing formatter, lint, type analysis, security scan, and coverage (refs CR-01–CR-03, SEC-01..03).
- Test data isolation (skip seeds in MIX_ENV=test) and expanded LiveView/context/unit suites for `/`, `/devices`, `/bulk/<ref>` plus Network/Automation/Inventory coverage (refs CR-04/CR-05).
### Known Issues
- Coverage barely clears the ≥85% gate (85.01%); continue adding suites to maintain buffer (CR-04).
- CSP still allows `style-src 'unsafe-inline'` to satisfy LiveView (SEC-05); documented exception until nonce-based styles become viable.
- Session TTL/cookie flags (secure, strict same-site) remain at Phoenix defaults and need hardening (SEC-02).
