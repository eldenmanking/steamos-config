# Downloads the pinned static ttyd release to bin/ttyd and verifies its checksum.

TTYD_VERSION=1.7.7
TTYD_BIN="$REPO_DIR/bin/ttyd"

# TODO(andywang): add comment
ttyd_asset() {
  case "$(uname -m)" in
    x86_64)  _asset=ttyd.x86_64  _sha256=8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55 ;;
    aarch64) _asset=ttyd.aarch64 _sha256=b38acadd89d1d396a0f5649aa52c539edbad07f4bc7348b27b4f4b7219dd4165 ;;
    *)       error "no ttyd build pinned for $(uname -m)" ;;
  esac
}

feature_ttyd() {
  f_write_args ttyd_asset _asset _sha256
  local asset="$_asset" sha256="$_sha256"

  if [[ -x "$TTYD_BIN" ]] && sha256_matches "$TTYD_BIN" "$sha256"; then
    info "ttyd $TTYD_VERSION already present: $TTYD_BIN"
    return
  fi

  info "Downloading ttyd $TTYD_VERSION ($asset)"
  local tmp
  tmp="$(mktemp "$TTYD_BIN.XXXXXX")"
  download_verified "https://github.com/tsl0922/ttyd/releases/download/$TTYD_VERSION/$asset" \
    "$sha256" "$tmp" ttyd || { rm -f "$tmp"; error "could not download ttyd"; }
  run chmod +x "$tmp"
  run mv "$tmp" "$TTYD_BIN"
  rm -f "$tmp"
  info "Installed $TTYD_BIN"
}
