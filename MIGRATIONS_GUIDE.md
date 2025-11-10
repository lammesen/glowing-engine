# MIGRATIONS_GUIDE.md

## Status Snapshot
| Area | Baseline | Current Risk | Next Action |
|------|----------|--------------|-------------|
| Migration Safety | Pending | Unknown | Inventory existing migrations + indices |

## Purpose & Scope
Explain how to design, run, and back out NetAuto database/index changes safely, including Oban job data considerations.

## Sources & Evidence
- `docs/shared/metrics.md` (Table MG-01)
- Ecto migration files
- Database monitoring dashboards

## 1. Change Log
Chronological table of migrations with status, rollout date, and owner.

| ID | File | Description | Status |
|----|------|-------------|--------|
| MIG-01 | 20251108175326_create_users_auth_tables.exs | phx.gen.auth baseline | Applied (test reset 2025-11-10) |
| MIG-02 | 20251108180350_create_devices.exs | Devices table + indexes | Applied |
| MIG-03 | 20251108180359_create_device_groups.exs | Device groups | Applied |
| MIG-04 | 20251108180408_create_device_group_memberships.exs | Join table | Applied |
| MIG-05 | 20251108180413_create_command_templates.exs | Command templates | Applied |
| MIG-06 | 20251108180419_create_runs.exs | Runs table | Applied |
| MIG-07 | 20251108180425_create_run_chunks.exs | Run chunks | Applied |
| MIG-08 | 20251108180500_add_oban_tables.exs | Oban v2 tables | Applied |

## 2. Online Migration Playbooks
Detail add/backfill/swap/drop sequencing, constraint/index strategies, and locking precautions.

## 3. Data Migration Procedures
Describe Ecto scripts, Oban backfill jobs, and verification queries. Include guidance for long-running migrations (chunking, throttling).

- Oban baseline migration `20251108180500_add_oban_tables.exs` installs tables without queue-specific indexes beyond scheduled_at; confirm upgrade steps when bumping Oban (2.20.1).

## 4. Backout & Verification
Checklist for backups, health checks, and telemetry to monitor during rollout and rollback.

## Verification & Evidence Links
Tie each migration to its PR, test evidence, and DB logs.
