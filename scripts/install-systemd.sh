#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/webterm"

PROXYD=""
for p in /usr/lib/systemd/systemd-socket-proxyd /lib/systemd/systemd-socket-proxyd; do
  [ -x "$p" ] && PROXYD="$p" && break
done
[ -n "$PROXYD" ] || { echo "error: systemd-socket-proxyd not found" >&2; exit 1; }

bash "$REPO_DIR/scripts/fetch-ttyd.sh"

# Secret URL path: keeps other sites (incl. DNS rebinding) from finding the shell
mkdir -p "$CONF_DIR"
if [ ! -f "$CONF_DIR/env" ]; then
  token="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
  (umask 077 && printf 'WEBTERM_TOKEN=%s\n' "$token" > "$CONF_DIR/env")
fi
# shellcheck disable=SC1091
. "$CONF_DIR/env"

mkdir -p "$UNIT_DIR"
sed -e "s|__PROXYD__|$PROXYD|g" "$REPO_DIR/systemd/webterm.service.template" > "$UNIT_DIR/webterm.service"
sed -e "s|__REPO_DIR__|$REPO_DIR|g" "$REPO_DIR/systemd/webterm-ttyd.service.template" > "$UNIT_DIR/webterm-ttyd.service"
cp "$REPO_DIR/systemd/webterm.socket" "$UNIT_DIR/webterm.socket"

systemctl --user daemon-reload
# Pick up changed units on re-install
systemctl --user stop webterm.service webterm-ttyd.service 2>/dev/null || true
systemctl --user enable --now webterm.socket

echo "Installed. Open http://localhost:3000/${WEBTERM_TOKEN:+$WEBTERM_TOKEN/}"
echo "(server starts on first visit, exits when idle)"
