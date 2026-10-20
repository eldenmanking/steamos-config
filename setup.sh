#!/usr/bin/env bash
# webterm setup: finds (or clones) the steamos-config repo, downloads the
# static ttyd binary and enables the systemd user socket on localhost:3000.
#
# If the current directory (or this script's directory) is inside the repo,
# that checkout is used. Otherwise the repo is cloned to ~/git/steamos-config.
#
# TODO(andywang): update comment
# Usage: ./setup.sh [--no-font] [--no-service] [--no-home-units]
#   --no-font        don't install JetBrainsMono Nerd Font
#   --no-service     only download ttyd (and the font); don't touch systemd
#   --no-home-units  don't install home-units.service (asked for with sudo
#                    only if the home directory is encrypted with dirlock)
#
# Env: WEBTERM_REPO_URL  clone URL (default: the GitHub repo over https)
#      WEBTERM_CLONE_DIR clone location (default: ~/git/steamos-config)
set -euo pipefail

REPO_URL="${WEBTERM_REPO_URL:-https://github.com/eldenmanking/steamos-config.git}"
CLONE_DIR="${WEBTERM_CLONE_DIR:-$HOME/git/steamos-config}"

die() { echo "error: $*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Finds (or clones) the steamos-config repo, then runs 'install.sh --all OPTIONS' in it.
Common options: --no-font, --no-service, --no-home-units, --dry-run.
Run 'install.sh --help' in the repo for all options.

Env: WEBTERM_REPO_URL  clone URL (default: the GitHub repo over https)
     WEBTERM_CLONE_DIR clone location (default: ~/git/steamos-config)
EOF
}

# Prints the checkout's top-level dir if $1 is inside the steamos-config repo.
repo_root() {
  local top
  top="$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" || return 1
  # files present in every version of the repo, so old clones get updated too
  [ -f "$top/setup.sh" ] && [ -f "$top/systemd/webterm.socket" ] && echo "$top"
}

# TODO(andywang): add comment
locate_repo() {
  local script_dir="" repo_dir
  [ -f "${BASH_SOURCE[0]:-}" ] && script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if repo_dir="$(repo_root "$PWD")"; then
    echo "Using checkout in current directory: $repo_dir"
  elif [ -n "$script_dir" ] && repo_dir="$(repo_root "$script_dir")"; then
    echo "Using checkout this script lives in: $repo_dir"
  elif repo_dir="$(repo_root "$CLONE_DIR")"; then
    echo "Using existing clone: $repo_dir"
    git -C "$repo_dir" pull --ff-only || echo "warning: git pull failed; using the checkout as-is" >&2
  else
    [ -e "$CLONE_DIR" ] && die "$CLONE_DIR exists but is not a steamos-config checkout"
    echo "Cloning $REPO_URL into $CLONE_DIR"
    mkdir -p "$(dirname "$CLONE_DIR")"
    git clone "$REPO_URL" "$CLONE_DIR"
    repo_dir="$CLONE_DIR"
  fi
  _repo_dir="$repo_dir"
}

main() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      -h|--help) usage; exit 0 ;;
    esac
  done
  command -v git >/dev/null || die "missing: git"

  locate_repo
  exec bash "$_repo_dir/install.sh" --all "$@"
}

main "$@"
