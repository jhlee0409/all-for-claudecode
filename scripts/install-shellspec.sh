#!/bin/bash
# Install ShellSpec locally to vendor/shellspec/
# Usage: bash scripts/install-shellspec.sh
set -euo pipefail

trap cleanup EXIT
cleanup() { :; }

SHELLSPEC_VERSION="0.28.1"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$PROJECT_ROOT/vendor"
SHELLSPEC_DIR="$VENDOR_DIR/shellspec"

if [ -f "$SHELLSPEC_DIR/shellspec" ]; then
  printf 'ShellSpec %s already installed at %s\n' "$SHELLSPEC_VERSION" "$SHELLSPEC_DIR"
  exit 0
fi

printf 'Installing ShellSpec %s to %s ...\n' "$SHELLSPEC_VERSION" "$SHELLSPEC_DIR"

mkdir -p "$VENDOR_DIR"

TARBALL_URL="https://github.com/shellspec/shellspec/archive/refs/tags/${SHELLSPEC_VERSION}.tar.gz"

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$TARBALL_URL" | tar -xzf - -C "$VENDOR_DIR"
elif command -v wget >/dev/null 2>&1; then
  wget -qO - "$TARBALL_URL" | tar -xzf - -C "$VENDOR_DIR"
else
  printf 'Error: curl or wget is required to install ShellSpec\n' >&2
  exit 1
fi

mv "$VENDOR_DIR/shellspec-${SHELLSPEC_VERSION}" "$SHELLSPEC_DIR"
chmod +x "$SHELLSPEC_DIR/shellspec"

printf 'ShellSpec %s installed successfully at %s\n' "$SHELLSPEC_VERSION" "$SHELLSPEC_DIR"
printf 'Run tests with: npm test\n'
