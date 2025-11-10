# SECURITY_REPORT.md

## Status Snapshot
| Area | Baseline | Current Risk | Next Action |
|------|----------|--------------|-------------|
| Sobelow | Not run | Unknown | Execute `mix sobelow -i Config.HTTPS --exit` |

## Purpose & Scope
Document NetAuto’s security posture (authN/authZ, CSRF, CSP, secrets, job handling) and link every finding to remediation work.

## Sources & Evidence
- `docs/shared/metrics.md` (Table SM-01)
- Sobelow reports, phx.gen.auth configs, cookie/session settings
- NetAuto.Secrets implementation and env policy

## 1. Threat Model Summary
Describe actors, entry points, and assets (devices, jobs, secrets).

## 2. Findings Overview
| ID | Category | Severity | Description | Evidence | Recommended Fix |
|----|----------|----------|-------------|----------|-----------------|
| SEC-01 | Tooling | High | `mix sobelow` task missing → security scan cannot run | CLI output "task sobelow could not be found" (2025-11-10) | Add Sobelow dependency and CI stage |

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
