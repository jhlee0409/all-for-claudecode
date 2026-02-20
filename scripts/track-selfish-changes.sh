#!/bin/bash
set -euo pipefail
# PostToolUse Hook: Track file changes
# Record changed files after Edit/Write tool usage
# Track which files have changed for the CI gate

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PIPELINE_FLAG="$PROJECT_DIR/.claude/.selfish-active"
CHANGES_LOG="$PROJECT_DIR/.claude/.selfish-changes.log"
CI_FLAG="$PROJECT_DIR/.claude/.selfish-ci-passed"

# shellcheck disable=SC2329
cleanup() {
  # Placeholder for temporary resource cleanup if needed
  :
}
trap cleanup EXIT

# If pipeline is inactive -> skip
if [ ! -f "$PIPELINE_FLAG" ]; then
  exit 0
fi

# Parse tool input from stdin
INPUT=$(cat)

# Skip if stdin is empty
if [ -z "$INPUT" ]; then
  exit 0
fi

# Extract file_path with jq if available, otherwise grep/sed fallback
if command -v jq &> /dev/null; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
else
  FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
fi

if [ -n "$FILE_PATH" ]; then
  # Append to change log (deduplicate)
  echo "$FILE_PATH" >> "$CHANGES_LOG"
  sort -u -o "$CHANGES_LOG" "$CHANGES_LOG"

  # Invalidate CI results since a file was changed
  rm -f "$CI_FLAG"
fi

exit 0
