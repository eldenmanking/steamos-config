#!/usr/bin/env bash
# Installs and starts kbrepeat.service, which sets the keyboard repeat delay
# and rate each time Steam's Big Picture window becomes active.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNIT_DIR="$HOME/.config/systemd/user"

for cmd in xprop xset; do
  command -v "$cmd" >/dev/null || { echo "error: missing $cmd" >&2; exit 1; }
done

mkdir -p "$UNIT_DIR"
sed -e "s|__REPO_DIR__|$REPO_DIR|g" "$REPO_DIR/systemd/kbrepeat.service.template" > "$UNIT_DIR/kbrepeat.service"

systemctl --user daemon-reload
systemctl --user enable kbrepeat.service
# Restart so a re-install picks up changes
systemctl --user restart kbrepeat.service
echo "Installed and started kbrepeat.service"
