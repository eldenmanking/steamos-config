#!/usr/bin/env bash
set -euo pipefail

sudo systemctl --global disable home-units.service 2>/dev/null || true
sudo rm -f /etc/systemd/user/home-units.service /etc/atomic-update.conf.d/home-units.conf

echo "Uninstalled home-units.service."
