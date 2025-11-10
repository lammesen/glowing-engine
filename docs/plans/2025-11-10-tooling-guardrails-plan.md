# Tooling Guardrails Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Credo, Dialyzer, and Sobelow tooling (deps, configs, aliases, CI) so the NetAuto modernization guardrails can run locally and in GitHub Actions.

**Architecture:** Introduce dev/test-only Mix deps (`credo`, `dialyxir`, `sobelow`), generate their config files, wire them into `mix.exs` aliases/CI workflow, document usage, and update CODE_REVIEW findings accordingly. No production code paths affected.

**Tech Stack:** Elixir 1.19.2, Mix, Credo 1.7, Dialyxir 1.4, Sobelow 0.13, GitHub Actions (Elixir setup), Markdown docs.

---

### Task 1: Add Tooling Dependencies & configs

**Files:**
- Modify: `net_auto/mix.exs`
- Create: `.credo.exs`, `dialyzer.ignore-warnings` (optional), `mix.lock` updates, `config/sobelow.exs` if needed.

**Step 1:** Add deps to `deps/0`:
```elixir
{:credo, "~> 1.7", only: [:dev, :test], runtime: false},
{:dialyxir, "~> 1.4", only: [:dev], runtime: false},
{:sobelow, "~> 0.13", only: :dev}
```

**Step 2:** Update aliases: add `credo --strict`, `dialyzer`, and `sobelow -i Config.HTTPS --exit` to `precommit`, e.g. `precommit: ["compile --warning-as-errors", "deps.unlock --unused", "format", "credo --strict", "dialyzer", "sobelow -i Config.HTTPS --exit", "test"]`.

**Step 3:** Install deps `cd net_auto && mix deps.get`.

**Step 4:** Generate Credo config `mix credo.gen.config` (outputs `.credo.exs`).

**Step 5:** Generate Dialyxir config `mix dialyzer --plt` (creates `.dialyzer_ignore.exs` or `dialyxir_erlang-*.plt`; document location). Add `dialyzer.ignore-warnings` placeholder for waivers.

**Step 6:** Ensure Sobelow config optional (not strictly needed). Document default `-i Config.HTTPS` as part of command.

### Task 2: Update Documentation & Findings

**Files:**
- `CODE_REVIEW.md`
- `SECURITY_REPORT.md`
- `DX_GUIDE.md`
- `docs/shared/metrics.md`

**Step 1:** Update CODE_REVIEW findings CR-01/CR-03 to note “In progress / resolved pending CI run”. Add new CR if issues persist.

**Step 2:** Update SECURITY_REPORT (Sobelow section) once tool runnable.

**Step 3:** Update DX_GUIDE Setup + CI sections to mention commands now available.

**Step 4:** Update shared metrics table SM-01 to show Sobelow baseline result once run.

### Task 3: Run Tools Locally (TDD style)

**Files:**
- `.credo.exs`, `dialyxir`, `mix.lock`

**Step 1:** `cd net_auto && mix credo --strict` (expect PASS/ warnings). If warnings, document CR IDs and either fix or record waivers.

**Step 2:** `cd net_auto && mix dialyzer` – build PLT (may take time). Capture runtime, warnings; update CODE_REVIEW.

**Step 3:** `cd net_auto && mix sobelow -i Config.HTTPS --exit` – gather findings, update SECURITY_REPORT.

### Task 4: GitHub Actions CI updates

**Files:**
- Modify/create `.github/workflows/ci.yml` (or similar) – ensure jobs for format, credo, dialyzer, sobelow, test.

**Step 1:** Inspect existing workflows. If missing, create `ci.yml` with matrix on OTP/Elixir (matching 1.19.x/OTP 28?). Include caching steps for deps, build, PLT.

**Step 2:** Add steps:
```yaml
- run: mix format --check-formatted
- run: mix credo --strict
- run: mix dialyzer
- run: mix sobelow -i Config.HTTPS --exit
- run: mix test --cover
```
Use `mix deps.get`, `mix compile --warnings-as-errors` prerequisites.

**Step 3:** Document secrets (if needed) for Sobelow (shouldn’t require). Ensure Postgres service for tests.

### Task 5: Docs & CHANGELOG updates

**Files:**
- `CHANGELOG.md`
- `DX_GUIDE.md`
- `README.md` (if referencing commands)

**Step 1:** Add bullet under “Added” describing new tooling enforcement referencing CR IDs.

**Step 2:** Mention new commands in DX_GUIDE + README.

### Task 6: Commit & Evidence

**Files:** All edited files.

**Step 1:** Verify `git status` clean except relevant files.

**Step 2:** Run `mix precommit` to ensure alias works end-to-end (may fail coverage – acceptable; record result).

**Step 3:** Commit with message `build: add lint and security tooling` (or similar) referencing CR IDs in body.

**Step 4:** Attach artifacts/screenshots or mention logs in CODE_REVIEW.

---

## Execution Handoff
Plan complete and saved to `docs/plans/2025-11-10-tooling-guardrails-plan.md`. Two execution options:
1. Subagent-Driven (this session) – preferred for incremental review.
2. Parallel Session – open new session with executing-plans.
