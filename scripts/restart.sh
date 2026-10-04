#!/usr/bin/env bash
# Applies changes without closing the browser: re-renders the units from the
# repo, reloads ~/.config/webterm/env and restarts ttyd if it is running.
# Open tabs show "Reconnecting..." and come back with the new settings, but
# with a fresh shell: whatever was running in the old one is ended.
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/install-systemd.sh"
