#!/usr/bin/env bash
# Installs JetBrainsMono Nerd Font (same release as the dotfiles) into
# ~/.local/share/fonts so the browser can use it. Skipped if already installed.
set -euo pipefail

NF_VERSION=v3.4.0
SHA256=ef552a3e638f25125c6ad4c51176a6adcdce295ab1d2ffacf0db060caf8c1582
FAMILY="JetBrainsMono Nerd Font Mono"
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/JetBrainsMonoNerdFont"

if command -v fc-list >/dev/null && fc-list : family | grep -qF "$FAMILY"; then
  echo "$FAMILY already installed"
  exit 0
fi

echo "Downloading JetBrainsMono Nerd Font $NF_VERSION"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/font.tar.xz" \
  "https://github.com/ryanoasis/nerd-fonts/releases/download/$NF_VERSION/JetBrainsMono.tar.xz"
echo "$SHA256  $tmp/font.tar.xz" | sha256sum -c --status || { echo "error: font checksum mismatch" >&2; exit 1; }
mkdir -p "$DEST"
tar -xJf "$tmp/font.tar.xz" -C "$DEST" --wildcards '*.ttf' OFL.txt
if command -v fc-cache >/dev/null; then fc-cache -f "$DEST"; fi
echo "Installed $FAMILY to $DEST (restart the browser if it was open)"
