#!/usr/bin/env bash
# TODO(andywang): add comment
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$REPO_DIR/install"

for f in "$INSTALL_DIR"/lib/*.sh "$INSTALL_DIR"/features/*.sh; do
  # shellcheck source=/dev/null
  source "$f"
done

usage() {
  local feature
  cat <<EOF
Usage: $(basename "$0") [--all] [--FEATURE...] [--no-FEATURE...] [OPTIONS]

Installs webterm. All operations are idempotent. See README.md for more information.

Features:
EOF
  for feature in $FEATURES; do
    printf '  --%-14s %s\n' "$feature" "$(feature_description "$feature")"
  done
  cat <<EOF

Options:
  --all            install all features
  --no-FEATURE     skip FEATURE (e.g. with --all)
  --no-service     skip webterm and home-units: only download ttyd (and the font)
  --uninstall      uninstall the selected features instead
  --dry-run        print what would happen without making changes
  --help           show this help page
EOF
}

usage_error() {
  warn "$1"
  usage >&2
  exit 2
}

parse_args() {
  local flags=" " skip=" " all=false uninstall=false dry_run=false help=false

  [[ $# -gt 0 ]] || help=true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all)        all=true ;;
      --uninstall)  uninstall=true ;;
      --dry-run)    dry_run=true ;;
      --help|-h)    help=true ;;
      --no-service) skip+="webterm home-units " ;;
      --no-?*)      skip+="${1#--no-} " ;;
      --?*)         flags+="${1#--} " ;;
      *)            usage_error "Unexpected argument: $1" ;;
    esac
    shift
  done

  _flags="$flags"
  _skip="$skip"
  _all="$all"
  _uninstall="$uninstall"
  _dry_run="$dry_run"
  _help="$help"
}

resolve_features() {
  local flags="$1" skip="$2" all="$3" uninstall="$4" wanted=" " enabled=" " k

  for k in $flags $skip; do
    list_contains "$FEATURES" "$k" || usage_error "Unknown option: --$k"
  done
  for k in $FEATURES; do
    if { list_contains "$flags" "$k" || $all; } && ! list_contains "$skip" "$k"; then
      wanted+="$k "
      if ! $uninstall; then
        f_write_args feature_dependencies _dependencies -- "$k"
        wanted+="$_dependencies "
      fi
    fi
  done
  for k in $FEATURES; do
    list_contains "$wanted" "$k" && enabled+="$k "
  done

  _enabled="$enabled"
}

check_requirements() {
  local enabled="$1" commands="" feature
  for feature in $enabled; do
    f_write_args feature_requirements _commands -- "$feature"
    commands+=" $_commands"
  done
  # shellcheck disable=SC2086
  f_write_args missing_commands _missing -- $commands
  [[ -z "$_missing" ]] || error "missing: $_missing"
}

run_features() {
  local enabled="$1" uninstall="$2" order="" feature fn

  for feature in $FEATURES; do
    list_contains "$enabled" "$feature" || continue
    if $uninstall; then order="$feature${order:+ }$order"; else order+="${order:+ }$feature"; fi
  done
  for feature in $order; do
    if $uninstall; then
      fn="$(uninstall_feature_function "$feature")"
      if ! declare -F "$fn" >/dev/null; then
        info "Nothing to uninstall for $feature"
        continue
      fi
    else
      fn="$(feature_function "$feature")"
    fi
    "$fn"
  done
}

print_manual_run() {
  local enabled="$1" uninstall="$2"
  $uninstall && return
  list_contains "$enabled" ttyd && ! list_contains "$enabled" webterm || return 0
  info "Done. Run it manually with:"
  info "  '$TTYD_BIN' -i 127.0.0.1 -p 3000 -W -O '$REPO_DIR/bin/webterm-shell'"
}

main() {
  f_write_args parse_args _flags _skip _all _uninstall _dry_run _help -- "$@"
  readonly DRY_RUN="$_dry_run"

  if $_help || { [[ "$_flags" == " " ]] && ! $_all; }; then
    usage
    exit 0
  fi

  f_write_args resolve_features _enabled -- "$_flags" "$_skip" "$_all" "$_uninstall"
  $_uninstall || check_requirements "$_enabled"
  run_features "$_enabled" "$_uninstall"
  print_manual_run "$_enabled" "$_uninstall"
}

main "$@"
