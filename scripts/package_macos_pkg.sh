#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT/dist"
NAME="linuxfsagent"
VERSION_RAW="${1:-}"

if [[ -z "$VERSION_RAW" ]]; then
  echo "Usage: $0 <version-tag>  (example: v0.1.6)" >&2
  exit 1
fi
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "macOS pkg packaging must be run on macOS." >&2
  exit 1
fi
if ! command -v pkgbuild >/dev/null 2>&1; then
  echo "pkgbuild not found (Xcode CLT required)." >&2
  exit 1
fi
if ! command -v lipo >/dev/null 2>&1; then
  echo "lipo not found (Xcode CLT required)." >&2
  exit 1
fi

VERSION_PKG="${VERSION_RAW#v}"
PKG_NAME="${NAME}-${VERSION_RAW}-macos-universal.pkg"
PKG_PATH="$DIST_DIR/$PKG_NAME"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$DIST_DIR" "$TMP_DIR/stage/usr/local/bin" "$TMP_DIR/stage/usr/local/etc/linuxfsagent" "$TMP_DIR/stage/Library/LaunchDaemons"

(
  cd "$ROOT"
  CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -trimpath -ldflags='-s -w' -o "$TMP_DIR/linuxfsagent-amd64" ./cmd/linuxfsagent
  CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -trimpath -ldflags='-s -w' -o "$TMP_DIR/linuxfsagent-arm64" ./cmd/linuxfsagent
)

lipo -create -output "$TMP_DIR/stage/usr/local/bin/linuxfsagent" "$TMP_DIR/linuxfsagent-amd64" "$TMP_DIR/linuxfsagent-arm64"
chmod 0755 "$TMP_DIR/stage/usr/local/bin/linuxfsagent"

cp "$ROOT/packaging/.env.example" "$TMP_DIR/stage/usr/local/etc/linuxfsagent/.env.example"
chmod 0644 "$TMP_DIR/stage/usr/local/etc/linuxfsagent/.env.example"

cp "$ROOT/packaging/macos/com.javiermugueta.linuxfsagent.plist" "$TMP_DIR/stage/Library/LaunchDaemons/com.javiermugueta.linuxfsagent.plist"
chmod 0644 "$TMP_DIR/stage/Library/LaunchDaemons/com.javiermugueta.linuxfsagent.plist"

pkgbuild \
  --root "$TMP_DIR/stage" \
  --scripts "$ROOT/packaging/macos/scripts" \
  --identifier "com.javiermugueta.linuxfsagent" \
  --version "$VERSION_PKG" \
  --install-location "/" \
  "$PKG_PATH"

echo "[ok] $PKG_PATH"
