#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="linuxfsagent"
INSTALL_DIR="/opt/linuxfsagent"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"
RUN_USER="opc"
RUN_GROUP="opc"

if [[ "${EUID}" -ne 0 ]]; then
  echo "This script must be run as root (use sudo)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! id -u "$RUN_USER" >/dev/null 2>&1; then
  echo "Required user '$RUN_USER' does not exist." >&2
  exit 1
fi
if ! getent group "$RUN_GROUP" >/dev/null 2>&1; then
  echo "Required group '$RUN_GROUP' does not exist." >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"
install -m 0755 "$SCRIPT_DIR/linuxfsagent" "$INSTALL_DIR/linuxfsagent"
install -m 0755 "$SCRIPT_DIR/run-linuxfsagent.sh" "$INSTALL_DIR/run-linuxfsagent.sh"

if [[ -f "$SCRIPT_DIR/.env" ]]; then
  install -m 0640 "$SCRIPT_DIR/.env" "$INSTALL_DIR/.env"
elif [[ -f "$SCRIPT_DIR/.env.example" ]]; then
  if [[ ! -f "$INSTALL_DIR/.env" ]]; then
    install -m 0640 "$SCRIPT_DIR/.env.example" "$INSTALL_DIR/.env"
    echo "Created $INSTALL_DIR/.env from .env.example. Update it before enabling OCI output."
  fi
fi

install -m 0644 "$SCRIPT_DIR/linuxfsagent.service" "$SERVICE_PATH"
chown -R "$RUN_USER:$RUN_GROUP" "$INSTALL_DIR"

systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"
systemctl status "$SERVICE_NAME" --no-pager -l || true

echo

echo "Installed $SERVICE_NAME"
echo "Config:    $INSTALL_DIR/.env"
echo "Service:   $SERVICE_PATH"
echo "Logs:      journalctl -u $SERVICE_NAME -f"
