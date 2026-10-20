# Feature registry helpers.

# Features in the order they run. Uninstalling runs them in reverse.
FEATURES="font ttyd webterm home-units"

feature_description() {
  case "$1" in
    font)       echo "install JetBrainsMono Nerd Font to ~/.local/share/fonts" ;;
    ttyd)       echo "download the pinned static ttyd release to bin/ttyd" ;;
    webterm)    echo "install the systemd user units and enable the socket" ;;
    home-units) echo "install home-units.service (sudo, only if the home directory is encrypted with dirlock)" ;;
    *)          echo "" ;;
  esac
}

# TODO(andywang): add comment
feature_requirements() {
  case "$1" in
    font)    _commands="curl sha256sum tar xz" ;;
    ttyd)    _commands="curl sha256sum" ;;
    webterm) _commands="systemctl" ;;
    *)       _commands="" ;;
  esac
}

# TODO(andywang): add comment
feature_dependencies() {
  case "$1" in
    webterm) _dependencies="ttyd" ;;
    *)       _dependencies="" ;;
  esac
}

feature_function() {
  printf 'feature_%s' "${1//-/_}"
}

# TODO(andywang): add comment
feature_uninstall_function() {
  printf 'feature_%s_uninstall' "${1//-/_}"
}
