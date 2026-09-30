#!/usr/bin/env bash
# webterm setup: finds (or clones) the steamos-config repo, installs its npm
# dependencies and enables the systemd user socket for http://localhost:3000.
#
# If the current directory (or this script's directory) is inside the repo,
# that checkout is used. Otherwise the repo is cloned to ~/git/steamos-config.
#
# Usage: ./setup.sh [--tmux] [--no-service]
#   --tmux         run the shell inside tmux (sessions survive tab closes)
#   --no-service   only install npm dependencies; don't touch systemd
#
# Env: WEBTERM_REPO_URL  clone URL (default: the GitHub repo over https)
#      WEBTERM_CLONE_DIR clone location (default: ~/git/steamos-config)
set -euo pipefail

REPO_URL="${WEBTERM_REPO_URL:-https://github.com/eldenmanking/steamos-config.git}"
CLONE_DIR="${WEBTERM_CLONE_DIR:-$HOME/git/steamos-config}"
TMUX_MODE=0
SERVICE=1
while [ $# -gt 0 ]; do
  case "$1" in
    --tmux) TMUX_MODE=1; shift ;;
    --no-service) SERVICE=0; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }

# --- prerequisites -----------------------------------------------------------
missing=()
command -v git >/dev/null || missing+=(git)
command -v node >/dev/null || missing+=(nodejs)
command -v npm >/dev/null || missing+=(npm)
command -v make >/dev/null || missing+=(make)
command -v g++ >/dev/null || command -v c++ >/dev/null || missing+=(g++)
command -v python3 >/dev/null || missing+=(python)
if [ "$TMUX_MODE" = 1 ]; then command -v tmux >/dev/null || missing+=(tmux); fi
if [ ${#missing[@]} -gt 0 ]; then
  echo "Missing: ${missing[*]}" >&2
  echo "node-pty compiles a native module, so build tools are required." >&2
  echo "  Arch:    sudo pacman -S --needed git base-devel python nodejs npm tmux" >&2
  echo "  SteamOS: see 'SteamOS notes' in the README (rootfs is read-only)." >&2
  exit 1
fi
node_major="$(node -p 'process.versions.node.split(".")[0]')"
[ "$node_major" -ge 18 ] || die "Node >= 18 required (found $(node -v))"

# --- locate or clone the repo ------------------------------------------------
# Prints the checkout's top-level dir if $1 is inside the steamos-config repo.
repo_root() {
  local top
  top="$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" || return 1
  [ -f "$top/server.js" ] && grep -q '"name": "steamos-config"' "$top/package.json" 2>/dev/null \
    && echo "$top"
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

# --- install dependencies ----------------------------------------------------
echo "Installing npm dependencies (builds node-pty)..."
npm ci --no-audit --no-fund

if [ "$SERVICE" = 0 ]; then
  echo "Done. Start it manually with: cd '$REPO_DIR' && npm start"
  exit 0
fi

# --- systemd user socket -----------------------------------------------------
command -v systemctl >/dev/null || die "systemctl not found; rerun with --no-service"
systemctl --user show-environment >/dev/null 2>&1 \
  || die "no systemd user session (log in graphically or via ssh, not su/sudo)"

bash scripts/install-systemd.sh

DROPIN="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/webterm.service.d"
if [ "$TMUX_MODE" = 1 ]; then
  mkdir -p "$DROPIN"
  printf '[Service]\nEnvironment=WEBTERM_TMUX=1\n' > "$DROPIN/tmux.conf"
else
  rm -f "$DROPIN/tmux.conf"
fi
systemctl --user daemon-reload

# Poke the socket once to prove activation works (server exits again when idle)
if command -v curl >/dev/null; then
  if curl -fsS --noproxy '*' -o /dev/null --max-time 10 http://127.0.0.1:3000/; then
    echo "Check: http://localhost:3000 answered, socket activation works."
  else
    echo "warning: http://localhost:3000 did not answer; see: journalctl --user -u webterm.service" >&2
  fi
fi
systemctl --user --no-pager status webterm.socket | head -n 3 || true
