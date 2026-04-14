#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version-tag>  (example: v0.1.0)" >&2
  exit 1
fi

"$ROOT/scripts/package_linux.sh" "$VERSION"
"$ROOT/scripts/package_macos.sh" "$VERSION"
"$ROOT/scripts/package_windows.sh" "$VERSION"

if [[ "$(uname -s)" == "Linux" ]] && command -v rpmbuild >/dev/null 2>&1; then
  "$ROOT/scripts/package_rpm.sh" "$VERSION" amd64
  if ! "$ROOT/scripts/package_rpm.sh" "$VERSION" arm64; then
    echo "Skipping arm64 RPM (build host/toolchain does not support aarch64 target)."
  fi
else
  echo "Skipping RPM build (requires Linux + rpmbuild)."
fi

(
  cd "$ROOT/dist"
  rm -f checksums.txt
  files=(
    "linuxfsagent-${VERSION}-linux-amd64.tar.gz"
    "linuxfsagent-${VERSION}-linux-arm64.tar.gz"
    "linuxfsagent-${VERSION}-darwin-amd64.tar.gz"
    "linuxfsagent-${VERSION}-darwin-arm64.tar.gz"
    "linuxfsagent-${VERSION}-windows-amd64.zip"
    "linuxfsagent-${VERSION}-windows-arm64.zip"
  )
  if [[ -f "linuxfsagent-${VERSION}-1.x86_64.rpm" ]]; then
    files+=("linuxfsagent-${VERSION}-1.x86_64.rpm")
  fi
  if [[ -f "linuxfsagent-${VERSION}-1.aarch64.rpm" ]]; then
    files+=("linuxfsagent-${VERSION}-1.aarch64.rpm")
  fi
  shasum -a 256 "${files[@]}" > checksums.txt
)

echo "Created:"
ls -lh "$ROOT/dist/linuxfsagent-${VERSION}-linux-amd64.tar.gz" \
       "$ROOT/dist/linuxfsagent-${VERSION}-linux-arm64.tar.gz" \
       "$ROOT/dist/linuxfsagent-${VERSION}-darwin-amd64.tar.gz" \
       "$ROOT/dist/linuxfsagent-${VERSION}-darwin-arm64.tar.gz" \
       "$ROOT/dist/linuxfsagent-${VERSION}-windows-amd64.zip" \
       "$ROOT/dist/linuxfsagent-${VERSION}-windows-arm64.zip" \
       "$ROOT/dist/checksums.txt"
if [[ -f "$ROOT/dist/linuxfsagent-${VERSION}-1.x86_64.rpm" ]]; then
  ls -lh "$ROOT/dist/linuxfsagent-${VERSION}-1.x86_64.rpm"
fi
if [[ -f "$ROOT/dist/linuxfsagent-${VERSION}-1.aarch64.rpm" ]]; then
  ls -lh "$ROOT/dist/linuxfsagent-${VERSION}-1.aarch64.rpm"
fi
