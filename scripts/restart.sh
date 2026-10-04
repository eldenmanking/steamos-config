#!/usr/bin/env bash
# Applies changes without closing the browser: re-renders the units from the
# repo, reloads ~/.config/webterm/env and restarts ttyd if it is running.
# Open tabs show "Reconnecting..." and come back with the new settings, but
# with a fresh shell: a bare shell's work ends, tmux sessions survive.
set -euo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/install-systemd.sh"
