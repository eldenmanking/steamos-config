#!/usr/bin/env bash
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "error: run as root: sudo bash $0" >&2; exit 1; }

systemctl --global disable home-units.service 2>/dev/null || true
rm -f /etc/systemd/user/home-units.service /etc/steamos-config/home-units-start \
  /etc/atomic-update.conf.d/steamos-config.conf /etc/atomic-update.conf.d/home-units.conf
rmdir /etc/steamos-config 2>/dev/null || true

echo "Uninstalled home-units.service."
