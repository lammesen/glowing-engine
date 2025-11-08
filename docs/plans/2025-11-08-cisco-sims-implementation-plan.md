# Cisco SSH Simulators Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Provide ten Dockerized SSH endpoints that mimic Cisco IOS CLI so NetAuto can run commands against deterministic devices without proprietary images.

**Architecture:** Build a reusable Alpine-based image running OpenSSH with a Python CLI shim as the login shell. Each container loads hostname- and command-specific YAML, exposing SSH on unique host ports via docker compose. Helper scripts seed device metadata and start/stop the lab.

**Tech Stack:** Docker, docker compose v2, python 3.12, OpenSSH server, YAML for command data, bash helper scripts.

### Task 1: Scaffolding & ignored paths

**Files:**
- Create: `sim_devices/.gitignore`
- Create: `sim_devices/README.md`

**Step 1:** Add `.gitignore` entries to keep generated keys/state out of git (`state/`, `*.log`, `.ssh/`).

**Step 2:** Write `README.md` documenting prerequisites (Docker), how to build/run, and how the CLI shim works.

**Step 3:** Commit scaffolding so future steps have a clean base (`git add sim_devices/.gitignore sim_devices/README.md && git commit -m "chore(sim): scaffold sim_devices dir"`).

### Task 2: Dockerfile & entrypoint

**Files:**
- Create: `sim_devices/Dockerfile`
- Create: `sim_devices/entrypoint.sh`
- Modify: `sim_devices/README.md`

**Step 1:** Write Dockerfile using `python:3.12-alpine`, install `openssh`, copy CLI files, expose port 22, set entrypoint.

**Step 2:** Implement `entrypoint.sh` to create the `netops` user, set password from `$DEVICE_PASSWORD`, install host keys if absent, drop per-device YAML under `/data/device.yml`, and exec `sshd -D`.

**Step 3:** Document build command in README.

**Step 4:** Commit Docker skeleton.

### Task 3: CLI simulator script

**Files:**
- Create: `sim_devices/cli_server.py`
- Create: `sim_devices/commands/base.yml`

**Step 1:** Implement Python CLI: load YAML, show IOS-style prompts, support `enable`, `configure terminal`, `show version`, `show ip interface brief`, `exit`.

**Step 2:** Ensure script is executable, installed to `/usr/local/bin/cli-server` during build.

**Step 3:** Seed default command outputs in `commands/base.yml` (structured text arrays).

**Step 4:** Rebuild image locally (`docker build -t netauto/cisco-sim sim_devices`).

**Step 5:** Commit CLI files.

### Task 4: Per-device overrides & compose file

**Files:**
- Create: `sim_devices/devices/device{1..10}.yml`
- Create: `docker-compose.cisco-sim.yml`
- Modify: `sim_devices/README.md`

**Step 1:** Author ten YAML files with fields: `hostname`, `site`, `mgmt_ip`, optional `commands` overrides.

**Step 2:** Write docker compose file defining services `cisco-sim-01`..`-10`, mapping host ports 2201-2210, mounting respective device YAMLs into `/data/device.yml`.

**Step 3:** Update README with bring-up instructions (`docker compose -f docker-compose.cisco-sim.yml up -d`).

**Step 4:** Commit device configs + compose file.

### Task 5: Helper scripts & NetAuto seeding

**Files:**
- Create: `bin/launch-cisco-sims.sh`
- Create: `bin/destroy-cisco-sims.sh`
- Modify: `net_auto/priv/repo/seeds.exs`
- Modify: `README.md`

**Step 1:** `launch` script builds the image, runs compose up, waits for SSH readiness by looping over ports with `ssh -o StrictHostKeyChecking=no` executing `show version`.

**Step 2:** `destroy` script runs `docker compose ... down -v`.

**Step 3:** Update `seeds.exs` to read a new CSV (`sim_devices/devices/devices.csv`) or embed the list directly, inserting ten devices with correct hostnames, IPs, SSH ports, `cred_ref`.

**Step 4:** Document usage in README (“Start sims”, “Seed DB”).

**Step 5:** Commit scripts + seed changes.

### Task 6: Verification & docs

**Files:**
- Modify: `docs/plans/2025-11-08-cisco-sims-design.md` (optional notes)
- Modify: `README.md`

**Step 1:** Run `bin/launch-cisco-sims.sh` and capture sample output, verifying SSH responses match expected prompts.

**Step 2:** Execute `bin/destroy-cisco-sims.sh` to ensure cleanup works.

**Step 3:** Add final README section summarizing verification steps and how teams should point NetAuto to these devices.

**Step 4:** Commit final docs and mention verification results in commit message (`feat(sim): add cisco ssh simulator fleet`).
