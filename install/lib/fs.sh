# TODO(andywang): add comment

# TODO(andywang): add comment
write_file() {
  local dest="$1"
  if $DRY_RUN; then
    info "[dry-run] would write $dest"
    cat >/dev/null
  else
    cat >"$dest"
  fi
}

# TODO(andywang): add comment
render_template() {
  local template="$1" pair args=()
  shift
  for pair in "$@"; do
    args+=(-e "s|__${pair%%=*}__|${pair#*=}|g")
  done
  sed "${args[@]}" "$template"
}

# TODO(andywang): add comment
sha256_matches() {
  local file="$1" sha256="$2"
  [[ -f "$file" ]] && echo "$sha256  $file" | sha256sum -c --status
}

# TODO(andywang): add comment
download_verified() {
  local url="$1" sha256="$2" out="$3" name="$4"
  if $DRY_RUN; then
    info "[dry-run] would download $url"
    return
  fi
  curl -fsSL -o "$out" "$url" || return 1
  sha256_matches "$out" "$sha256" || { warn "$name checksum mismatch"; return 1; }
}
