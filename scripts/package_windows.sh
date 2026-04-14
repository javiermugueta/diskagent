#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT/dist"
NAME="linuxfsagent"
VERSION="${1:-$(date +%Y%m%d-%H%M%S)}"

mkdir -p "$DIST_DIR"

build_target() {
  local arch="$1"
  local out_dir="$DIST_DIR/${NAME}-${VERSION}-windows-${arch}"
  local zip_file="$DIST_DIR/${NAME}-${VERSION}-windows-${arch}.zip"

  rm -rf "$out_dir"
  mkdir -p "$out_dir"

  echo "[build] windows/${arch}"
  (
    cd "$ROOT"
    CGO_ENABLED=0 GOOS=windows GOARCH="$arch" \
      go build -trimpath -ldflags='-s -w' -o "$out_dir/${NAME}.exe" ./cmd/linuxfsagent
  )

  cp "$ROOT/README.md" "$out_dir/README.md"
  cp "$ROOT/packaging/.env.example" "$out_dir/.env.example"
  cp "$ROOT/packaging/windows/run-windows.ps1" "$out_dir/run-windows.ps1"
  cp "$ROOT/packaging/windows/install-windows.ps1" "$out_dir/install-windows.ps1"
  cp "$ROOT/packaging/windows/uninstall-windows.ps1" "$out_dir/uninstall-windows.ps1"

  (
    cd "$DIST_DIR"
    rm -f "$(basename "$zip_file")"
    zip -rq "$(basename "$zip_file")" "$(basename "$out_dir")"
  )

  echo "[ok] $zip_file"
}

build_target amd64
build_target arm64

echo "Artifacts:"
ls -lh "$DIST_DIR"/*windows-*.zip
