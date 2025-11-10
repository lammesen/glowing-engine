# SECURITY_REPORT.md

## Status Snapshot
| Area | Baseline | Current Risk | Next Action |
|------|----------|--------------|-------------|
| Sobelow | First green run 2025-11-10 14:45 PT | Low – gate passes locally | Keep command in `mix precommit`; capture report artifacts in CI |

## Purpose & Scope
Document NetAuto’s security posture (authN/authZ, CSRF, CSP, secrets, job handling) and link every finding to remediation work.

## Sources & Evidence
- `docs/shared/metrics.md` (Table SM-01)
- Sobelow reports, phx.gen.auth configs, cookie/session settings
- NetAuto.Secrets implementation and env policy

## 1. Threat Model Summary
Describe actors, entry points, and assets (devices, jobs, secrets).

## 2. Findings Overview
| ID | Category | Severity | Description | Evidence | Status / Next Step |
|----|----------|----------|-------------|----------|-------------------|
| SEC-01 | Config | High → Mitigated | CSP plug `NetAutoWeb.Plugs.ContentSecurityPolicy` now injected into router + endpoint, covering LiveView and static assets. | Diff + `mix sobelow` (2025-11-10) shows Config.CSP cleared. | Monitor CSP changes when new assets/components are added; keep policy documented in `docs/security/csp.md`. |
| SEC-02 | Input Validation | Medium → Mitigated | Inventory filters now use whitelist map rather than `String.to_atom/1`. | `lib/net_auto/inventory.ex` lookup map + `mix sobelow` clean run. | Extend whitelist when new query params land; add unit tests for `normalize_filter_key/1`. |
| SEC-03 | File Handling | Medium → Mitigated | SSH adapter no longer touches arbitrary filesystem paths. Private keys stay in-memory via `NetAuto.Protocols.SSHKeyCallback`; temp user dirs handled by `Briefly`. | New module `lib/net_auto/protocols/ssh_key_callback.ex`, updated tests, and Sobelow traversal findings resolved 2025-11-10. | Enforce callback usage for any future protocol adapters; document passphrase/algorithm support in ARCHITECTURE_DECISIONS.md. |
| SEC-04 | Input Validation | Low → Mitigated | Mishka components previously called `String.to_atom/1` for attribute filtering. All helpers now use `String.to_existing_atom/1` with rescue fallback, and the remaining generated modules live in `net_auto_ui_components/` to limit attack surface. | `lib/net_auto_web/components/{badge,button,indicator}.ex` replacements + `mix sobelow` clean run (2025-11-10 17:30 PT). | Keep future component imports inside the dependency; require `to_existing_atom` when adding new attrs. |
| SEC-05 | CSP Exception | Known Issue | LiveView currently requires `style-src 'self' 'unsafe-inline'` for dynamic attribute patches. This exception is documented in `docs/shared/metrics.md` and must remain until Phoenix/LiveView support nonce-based styles. | router.ex, PromEx CSP plug | Track removal plan post-LiveView upgrade; note in future releases if/when removed. |

## 3. AuthZ/AuthN Posture
Evaluate login/registration flows, Argon2 parameters, session TTL, remember-me tokens, lockouts.

- Observation (2025-11-10): No explicit session TTL or idle timeout configured; defaults depend on Phoenix session plug. Requires ADR + implementation.

## 4. CSRF, CSP, Cookie Policies
Review Phoenix protections, LiveView tokens, cookie flags, CSP headers.

- Baseline (2025-11-10): `Plug.Session` configured with cookie store, signed only, `same_site: "Lax"`, and no `secure` flag — needs hardening per NET_AUTO guardrails.

## 5. Secrets & Sensitive Data
Describe `cred_ref` strategy, runtime resolution, logging redaction, Oban job payload hygiene.

## Verification & Evidence Links
Attach Sobelow output, configuration diffs, and tests covering auth flows.
