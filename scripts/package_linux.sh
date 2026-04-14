#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT/dist"
NAME="linuxfsagent"
VERSION="${1:-$(date +%Y%m%d-%H%M%S)}"

mkdir -p "$DIST_DIR"

build_target() {
  local arch="$1"
  local out_dir="$DIST_DIR/${NAME}-${VERSION}-linux-${arch}"
  local tar_file="$DIST_DIR/${NAME}-${VERSION}-linux-${arch}.tar.gz"

  rm -rf "$out_dir"
  mkdir -p "$out_dir"

  echo "[build] linux/${arch}"
  (
    cd "$ROOT"
    CGO_ENABLED=0 GOOS=linux GOARCH="$arch" \
      go build -trimpath -ldflags='-s -w' -o "$out_dir/$NAME" ./cmd/linuxfsagent
  )

  cp "$ROOT/README.md" "$out_dir/README.md"
  cp "$ROOT/packaging/.env.example" "$out_dir/.env.example"
  cp "$ROOT/packaging/run-linuxfsagent.sh" "$out_dir/run-linuxfsagent.sh"
  cp "$ROOT/packaging/linuxfsagent.service" "$out_dir/linuxfsagent.service"
  cp "$ROOT/packaging/install-systemd.sh" "$out_dir/install-systemd.sh"
  chmod +x "$out_dir/$NAME" "$out_dir/run-linuxfsagent.sh" "$out_dir/install-systemd.sh"

  (
    cd "$DIST_DIR"
    tar -czf "$(basename "$tar_file")" "$(basename "$out_dir")"
  )

  echo "[ok] $tar_file"
}

build_target amd64
build_target arm64

echo "Artifacts:"
ls -lh "$DIST_DIR"/*.tar.gz
