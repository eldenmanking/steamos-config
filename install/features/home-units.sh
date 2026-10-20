# Installs home-units.service system-wide (run as root). It starts the user units
# in an encrypted home directory once dirlock unlocks it; see the unit file.
# A SteamOS keep list makes both files survive OS updates.

# TODO(andywang): add comment
HOME_UNITS_KEEP_LIST=/etc/atomic-update.conf.d/steamos-config.conf
HOME_UNITS_FILES=(
  "755 bin/home-units-start /etc/steamos-config/home-units-start"
  "644 systemd/home-units.service /etc/systemd/user/home-units.service"
  "644 systemd/home-units.keep.conf $HOME_UNITS_KEEP_LIST"
)
# Keep list name used by earlier versions
HOME_UNITS_OLD_KEEP_LIST=/etc/atomic-update.conf.d/home-units.conf

# Installed copies are compared with the repo, so updates get reinstalled too.
home_units_current() {
  local entry mode src dest
  for entry in "${HOME_UNITS_FILES[@]}"; do
    read -r mode src dest <<<"$entry"
    cmp -s "$REPO_DIR/$src" "$dest" || return 1
  done
}

# TODO(andywang): add comment
home_is_encrypted() {
  command -v dirlock >/dev/null && dirlock status "$HOME" 2>/dev/null | grep -q '^Encrypted'
}

# TODO(andywang): add comment
check_home_units_keep_list() {
  local entry mode src dest
  for entry in "${HOME_UNITS_FILES[@]}"; do
    read -r mode src dest <<<"$entry"
    [[ "$dest" == "$HOME_UNITS_KEEP_LIST" ]] && continue
    grep -qxF "$dest" "$REPO_DIR/systemd/home-units.keep.conf" \
      || error "$dest is missing from systemd/home-units.keep.conf"
  done
}

# TODO(andywang): add comment
install_home_units() {
  local entry mode src dest
  check_home_units_keep_list
  for entry in "${HOME_UNITS_FILES[@]}"; do
    read -r mode src dest <<<"$entry"
    run install -Dm"$mode" "$REPO_DIR/$src" "$dest"
  done
  run systemctl --global enable home-units.service
  run rm -f "$HOME_UNITS_OLD_KEEP_LIST"

  info "Installed. From the next login on, units in your home directory start"
  info "once it is unlocked. Check with: systemctl --user status home-units.service"
}

# With dirlock, the user manager can't see these units at boot (see README).
feature_home_units() {
  if is_root; then
    install_home_units
    return
  fi
  home_units_current && return
  home_is_encrypted || return 0

  info "Your home directory is encrypted: installing home-units.service so webterm"
  info "starts after a reboot. This writes to /etc and needs sudo."
  run sudo bash "$REPO_DIR/install.sh" --home-units \
    || warn "not installed; webterm won't start after a reboot. Retry with: sudo bash '$REPO_DIR/install.sh' --home-units"
}

feature_home_units_uninstall() {
  if ! is_root; then
    run sudo bash "$REPO_DIR/install.sh" --uninstall --home-units
    return
  fi
  local entry mode src dest dests=()
  for entry in "${HOME_UNITS_FILES[@]}"; do
    read -r mode src dest <<<"$entry"
    dests+=("$dest")
  done

  run systemctl --global disable home-units.service 2>/dev/null || true
  run rm -f "${dests[@]}" "$HOME_UNITS_OLD_KEEP_LIST"
  run rmdir /etc/steamos-config 2>/dev/null || true

  info "Uninstalled home-units.service."
}
