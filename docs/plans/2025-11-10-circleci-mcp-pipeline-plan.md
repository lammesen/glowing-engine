# CircleCI + MCP Pipeline Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver a production-grade CircleCI pipeline with MCP integration, scripts, docs, and supporting Docker assets for the Phoenix LiveView app under `net_auto/`.

**Architecture:** Modular CircleCI config with reusable commands, caching, PostgreSQL service, and parameterized workflows (ci/nightly/release) plus GHCR pushes. Local repo gains CI helper scripts, test formatter config, security/dev tooling deps, documentation for CI+MCP, and optional Dockerfile/docker-compose for parity.

**Tech Stack:** Elixir 1.19 / OTP 27, Phoenix 1.8.1, Postgres, CircleCI, Bash, Docker (GHCR), MCP Toolkit.

---

### Task 1: Add CI/Test Dependencies in `mix.exs`

**Files:**
- Modify: `net_auto/mix.exs`

**Step 1:** Update the `project/0` config to bump `elixir: "~> 1.19"` and ensure `test_coverage` block stays intact.

**Step 2:** Extend `deps/0` with `{:dialyxir, "~> 1.4", only: [:dev], runtime: false}`, `{:sobelow, "~> 0.13", only: [:dev, :test], runtime: false}`, `{:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}`, `{:junit_formatter, "~> 3.4", only: [:test]}`, and `{:excoveralls, "~> 0.18", only: [:test]}`. Remove duplicated/old versions if present.

**Step 3:** Add `preferred_cli_env` entries for `dialyzer`, `coveralls`, and `coveralls.json` in `cli/0` if not already covered.

**Step 4:** Run `mix deps.get` locally to lock versions (command: `cd net_auto && mix deps.get`). Expect `mix.lock` changes.

**Step 5:** Stage files for later commit (`git add net_auto/mix.exs net_auto/mix.lock`).

---

### Task 2: Configure Test Formatter & Coveralls

**Files:**
- Modify: `net_auto/test/test_helper.exs`
- Modify: `net_auto/config/test.exs`

**Step 1:** At the top of `test/test_helper.exs`, invoke `ExUnit.start(formatters: [JUnitFormatter, ExUnit.CLIFormatter])` and ensure `Application.put_env(:junit_formatter, ...)` not needed elsewhere.

**Step 2:** Append to `config/test.exs`:
```elixir
config :junit_formatter,
  report_dir: "test_results",
  automatic_create_dir?: true,
  include_filename?: true

config :excoveralls,
  coverage_options: [treat_no_relevant_lines_as_covered: true]
```
Confirm no duplicate configs exist.

**Step 3:** Run `cd net_auto && MIX_ENV=test mix test --max-failures 1` to ensure formatter config loads (expect PASS or known failures noted).

**Step 4:** Stage updated configs (`git add net_auto/config/test.exs net_auto/test/test_helper.exs`).

---

### Task 3: Add CI Helper Scripts

**Files:**
- Create: `scripts/ci/coverage_gate.sh`
- Create: `scripts/ci/detect_changed_paths.sh`

**Step 1:** Create `scripts/ci/coverage_gate.sh` with `#!/usr/bin/env bash`, `set -euo pipefail`, usage check (`threshold json_path`), ensure `jq` availability (install instructions message if missing), extract coverage (`jq -r '.metrics.covered_percent'`), compare with threshold, exit 1 if below.

**Step 2:** Mark script executable (`chmod +x scripts/ci/coverage_gate.sh`).

**Step 3:** Create `scripts/ci/detect_changed_paths.sh` that diffs against `origin/main...HEAD`, defines allowlist (`docs/`, `README.md`, etc.), exits 0 with message if only allowlisted paths changed, else exits 1 (CircleCI job can `|| true`). Include `set -euo pipefail` and helpful logging.

**Step 4:** Mark script executable (`chmod +x scripts/ci/detect_changed_paths.sh`).

**Step 5:** Stage scripts (`git add scripts/ci/coverage_gate.sh scripts/ci/detect_changed_paths.sh`).

