#!/bin/bash
set -euo pipefail
# PostToolUse Hook: Track file changes
# Record changed files after Edit/Write tool usage
# Track which files have changed for the CI gate

# shellcheck source=afc-state.sh
. "$(dirname "$0")/afc-state.sh"

# shellcheck disable=SC2329
cleanup() {
  # Placeholder for temporary resource cleanup if needed
  :
}
trap cleanup EXIT

# If pipeline is inactive -> skip
if ! afc_state_is_active; then
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
  FILE_PATH=$(printf '%s\n' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
else
  FILE_PATH=$(printf '%s\n' "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
fi

if [ -n "$FILE_PATH" ]; then
  # Append to change log (deduplicate handled by afc_state_append_change)
  afc_state_append_change "$FILE_PATH"

  # Invalidate CI results since a file was changed
  afc_state_invalidate_ci
fi

exit 0
