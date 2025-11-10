# Shared Metrics Tables

Populate these once baseline data is captured. Other docs should reference the IDs below instead of duplicating numbers.

## Test Coverage (Table TM-01)
| Layer | Target % | Baseline % | Evidence Link | Notes |
|-------|----------|------------|---------------|-------|
| Unit | 90 | 79.84 | mix test --cover (2025-11-10) | Fails threshold; LiveView/integration gaps |
| LiveView | 85 | TBD | TBD |  |
| Integration | 80 | TBD | TBD |  |
| Property | 70 | TBD | TBD |  |

## Performance (Table PM-01)
| Metric | Target | Baseline | Latest | Evidence |
|--------|--------|----------|--------|----------|
| Time to First Paint (TTFP) | < 1.5s | Unauthenticated redirect 20ms (GET /, 2025-11-10) | TBD | Need authenticated sample |
| LV Mount Avg | < 150ms | Not captured (auth redirect) | TBD | Instrument after login |
| LV Render Diff p95 | < 80ms | Not captured | TBD | Requires telemetry |
| DB Query p95 | < 120ms | Not captured | TBD | Add Telemetry/Logger |
| Memory / Connection | < 10MB | Not captured | TBD | Add metrics |

## Stack Versions (Table SV-01)
| Component | Baseline | Target | Notes |
|-----------|----------|--------|-------|
| Elixir | 1.19.2 | 1.19.0 | Already ≥ target; verify OTP compatibility |
| Erlang/OTP | 28.1.1 | 27 (preferred) | Evaluate library compatibility |
| Phoenix | 1.8.1 | 1.8.1 | Matches target |
| Phoenix LiveView | 1.1.17 | Latest compatible w/ 1.8.1 | Requires upgrade |

## Security (Table SM-01)
| Control | Baseline | Target | Evidence | Notes |
|---------|----------|--------|----------|-------|
| Sobelow Findings | Not runnable (`mix sobelow` missing) | 0 high, 0 medium | Pending once dependency added | Add sobelow dependency + CI |
| Session TTL | Not documented (Plug.Session default) | 30m idle / 12h absolute | Pending config review | Add explicit TTL + renewal |
| Cookie Flags | store=:cookie, key="_net_auto_key", `same_site: "Lax"`, no `secure` flag | Secure + SameSite=Strict | Needs hardening | Set secure cookie, consider encryption |
| CSP Policy | TBD | No `unsafe-inline` | TBD |  |
| Secrets Storage | TBD | `NET_AUTO_*` env only | TBD |  |

## Migration Health (Table MG-01)
| Migration | Status | Backout Ready? | Evidence |
|-----------|--------|----------------|----------|
| TBD | Pending | TBD | TBD |

## DX Metrics (Table DX-01)
| Metric | Baseline | Target | Evidence |
|--------|----------|--------|----------|
| Onboarding Time | TBD | < 30 min | TBD |
| `mix setup` Success Rate | TBD | 100% | TBD |
| Precommit Duration | TBD | < 5 min | TBD |