---

### Task 4: Create CircleCI Config with Parameterized Pipelines

**Files:**
- Create: `.circleci/config.yml`

**Step 1:** Define pipeline parameters `docker_push` (boolean, default false), `parallel_tests` (integer, default 4), `pg_version` (string, default "16.3"), `elixir_image_tag` (string, default `1.19-node` variant, e.g., `1.19.0-node`).

**Step 2:** Declare reusable commands for checkout/setup, cache restoration/saving, database wait, and workspace attach. Ensure `working_directory: ~/project/net_auto` globally.

**Step 3:** Implement jobs `setup`, `deps`, `lint`, `dialyzer`, `security`, `test`, `build_release`, `docker_build_push`, `deploy_stub`. Include caching, env vars, Postgres service definition (`POSTGRES_USER=postgres`, etc.), timing-based test splitting, JUnit storage, and GHCR login/push (context `netauto-ci`).

**Step 4:** Configure workflows `ci`, `nightly`, and `release` with appropriate filters, parameters (e.g., nightly sets `parallel_tests: 8`), and approval before `deploy_stub`.

**Step 5:** Validate YAML locally with `circleci config validate .circleci/config.yml` (requires CLI; otherwise ensure syntax via `yamllint`). Note results.

**Step 6:** Stage config (`git add .circleci/config.yml`).

---

### Task 5: Documentation (CI + MCP + README Badges)

**Files:**
- Create: `docs/ci.md`
- Create: `docs/mcp.md`
- Modify: `README.md`

**Step 1:** Write `docs/ci.md` covering workflows, required CircleCI contexts (step-by-step creation of `netauto-ci` with `GHCR_PAT`, `SOBELOW_CONFIG`, etc.), environment variables, pipeline parameters, and instructions for timing data, artifacts, and auto-cancel configuration.

**Step 2:** Write `docs/mcp.md` describing the CircleCI MCP Server usage, sample commands/prompts, client configuration snippets (Claude/Cursor/Windsurf), and reminders about secrets staying in CircleCI contexts.

**Step 3:** Update `README.md` with badges (CircleCI status, Coveralls/ExCoveralls link, last GitHub release). Add an "AI + CI" section linking to both docs and summarizing MCP + CI workflow.

**Step 4:** Stage documentation updates (`git add docs/ci.md docs/mcp.md README.md`).

---

### Task 6: Optional Docker Assets for CI Parity

**Files:**
- Create: `Dockerfile`
- Create: `docker-compose.ci.yml`

**Step 1:** Author multi-stage Dockerfile: builder uses `hexpm/elixir:1.19.0-erlang-27.0-debian-bookworm` (with Node/Yarn) to install deps, compile assets, run `mix release`; final stage based on `gcr.io/distroless/base-debian12` (or `debian:bookworm-slim`) copying release.

**Step 2:** Include runtime env vars (`PHX_SERVER=true`, `SECRET_KEY_BASE`, `DATABASE_URL`). Document `ENTRYPOINT` pointing to `bin/net_auto start`.

**Step 3:** Create `docker-compose.ci.yml` that starts app container using the local Dockerfile and a postgres service mirroring CircleCI settings. Include `depends_on` with healthcheck/wait.

**Step 4:** Stage new files (`git add Dockerfile docker-compose.ci.yml`).

---

### Task 7: Verification & Cleanup

**Files:** N/A

**Step 1:** Run `cd net_auto && mix format` to ensure formatting.

**Step 2:** Execute targeted checks locally if feasible: `mix credo --strict`, `mix test`, `mix coveralls.json`, `scripts/ci/coverage_gate.sh 85 net_auto/cover/excoveralls.json` (adjust paths as needed). Document any failures if tests require services not available locally.

**Step 3:** Confirm scripts executable (`ls -l scripts/ci`).

**Step 4:** Review git status (`git status -sb`) ensuring only expected files changed.

**Step 5:** Prepare for commit (message `ci(circleci): full pipeline with parallel tests, security gates, MCP integration`).
