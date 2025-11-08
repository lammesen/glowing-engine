#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT_DIR/docker-compose.cisco-sim.yml}"

echo "[sim] Stopping simulator fleet"
docker compose -f "$COMPOSE_FILE" down -v
