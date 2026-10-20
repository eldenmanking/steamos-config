# TODO(andywang): add comment

WEBTERM_UNIT_DIR="$HOME/.config/systemd/user"
WEBTERM_CONF_DIR="$HOME/.config/webterm"
WEBTERM_ENV="$WEBTERM_CONF_DIR/env"
WEBTERM_SOCKET="$REPO_DIR/systemd/webterm.socket"
WEBTERM_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/webterm"
WEBTERM_SERVICES=(webterm.service webterm-ttyd.service)

# TODO(andywang): add comment
find_proxyd() {
  local p
  _proxyd=""
  for p in /usr/lib/systemd/systemd-socket-proxyd /lib/systemd/systemd-socket-proxyd; do
    [[ -x "$p" ]] && _proxyd="$p" && break
  done
}

# TODO(andywang): add comment
webterm_url() {
  local token="$1" listen
  listen="$(sed -n 's/^ListenStream=//p' "$WEBTERM_SOCKET")"
  _url="http://$listen/${token:+$token/}"
}

# Secret URL path: keeps other sites (incl. DNS rebinding) from finding the shell
ensure_token() {
  local token
  if [[ -f "$WEBTERM_ENV" ]]; then
    token="$(sed -n 's/^WEBTERM_TOKEN=//p' "$WEBTERM_ENV")"
  else
    token="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
    run mkdir -p "$WEBTERM_CONF_DIR"
    (umask 077 && printf 'WEBTERM_TOKEN=%s\n' "$token" | write_file "$WEBTERM_ENV")
  fi
  _token="$token"
}

# TODO(andywang): add comment
install_webterm_units() {
  local proxyd="$1"
  run mkdir -p "$WEBTERM_UNIT_DIR"
  render_template "$REPO_DIR/systemd/webterm.service.template" "PROXYD=$proxyd" \
    | write_file "$WEBTERM_UNIT_DIR/webterm.service"
  render_template "$REPO_DIR/systemd/webterm-ttyd.service.template" "REPO_DIR=$REPO_DIR" \
    | write_file "$WEBTERM_UNIT_DIR/webterm-ttyd.service"
  run cp "$WEBTERM_SOCKET" "$WEBTERM_UNIT_DIR/webterm.socket"
}

# Poke the socket once to prove activation works (it exits again when idle)
check_socket_activation() {
  local url="$1"
  if $DRY_RUN; then
    info "[dry-run] would check that $url answers"
  elif curl -fsS --noproxy '*' -o /dev/null --max-time 10 "$url"; then
    info "Check: $url answered, socket activation works."
  else
    warn "$url did not answer; see: journalctl --user -u webterm.service -u webterm-ttyd.service"
  fi
}

feature_webterm() {
  systemctl --user show-environment >/dev/null 2>&1 \
    || error "no systemd user session (log in graphically or via ssh, not su/sudo)"

  f_write_args find_proxyd _proxyd
  [[ -n "$_proxyd" ]] || error "systemd-socket-proxyd not found"
  run "$REPO_DIR/bin/webterm-index" \
    || warn "could not build the webterm page; ttyd will serve its stock page"
  f_write_args ensure_token _token
  install_webterm_units "$_proxyd"

  run systemctl --user daemon-reload
  run systemctl --user enable --now webterm.socket
  # If it's running, restart it so the new units and settings apply right away.
  # Open tabs reconnect on their own (their shells are restarted).
  run systemctl --user try-restart "${WEBTERM_SERVICES[@]}"

  f_write_args webterm_url _url -- "$_token"
  info "Installed. Open $_url"
  info "(server starts on first visit, exits when idle)"
  check_socket_activation "$_url"
}

uninstall_feature_webterm() {
  run systemctl --user disable --now webterm.socket 2>/dev/null || true
  run systemctl --user stop "${WEBTERM_SERVICES[@]}" 2>/dev/null || true
  run rm -f "$WEBTERM_UNIT_DIR/webterm.socket" "${WEBTERM_SERVICES[@]/#/$WEBTERM_UNIT_DIR/}"
  run rm -rf "$WEBTERM_STATE_DIR"
  run systemctl --user daemon-reload

  info "Uninstalled. Your URL token is kept in $WEBTERM_ENV."
}
