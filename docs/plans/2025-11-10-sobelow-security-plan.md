# Sobelow & Security Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Resolve Sobelow findings (missing CSP header, unsafe `String.to_atom`, filesystem usage in SSH adapter) and ensure `mix sobelow -i Config.HTTPS --exit` passes.

**Architecture:** Add CSP headers to the browser pipeline, sanitize filter helpers to avoid dynamic atoms, and constrain SSH adapter temp files. Verify by running Sobelow and updating security docs.

---

### Task 1: Add CSP Headers

**Files:** `net_auto/lib/net_auto_web/router.ex`, `net_auto/lib/net_auto_web/endpoint.ex`

**Steps:**
1. Add `plug :put_secure_browser_headers, content_security_policy: <policy>` to the `:browser` pipeline.
2. Define policy (default-src 'self'; img-src 'self' data:; etc.) referencing requirements.
3. Update SECURITY_REPORT + CODE_REVIEW to note CSP implemented.

### Task 2: Sanitize `String.to_atom`

**Files:** `net_auto/lib/net_auto/inventory.ex`

**Steps:**
1. Replace raw `String.to_existing_atom` usage with whitelist/map translation (e.g., map of allowed fields) to avoid dynamic atoms.
2. Update related tests (inventory search sorts) to cover fallback path.

### Task 3: Harden SSH Adapter Temp Files

**Files:** `net_auto/lib/net_auto/protocols/ssh_adapter.ex`

**Steps:**
1. Ensure temp dir resides under `System.tmp_dir!/net_auto/` with unique subdir; sanitize `File.rm_rf` target.
2. Use `Briefly` or `:filename` to generate safe paths; restrict to 600 perms. Add doc comment.

### Task 4: Verification & Docs

1. Run `mix sobelow -i Config.HTTPS --exit` → expect PASS.
2. Run `mix precommit` (still fails coverage) to ensure lint/tooling gates remain clean.
3. Update SECURITY_REPORT (SEC-01..03) statuses and CHANGELOG Known Issues.
4. Commit `security: harden sobelow findings` referencing CR-03/SEC-01..03.

---

## Execution Handoff
Plan saved to `docs/plans/2025-11-10-sobelow-security-plan.md`. Execution options: subagent-driven (this session) or parallel executing-plans session.
