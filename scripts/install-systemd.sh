#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NODE_BIN="$(command -v node)"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

mkdir -p "$UNIT_DIR"
sed -e "s|__REPO_DIR__|$REPO_DIR|g" -e "s|__NODE__|$NODE_BIN|g" \
  "$REPO_DIR/systemd/webterm.service.template" > "$UNIT_DIR/webterm.service"
cp "$REPO_DIR/systemd/webterm.socket" "$UNIT_DIR/webterm.socket"

systemctl --user daemon-reload
systemctl --user enable --now webterm.socket

echo "Installed. Open http://localhost:3000 (server starts on first visit, exits when idle)."
