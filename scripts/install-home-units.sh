#!/usr/bin/env bash
# Installs home-units.service system-wide (needs sudo). It starts the user units
# in an encrypted home directory once dirlock unlocks it; see the unit file.
# A SteamOS keep list makes both files survive OS updates.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

sudo install -Dm644 "$REPO_DIR/systemd/home-units.service" /etc/systemd/user/home-units.service
sudo install -Dm644 "$REPO_DIR/systemd/home-units.keep.conf" /etc/atomic-update.conf.d/home-units.conf
sudo systemctl --global enable home-units.service

echo "Installed. From the next login on, units in your home directory start"
echo "once it is unlocked. Check with: systemctl --user status home-units.service"
