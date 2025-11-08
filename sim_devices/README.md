# Cisco SSH Simulator Fleet

This directory contains tooling to spin up a fleet of Cisco-like SSH endpoints for NetAuto development/testing without using proprietary images.

## Contents
- `Dockerfile` – builds the simulator image
- `cli_server.py` – custom CLI shell executed on SSH login
- `entrypoint.sh` – container bootstrap script
- `commands/` – default command outputs consumed by the CLI
- `devices/` – per-device metadata files (10 ready-made nodes)
- `docker-compose.cisco-sim.yml` – launches multiple devices

## Prerequisites
- Docker Engine 24+
- docker compose v2 (`docker compose version`)

## Building the image
```bash
cd sim_devices
docker build -t netauto/cisco-sim .
```

The image installs OpenSSH on Alpine and sets `/usr/local/bin/cli-server` as the login shell for the `netops` user. Runtime configuration is handled by `entrypoint.sh` using environment variables such as `DEVICE_HOSTNAME`, `DEVICE_PASSWORD`, and `DEVICE_DATA_PATH`.

## Launching the lab
```bash
# Build the image once
cd sim_devices
docker build -t netauto/cisco-sim .

# Start all 10 nodes
docker compose -f ../docker-compose.cisco-sim.yml up -d

# Tear everything down when finished
docker compose -f ../docker-compose.cisco-sim.yml down -v
```

Each container exposes SSH on host ports `2201`–`2210` and automatically loads the per-device YAML mounted into `/data/device.yml`.
