#!/usr/bin/env bash
# Installs home-units.service system-wide (run as root). It starts the user units
# in an encrypted home directory once dirlock unlocks it; see the unit file.
# A SteamOS keep list makes both files survive OS updates.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "error: run as root: sudo bash $0" >&2; exit 1; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

install -Dm644 "$REPO_DIR/systemd/home-units.service" /etc/systemd/user/home-units.service
install -Dm644 "$REPO_DIR/systemd/home-units.keep.conf" /etc/atomic-update.conf.d/home-units.conf
systemctl --global enable home-units.service

echo "Installed. From the next login on, units in your home directory start"
echo "once it is unlocked. Check with: systemctl --user status home-units.service"
