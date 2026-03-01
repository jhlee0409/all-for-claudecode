#!/bin/bash
set -euo pipefail

# afc-sync-cache.sh — Sync source files to plugin cache directory
# Used during development to keep the cache in sync with source changes.

cleanup() { :; }
trap cleanup EXIT

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Read version from package.json
if command -v jq >/dev/null 2>&1; then
  VERSION=$(jq -r '.version' "$PROJECT_ROOT/package.json")
else
  VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROJECT_ROOT/package.json" | head -1 | sed 's/.*: *"//;s/"//')
fi

if [ -z "$VERSION" ]; then
  printf 'Error: could not read version from package.json\n' >&2
  exit 1
fi

CACHE_DIR="$HOME/.claude/plugins/cache/all-for-claudecode/afc/$VERSION"

if [ ! -d "$CACHE_DIR" ]; then
  printf 'Cache directory not found: %s\n' "$CACHE_DIR" >&2
  printf 'Plugin may not be installed yet. Install first: claude plugin install afc@all-for-claudecode\n' >&2
  exit 1
fi

# Sync directories and files
DIRS_TO_SYNC="commands agents scripts hooks docs schemas templates"
FILES_TO_SYNC="package.json"

for dir in $DIRS_TO_SYNC; do
  if [ -d "$PROJECT_ROOT/$dir" ]; then
    rsync -a --delete "$PROJECT_ROOT/$dir/" "$CACHE_DIR/$dir/"
  fi
done

for file in $FILES_TO_SYNC; do
  if [ -f "$PROJECT_ROOT/$file" ]; then
    cp "$PROJECT_ROOT/$file" "$CACHE_DIR/$file"
  fi
done

printf 'Synced source to cache: %s\n' "$CACHE_DIR"
