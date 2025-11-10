# 2025-11-10 Repo Hygiene & Workstream Bootstrap Plan

## Task 1 – Harden root `.gitignore`
1. **Write failing test**: `git status -sb | rg "\.env|node_modules|tmp_dev\.log"`
   - *Expectation*: command exits 0 and prints lines for `.env`, `node_modules/`, and `tmp_dev.log`, proving they are currently tracked/unignored.
2. **Run and confirm failure**: capture the actual output showing those files so we know the test is red.
3. **Minimal implementation**: edit the root `.gitignore` to append entries for `.env`, `net_auto/.env`, `node_modules/`, `tmp_dev.log`, `tmp_phx_server.log`, and `*.log` (leave `package-lock.json` tracked so the automation dependency stays reproducible).
4. **Verification test**: rerun `git status -sb | rg "\.env|node_modules|tmp_dev\.log"`.
   - *Pass condition*: command exits 1 (no matches) proving the ignore rules work; alternatively, if exit code handling is inconvenient, ensure no output is printed.
5. **Commit prep**: `git status -sb` should now only show intentional tracked/untracked files (package manifests, docs).

## Task 2 – Document Node toolchain & workstream readiness
1. **Write failing test**: search for existing documentation of the root Node toolchain.
   - Command: `rg "@opencode-ai" README.md project.md docs -n`.
   - *Expectation*: no hits, proving the documentation gap.
2. **Run and confirm failure**: capture empty output or non-zero exit, documenting the missing guidance.
3. **Implementation**: update `README.md` under “Quick start” (after step 7) with a short subsection "Root automation tooling" explaining the `@opencode-ai/sdk` dependency, how to install via `npm install`, and that `node_modules/` is ignored. Include instructions on running any scripts if/when added.
   - Add a bullet to `project.md` Workstreams section clarifying WS owners must create branches per table and reference the root package tooling for automation commands.
4. **Verification test**: rerun `rg "@opencode-ai" README.md project.md -n` and ensure matches now point to the new sections; also run `rg "automation tooling" README.md -n` to confirm wording landed.
5. **Commit prep**: `mix format` (noop for docs but enforces formatter), then `git status -sb` should show `.gitignore`, `README.md`, and `project.md` as modified plus tracked package manifests.

## Task 3 – Capture workstream branch ownership checklist
1. **Write failing test**: verify there is no checklist describing open branches per WS.
   - Command: `rg "WS ownership" docs -n` expecting no matches.
2. **Run and confirm failure**: note absence of hits.
3. **Implementation**: create `docs/workstreams/WS-ownership-checklist.md` describing:
   - Table mapping WS02–WS06 to owners/placeholders, required branches (e.g., `ws02-db-schemas`), and status fields.
   - Checklist instructing engineers to (a) create branch, (b) run `mix test`, (c) update plan before coding.
4. **Verification test**: `rg "WS ownership" docs/workstreams/WS-ownership-checklist.md -n` should highlight the new content; optionally lint Markdown via `markdownlint` if available (skip if not installed).
5. **Commit prep**: ensure new file tracked and referenced in `project.md` under section 3 so contributors can find it.
