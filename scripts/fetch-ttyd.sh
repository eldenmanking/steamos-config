#!/usr/bin/env bash
# Downloads the pinned static ttyd release to bin/ttyd and verifies its checksum.
set -euo pipefail

TTYD_VERSION=1.7.7
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_DIR/bin/ttyd"

case "$(uname -m)" in
  x86_64) ASSET=ttyd.x86_64 SHA256=8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55 ;;
  aarch64) ASSET=ttyd.aarch64 SHA256=b38acadd89d1d396a0f5649aa52c539edbad07f4bc7348b27b4f4b7219dd4165 ;;
  *) echo "error: no ttyd build pinned for $(uname -m)" >&2; exit 1 ;;
esac

if [ -x "$DEST" ] && echo "$SHA256  $DEST" | sha256sum -c --status; then
  echo "ttyd $TTYD_VERSION already present: $DEST"
  exit 0
fi

echo "Downloading ttyd $TTYD_VERSION ($ASSET)"
tmp="$(mktemp "$DEST.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
curl -fsSL -o "$tmp" "https://github.com/tsl0922/ttyd/releases/download/$TTYD_VERSION/$ASSET"
echo "$SHA256  $tmp" | sha256sum -c --status || { echo "error: ttyd checksum mismatch" >&2; exit 1; }
chmod +x "$tmp"
mv "$tmp" "$DEST"
trap - EXIT
echo "Installed $DEST"
