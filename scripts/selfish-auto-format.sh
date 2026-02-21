#!/bin/bash
set -euo pipefail

# PostToolUse Hook: Auto-format changed files
# Non-blocking for Claude workflow via async: true in hooks.json
#
# Behavior: Extract file_path from stdin -> Run formatter by extension -> exit 0

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

# Read hook data from stdin
INPUT=$(cat 2>/dev/null || true)
if [ -z "$INPUT" ]; then
  exit 0
fi

# Extract file_path (jq preferred, grep/sed fallback)
if command -v jq &> /dev/null; then
  FILE_PATH=$(printf '%s\n' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
else
  FILE_PATH=$(printf '%s\n' "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
fi

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Check formatter config at project root
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Run formatter by file extension
format_file() {
  local file="$1"
  case "$file" in
    *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.scss|*.md|*.html|*.yaml|*.yml)
      # Check prettier (project-local npx or global)
      if [ -f "$PROJECT_DIR/node_modules/.bin/prettier" ]; then
        "$PROJECT_DIR/node_modules/.bin/prettier" --write "$file" 2>/dev/null || true
      elif command -v npx &> /dev/null && [ -f "$PROJECT_DIR/package.json" ]; then
        npx --no-install prettier --write "$file" 2>/dev/null || true
      fi
      ;;
    *.py)
      if command -v black &> /dev/null; then
        black --quiet "$file" 2>/dev/null || true
      elif command -v autopep8 &> /dev/null; then
        autopep8 --in-place "$file" 2>/dev/null || true
      fi
      ;;
    *.go)
      if command -v gofmt &> /dev/null; then
        gofmt -w "$file" 2>/dev/null || true
      fi
      ;;
    *.rs)
      if command -v rustfmt &> /dev/null; then
        rustfmt "$file" 2>/dev/null || true
      fi
      ;;
  esac
}

# Synchronous execution (async: true in hooks.json ensures non-blocking)
format_file "$FILE_PATH"

exit 0
