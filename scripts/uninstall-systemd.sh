#!/usr/bin/env bash
set -euo pipefail

UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

systemctl --user disable --now webterm.socket 2>/dev/null || true
systemctl --user stop webterm.service 2>/dev/null || true
rm -f "$UNIT_DIR/webterm.socket" "$UNIT_DIR/webterm.service"
systemctl --user daemon-reload

echo "Uninstalled."
