#!/usr/bin/env bash
set -euo pipefail

UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

systemctl --user disable --now webterm.socket 2>/dev/null || true
systemctl --user stop webterm.service webterm-ttyd.service 2>/dev/null || true
rm -f "$UNIT_DIR/webterm.socket" "$UNIT_DIR/webterm.service" "$UNIT_DIR/webterm-ttyd.service"
rm -f "$UNIT_DIR/webterm-ttyd.service.d/tmux.conf"
systemctl --user daemon-reload

echo "Uninstalled. Your URL token is kept in ${XDG_CONFIG_HOME:-$HOME/.config}/webterm/env."
