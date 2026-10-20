# Helpers for functions that return values through _<name> output variables.

F_NULL='<<null>>'

# Reset each named output to F_NULL.
f_prepare_args() {
  local out
  for out in "$@"; do
    printf -v "$out" '%s' "$F_NULL"
  done
}

# Error if any named output was not set by function fn.
f_end() {
  local fn="$1" out
  shift
  for out in "$@"; do
    if [[ -z "${!out+x}" || "${!out}" == "$F_NULL" ]]; then
      error "$fn: output '$out' was not initialized"
    fi
  done
}

# TODO(andywang): update comment
f_write_args() {
  local fn="$1" outs=""
  shift
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    [[ "$1" == _[!_]* ]] || error "f_write_args $fn: output '$1' must start with a single underscore"
    outs+="${outs:+ }$1"
    shift
  done
  [[ $# -gt 0 ]] && shift
  [[ -n "$outs" ]] || error "f_write_args $fn: no outputs given"
  f_prepare_args $outs
  "$fn" "$@"
  f_end "$fn" $outs
}

# Return 0 if space-separated list $1 contains word $2.
list_contains() {
  case " $1 " in
    *" $2 "*) return 0 ;;
    *)        return 1 ;;
  esac
}
