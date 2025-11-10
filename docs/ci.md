# CircleCI Pipeline

This repository ships a production-grade CircleCI workflow tailored for the Phoenix app under `net_auto/`. All jobs execute with Elixir 1.19.x / OTP 27, Postgres 16, and deterministic caching so contributors get identical feedback locally and in CI.

## Workflows

| Workflow | Trigger | Notes |
| --- | --- | --- |
| `ci` | Every push + pull request | Runs the full gate (setup → deps → lint/security/dialyzer → test → release). Set the `docker_push` pipeline parameter to `true` when you need GHCR images on normal branches. |
| `nightly` | Cron `0 2 * * *` on `main` | Bumps `parallel_tests` to 8, re-runs deps/security/dialyzer/test/build_release to catch drift. |
| `release` | Tags matching `v*` | Forces `docker_push=true`, runs the entire pipeline, and requires a manual approval (`deploy_gate`) before the `deploy_stub` job executes. |

## Jobs & Responsibilities

- `setup`: check out into `~/project`, install `mix local.hex`/`rebar`, persist workspace.
- `deps`: restore caches, run `mix deps.get && mix deps.compile`, populate `_build` + deps caches, runs `scripts/ci/detect_changed_paths.sh` to short-circuit doc-only changes.
- `lint`: `mix compile --warnings-as-errors`, `mix format --check-formatted`, `mix credo --strict`.
- `dialyzer`: restores PLTs, builds if missing, enforces `mix dialyzer --format short`.
- `security`: `mix sobelow -i Config.HTTPS --exit` plus `mix deps.audit --format short`.
- `test`: timing-based splitting via `circleci tests split`, Postgres service (`cimg/postgres:<pg_version>`), migrations, coverage via `mix coveralls.json` on node 0 + `scripts/ci/coverage_gate.sh 85 cover/excoveralls.json`. Stores `test_results/` JUnit XML and `cover/` artifacts so CircleCI timing data stays fresh.
- `build_release`: `MIX_ENV=prod mix compile --warnings-as-errors`, `mix assets.deploy`, `mix release`; uploads `_build/prod/rel`.
- `docker_build_push`: guarded by the `docker_push` parameter, uses `setup_remote_docker`, logs into GHCR with `$GHCR_PAT`, and tags `ghcr.io/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME:$CIRCLE_SHA1`. Fallback to Docker Hub by changing the registry URL + secret.
- `deploy_stub`: placeholder job after a manual approval gate inside the `release` workflow.

## Pipeline Parameters

| Parameter | Default | Purpose |
| --- | --- | --- |
| `docker_push:boolean` | `false` | Enables `docker_build_push`. Set to `true` for release workflows or image smoke tests. |
| `parallel_tests:int` | `4` | Controls `test` job parallelism + CircleCI timing split. Nightly workflow passes `8`. |
| `pg_version:string` | `16.3` | Chooses the `cimg/postgres` tag for the DB service. |
| `elixir_image_tag:string` | `1.19.0-node` | Selects the `cimg/elixir` image (Node-enabled) so asset compilation works without Node installs. |

Trigger ad-hoc pipelines with custom parameters via `circleci pipeline trigger -p docker_push=true -p parallel_tests=6`.

## CircleCI Contexts & Secrets

Create a context named `netauto-ci` (CircleCI UI → Organization Settings → Contexts). Add the following environment variables:

| Variable | Description |
| --- | --- |
| `GHCR_PAT` | GitHub Personal Access Token with `packages:write` + `packages:read` scopes for pushing to GHCR. |
| `SOBELOW_CONFIG` | Optional path/JSON overrides for Sobelow ignore rules (leave blank to use repo defaults). |
| `MIX_ENV`, `SECRET_KEY_BASE`, etc. | Supply any extra deploy-time secrets here rather than hardcoding. |

Jobs that require the context (`docker_build_push`, future deploys) declare `context: netauto-ci`. Never commit plaintext secrets; add docs to `docs/ci.md` or `.env.sample` only.

## Deterministic Builds

- Images pinned to `cimg/elixir:<elixir_image_tag>` and `cimg/postgres:<pg_version>`.
- Mix deps + `_build` caches key off `mix.lock` checksum and Elixir tag.
- Dialyzer PLTs cached under `_build/plts` with the same keys to avoid rebuilding.
- All `mix compile` steps run with `--warnings-as-errors`.
- `scripts/ci/coverage_gate.sh` ensures overall coverage stays ≥85%; bump threshold in the script if governance changes.

## Artifacts, Timings, and Auto-cancel

- `test_results/` contains JUnit XML emitted by `JUnitFormatter`; CircleCI ingests this for timing-based splitting.
- `cover/` holds `coveralls.json`, letting you inspect exact module coverage per build.
- Enable “Auto-cancel redundant builds” in CircleCI Project Settings → Advanced so superseded PR commits stop early. This keeps shards available for active runs.

## Local Parity

- `scripts/ci/coverage_gate.sh 85 cover/excoveralls.json` enforces the same gate locally after running `mix coveralls.json`.
- `scripts/ci/detect_changed_paths.sh origin/main` lets you confirm whether a change is docs-only before pushing.
- `docker-compose.ci.yml` (optional) spins up the same Elixir + Postgres pairing locally; run `docker compose -f docker-compose.ci.yml up --build` to mimic the CI service wiring.

## Troubleshooting

- `pg_isready` loop fails → ensure Postgres container exposes `127.0.0.1` and matches `pg_version`.
- Dialyzer rebuilds every run → clear `_build/plts`, re-run `mix dialyzer --plt`, confirm cache key still matches `mix.lock` checksum.
- GHCR push errors → confirm `GHCR_PAT` scopes include `read:packages` + `write:packages` and that `docker_push` pipeline param is `true`.
- MCP introspection missing data → see `docs/mcp.md` for enabling the CircleCI MCP server; it can answer “What failed on my last build?” even when jobs run under contexts.
