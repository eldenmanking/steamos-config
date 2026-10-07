#!/usr/bin/env bash
set -euo pipefail

UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

systemctl --user disable --now kbrepeat.service 2>/dev/null || true
rm -f "$UNIT_DIR/kbrepeat.service"
systemctl --user daemon-reload

echo "Uninstalled. Settings in ${XDG_CONFIG_HOME:-$HOME/.config}/kbrepeat/env are kept."
