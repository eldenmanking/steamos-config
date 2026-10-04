#!/usr/bin/env bash
# webterm setup: finds (or clones) the steamos-config repo, downloads the
# static ttyd binary and enables the systemd user socket on localhost:3000.
#
# If the current directory (or this script's directory) is inside the repo,
# that checkout is used. Otherwise the repo is cloned to ~/git/steamos-config.
#
# Usage: ./setup.sh [--no-font] [--no-service]
#   --no-font      don't install JetBrainsMono Nerd Font
#   --no-service   only download ttyd (and the font); don't touch systemd
#
# Env: WEBTERM_REPO_URL  clone URL (default: the GitHub repo over https)
#      WEBTERM_CLONE_DIR clone location (default: ~/git/steamos-config)
set -euo pipefail

REPO_URL="${WEBTERM_REPO_URL:-https://github.com/eldenmanking/steamos-config.git}"
CLONE_DIR="${WEBTERM_CLONE_DIR:-$HOME/git/steamos-config}"
FONT=1
SERVICE=1
while [ $# -gt 0 ]; do
  case "$1" in
    --no-font) FONT=0; shift ;;
    --no-service) SERVICE=0; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }

# --- prerequisites (all part of a stock SteamOS / Arch install) --------------
missing=()
for cmd in git curl sha256sum tar xz; do
  command -v "$cmd" >/dev/null || missing+=("$cmd")
done
if [ "$SERVICE" = 1 ]; then
  command -v systemctl >/dev/null || missing+=(systemctl)
  [ -x /usr/lib/systemd/systemd-socket-proxyd ] || [ -x /lib/systemd/systemd-socket-proxyd ] \
    || missing+=(systemd-socket-proxyd)
fi
[ ${#missing[@]} -eq 0 ] || die "missing: ${missing[*]}"

# --- locate or clone the repo ------------------------------------------------
# Prints the checkout's top-level dir if $1 is inside the steamos-config repo.
repo_root() {
  local top
  top="$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" || return 1
  # files present in every version of the repo, so old clones get updated too
  [ -f "$top/setup.sh" ] && [ -f "$top/systemd/webterm.socket" ] && echo "$top"
}

SCRIPT_DIR=""
[ -f "${BASH_SOURCE[0]:-}" ] && SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if REPO_DIR="$(repo_root "$PWD")"; then
  echo "Using checkout in current directory: $REPO_DIR"
elif [ -n "$SCRIPT_DIR" ] && REPO_DIR="$(repo_root "$SCRIPT_DIR")"; then
  echo "Using checkout this script lives in: $REPO_DIR"
elif REPO_DIR="$(repo_root "$CLONE_DIR")"; then
  echo "Using existing clone: $REPO_DIR"
  git -C "$REPO_DIR" pull --ff-only || echo "warning: git pull failed; using the checkout as-is" >&2
else
  [ -e "$CLONE_DIR" ] && die "$CLONE_DIR exists but is not a steamos-config checkout"
  echo "Cloning $REPO_URL into $CLONE_DIR"
  mkdir -p "$(dirname "$CLONE_DIR")"
  git clone "$REPO_URL" "$CLONE_DIR"
  REPO_DIR="$CLONE_DIR"
fi
cd "$REPO_DIR"

if [ "$FONT" = 1 ]; then bash scripts/fetch-font.sh; fi

if [ "$SERVICE" = 0 ]; then
  bash scripts/fetch-ttyd.sh
  echo "Done. Run it manually with:"
  echo "  '$REPO_DIR/bin/ttyd' -i 127.0.0.1 -p 3000 -W -O '$REPO_DIR/bin/webterm-shell'"
  exit 0
fi

# --- systemd user socket -----------------------------------------------------
systemctl --user show-environment >/dev/null 2>&1 \
  || die "no systemd user session (log in graphically or via ssh, not su/sudo)"

bash scripts/install-systemd.sh

# Poke the socket once to prove activation works (it exits again when idle)
# shellcheck disable=SC1091
. "${XDG_CONFIG_HOME:-$HOME/.config}/webterm/env"
URL="http://127.0.0.1:3000/${WEBTERM_TOKEN:+$WEBTERM_TOKEN/}"
if curl -fsS --noproxy '*' -o /dev/null --max-time 10 "$URL"; then
  echo "Check: $URL answered, socket activation works."
else
  echo "warning: $URL did not answer; see: journalctl --user -u webterm.service -u webterm-ttyd.service" >&2
fi
