# Cisco SSH Simulator Fleet

This directory contains tooling to spin up a fleet of Cisco-like SSH endpoints for NetAuto development/testing without using proprietary images.

## Contents
- `Dockerfile` – builds the simulator image
- `cli_server.py` – custom CLI shell (placeholder until Task 3)
- `entrypoint.sh` – container bootstrap script
- `commands/` – default command outputs (WIP)
- `devices/` – per-device metadata files (WIP)
- `docker-compose.cisco-sim.yml` – launches multiple devices (WIP)

## Prerequisites
- Docker Engine 24+
- docker compose v2 (`docker compose version`)

## Building the image
```bash
cd sim_devices
docker build -t netauto/cisco-sim .
```

The image installs OpenSSH on Alpine and sets `/usr/local/bin/cli-server` as the login shell for the `netops` user. Runtime configuration is handled by `entrypoint.sh` using environment variables such as `DEVICE_HOSTNAME`, `DEVICE_PASSWORD`, and `DEVICE_DATA_PATH`.

## Usage (coming soon)
Instructions for defining device metadata and launching the fleet via docker compose will be documented once the remaining components are implemented.
