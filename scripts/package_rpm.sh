#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT/dist"
NAME="linuxfsagent"
VERSION_RAW="${1:-}"
ARCH_RAW="${2:-amd64}"

if [[ -z "$VERSION_RAW" ]]; then
  echo "Usage: $0 <version> [amd64|arm64]" >&2
  exit 1
fi
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "RPM packaging must be run on Linux." >&2
  exit 1
fi
if ! command -v rpmbuild >/dev/null 2>&1; then
  echo "rpmbuild not found. Install rpm-build first." >&2
  exit 1
fi

case "$ARCH_RAW" in
  amd64|x86_64)
    GOARCH="amd64"
    RPM_ARCH="x86_64"
    ;;
  arm64|aarch64)
    GOARCH="arm64"
    RPM_ARCH="aarch64"
    ;;
  *)
    echo "Unsupported arch: $ARCH_RAW (use amd64|arm64)" >&2
    exit 1
    ;;
esac

VERSION_RPM="${VERSION_RAW#v}"
TOPDIR="$(mktemp -d)"
trap 'rm -rf "$TOPDIR"' EXIT

mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS} "$DIST_DIR"

CGO_ENABLED=0 GOOS=linux GOARCH="$GOARCH" \
  go build -trimpath -ldflags='-s -w' -o "$TOPDIR/SOURCES/linuxfsagent" "$ROOT/cmd/linuxfsagent"

cp "$ROOT/packaging/run-linuxfsagent.sh" "$TOPDIR/SOURCES/run-linuxfsagent.sh"
cp "$ROOT/packaging/linuxfsagent.service" "$TOPDIR/SOURCES/linuxfsagent.service"
cp "$ROOT/packaging/.env.example" "$TOPDIR/SOURCES/.env.example"

sed \
  -e "s/__VERSION__/${VERSION_RPM}/g" \
  -e "s/__RPM_ARCH__/${RPM_ARCH}/g" \
  "$ROOT/packaging/rpm/linuxfsagent.spec.in" > "$TOPDIR/SPECS/linuxfsagent.spec"

rpmbuild --define "_topdir $TOPDIR" --target "$RPM_ARCH" -bb "$TOPDIR/SPECS/linuxfsagent.spec"

RPM_OUT="$(ls "$TOPDIR/RPMS/$RPM_ARCH"/*.rpm | head -n1)"
FINAL_RPM="$DIST_DIR/${NAME}-${VERSION_RAW}-1.${RPM_ARCH}.rpm"
cp "$RPM_OUT" "$FINAL_RPM"

echo "[ok] $FINAL_RPM"
