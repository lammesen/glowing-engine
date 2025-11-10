#!/bin/sh
set -euo pipefail

DEVICE_USERNAME=${DEVICE_USERNAME:-netops}
DEVICE_PASSWORD=${DEVICE_PASSWORD:-netops}
DEVICE_HOSTNAME=${DEVICE_HOSTNAME:-sim-router}
DEVICE_SITE=${DEVICE_SITE:-LAB}
DEVICE_MGMT_IP=${DEVICE_MGMT_IP:-10.0.0.1}
DEVICE_DATA_PATH=${DEVICE_DATA_PATH:-/data}
CLI_SHELL=${CLI_SHELL:-/usr/local/bin/cli-server}
DEVICE_HOME="/home/$DEVICE_USERNAME"
SSH_DIR="$DEVICE_HOME/.ssh"

mkdir -p "$DEVICE_DATA_PATH"

if [ ! -f "$DEVICE_DATA_PATH/device.yml" ]; then
  cat <<YAML > "$DEVICE_DATA_PATH/device.yml"
hostname: ${DEVICE_HOSTNAME}
site: ${DEVICE_SITE}
mgmt_ip: ${DEVICE_MGMT_IP}
commands: {}
YAML
fi

# Configure hostname/banner
printf '%s\n' "$DEVICE_HOSTNAME" > /etc/hostname
printf 'Welcome to %s (site %s)\n' "$DEVICE_HOSTNAME" "$DEVICE_SITE" > /etc/motd

# Generate host keys on first boot
ssh-keygen -A >/dev/null 2>&1

# Ensure group/user exist
if ! getent group "$DEVICE_USERNAME" >/dev/null 2>&1; then
  addgroup -S "$DEVICE_USERNAME"
fi

if ! id "$DEVICE_USERNAME" >/dev/null 2>&1; then
  adduser -S -D -G "$DEVICE_USERNAME" -h "$DEVICE_HOME" -s "$CLI_SHELL" "$DEVICE_USERNAME"
fi

echo "$DEVICE_USERNAME:$DEVICE_PASSWORD" | chpasswd
mkdir -p "$DEVICE_HOME"
chown -R "$DEVICE_USERNAME:$DEVICE_USERNAME" "$DEVICE_HOME" || true
chown -R "$DEVICE_USERNAME:$DEVICE_USERNAME" "$DEVICE_DATA_PATH" || true
chmod 700 "$DEVICE_HOME"

if [ -n "${AUTHORIZED_KEY:-}" ]; then
  mkdir -p "$SSH_DIR"
  printf '%s\n' "$AUTHORIZED_KEY" > "$SSH_DIR/authorized_keys"
  chmod 600 "$SSH_DIR/authorized_keys"
  chown -R "$DEVICE_USERNAME:$DEVICE_USERNAME" "$SSH_DIR"
fi

# Launch sshd in foreground
exec /usr/sbin/sshd -D -e
