#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version-tag>  (example: v0.1.0)" >&2
  exit 1
fi

"$ROOT/scripts/package_linux.sh" "$VERSION"

(
  cd "$ROOT/dist"
  rm -f checksums.txt
  shasum -a 256 "linuxfsagent-${VERSION}-linux-amd64.tar.gz" "linuxfsagent-${VERSION}-linux-arm64.tar.gz" > checksums.txt
)

echo "Created:"
ls -lh "$ROOT/dist/linuxfsagent-${VERSION}-linux-amd64.tar.gz" \
       "$ROOT/dist/linuxfsagent-${VERSION}-linux-arm64.tar.gz" \
       "$ROOT/dist/checksums.txt"
