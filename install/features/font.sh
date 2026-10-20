# Installs JetBrainsMono Nerd Font (same release as the dotfiles) into
# ~/.local/share/fonts so the browser can use it. Skipped if already installed.

FONT_NF_VERSION=v3.4.0
FONT_SHA256=ef552a3e638f25125c6ad4c51176a6adcdce295ab1d2ffacf0db060caf8c1582
FONT_FAMILY="JetBrainsMono Nerd Font Mono"
FONT_DEST="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"

# TODO(andywang): add comment
font_installed() {
  command -v fc-list >/dev/null && fc-list : family | grep -qF "$FONT_FAMILY"
}

feature_font() {
  if font_installed; then
    info "$FONT_FAMILY already installed"
    return
  fi

  info "Downloading JetBrainsMono Nerd Font $FONT_NF_VERSION"
  local tmp
  tmp="$(mktemp -d)"
  download_verified \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/$FONT_NF_VERSION/JetBrainsMono.tar.xz" \
    "$FONT_SHA256" "$tmp/font.tar.xz" font \
    || { rm -rf "$tmp"; error "could not download the font"; }
  run mkdir -p "$FONT_DEST"
  run tar -xJf "$tmp/font.tar.xz" -C "$FONT_DEST" --wildcards '*.ttf' OFL.txt
  if command -v fc-cache >/dev/null; then run fc-cache -f "$FONT_DEST"; fi
  rm -rf "$tmp"
  info "Installed $FONT_FAMILY to $FONT_DEST (restart the browser if it was open)"
}
