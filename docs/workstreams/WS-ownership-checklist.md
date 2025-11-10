# Workstream Ownership Checklist

This WS ownership checklist keeps every in-flight branch discoverable and accountable.

| WS | Branch name | Owner | Status | Notes |
|----|-------------|-------|--------|-------|
| WS02 – DB & schemas | `ws02-db-schemas` | _unassigned_ | outline only | Needs migrations for devices/runs/chunks plus schema tests. |
| WS03 – Secrets adapter | `ws03-secrets-adapter` | _unassigned_ | not started | Implement env adapter + telemetry with TDD. |
| WS04 – SSH protocol adapter | `ws04-ssh-adapter` | _unassigned_ | not started | Build `SSHAdapter.run/4` + streaming tests vs sim lab. |
| WS05 – Runner & quotas | `ws05-runner-quotas` | _unassigned_ | not started | Implement `RunServer` + `QuotaServer`, wire telemetry. |
| WS06 – Chelekom UI foundation | `ws06-chelekom-ui` | _unassigned_ | prototype | Run Mishka generators, confirm imports, document theme tokens. |

## Ownership steps
1. Create/checkout the branch listed above from `main`.
2. `cd net_auto && mix deps.get && mix ecto.setup`; return to repo root and run `npm install` to ensure the shared `@opencode-ai/sdk` tooling is available.
3. Update or add a plan under `docs/plans/YYYY-MM-DD-wsXX-<topic>.md` before touching code; follow Section 5 rules (failing tests first).
4. Execute the plan using Section 6 or 7 from `AGENTS.md`, keeping timestamps plus command outputs for every test run.
5. Record progress by editing the table above (owner + status) when you start, hand off, or finish a workstream.
6. Reference the Cisco sim scripts in `bin/` for SSH-related work and document any new verification steps in `README.md` once validated.
