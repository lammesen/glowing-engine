#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT_DIR/docker-compose.cisco-sim.yml}"
IMAGE_TAG="${SIM_IMAGE_TAG:-netauto/cisco-sim:latest}"
PORT_START=${SIM_PORT_START:-2201}
PORT_END=${SIM_PORT_END:-2210}

build_image() {
  echo "[sim] Building $IMAGE_TAG from $ROOT_DIR/sim_devices"
  docker build -t "$IMAGE_TAG" "$ROOT_DIR/sim_devices"
}

start_stack() {
  echo "[sim] Starting containers via docker compose"
  SIM_IMAGE_TAG="$IMAGE_TAG" docker compose -f "$COMPOSE_FILE" up -d
}

wait_for_ports() {
  echo "[sim] Waiting for SSH to accept connections"
  for port in $(seq "$PORT_START" "$PORT_END"); do
    for attempt in $(seq 1 30); do
      if nc -z localhost "$port" >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done
  done
}

print_summary() {
  printf "%-10s %-15s %-8s\n" "Host" "IP" "Port"
  for idx in $(seq 1 $((PORT_END - PORT_START + 1))); do
    port=$((PORT_START + idx - 1))
    printf "%-10s %-15s %-8s\n" "LAB-R${idx}" "127.0.0.1" "$port"
  done
  echo "Use username 'netops' / password 'netops'."
}

build_image
start_stack
wait_for_ports
print_summary
