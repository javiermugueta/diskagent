#!/usr/bin/env bash
set -euo pipefail

REPO="javiermugueta/diskagent"
VERSION=""

usage() {
  cat <<USAGE
Usage: curl -fsSL https://raw.githubusercontent.com/${REPO}/<tag>/install.sh | sudo bash

Options:
  --version <tag>   Install a specific release tag (e.g. v0.1.0)
  --repo <owner/repo> Override repository (default: ${REPO})
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root (sudo)." >&2
  exit 1
fi

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This installer supports Linux only." >&2
  exit 1
fi

arch="$(uname -m)"
case "$arch" in
  x86_64|amd64) pkg_arch="amd64" ;;
  aarch64|arm64) pkg_arch="arm64" ;;
  *)
    echo "Unsupported architecture: $arch" >&2
    exit 1
    ;;
esac

if [[ -z "$VERSION" ]]; then
  api="https://api.github.com/repos/${REPO}/releases/latest"
  VERSION="$(curl -fsSL "$api" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
  if [[ -z "$VERSION" ]]; then
    echo "Could not determine latest release tag from ${api}" >&2
    exit 1
  fi
fi

name="linuxfsagent-${VERSION}-linux-${pkg_arch}"
archive="${name}.tar.gz"
base="https://github.com/${REPO}/releases/download/${VERSION}"
archive_url="${base}/${archive}"
checksums_url="${base}/checksums.txt"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

curl -fL "$archive_url" -o "$tmp_dir/$archive"
curl -fL "$checksums_url" -o "$tmp_dir/checksums.txt"

if command -v sha256sum >/dev/null 2>&1; then
  (cd "$tmp_dir" && sha256sum -c checksums.txt --ignore-missing)
elif command -v shasum >/dev/null 2>&1; then
  expected="$(grep "  ${archive}$" "$tmp_dir/checksums.txt" | awk '{print $1}')"
  got="$(shasum -a 256 "$tmp_dir/$archive" | awk '{print $1}')"
  [[ "$expected" == "$got" ]] || { echo "Checksum mismatch" >&2; exit 1; }
else
  echo "sha256sum or shasum is required for checksum verification" >&2
  exit 1
fi

(cd "$tmp_dir" && tar -xzf "$archive")
cd "$tmp_dir/$name"

if [[ -f .env.example && ! -f .env ]]; then
  cp .env.example .env
fi

./install-systemd.sh
