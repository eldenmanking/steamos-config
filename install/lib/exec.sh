# Command execution helpers that honor DRY_RUN.

# Execute a command, or just announce it under --dry-run.
run() {
  if $DRY_RUN; then
    printf '\033[36m[dry-run]\033[0m %s\n' "$*"
  else
    "$@"
  fi
}

# TODO(andywang): add comment
is_root() {
  [[ "$(id -u)" -eq 0 ]]
}

# TODO(andywang): add comment
missing_commands() {
  local cmd missing=""
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null || missing+="${missing:+ }$cmd"
  done
  _missing="$missing"
}
