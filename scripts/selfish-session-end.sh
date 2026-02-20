#!/bin/bash
set -euo pipefail
# Session End Hook: Warn about incomplete pipeline on session end
# Notify user of in-progress work when leaving the session
#
# Gap fix: Ensures resumability via /selfish:resume even after session ends

# shellcheck disable=SC2329
cleanup() {
  # Extend here if temporary file cleanup is needed
  :
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PIPELINE_FLAG="${PROJECT_DIR}/.claude/.selfish-active"

# If pipeline is not active -> exit silently
if [ ! -f "$PIPELINE_FLAG" ]; then
  exit 0
fi

FEATURE=$(head -1 "$PIPELINE_FLAG" | tr -d '\n\r')

# Read JSON from stdin
INPUT=$(cat)

# Parse reason: jq preferred, grep/sed fallback
REASON=""
if command -v jq &>/dev/null; then
  REASON=$(echo "$INPUT" | jq -r '.reason // empty' 2>/dev/null || true)
else
  REASON=$(echo "$INPUT" | grep -o '"reason"[[:space:]]*:[[:space:]]*"[^"]*"' 2>/dev/null \
    | sed 's/.*:[[:space:]]*"//;s/"$//' || true)
fi

# Compose warning message (stderr -> displayed to user in SessionEnd)
MSG="SELFISH PIPELINE: Session ending with feature '${FEATURE}' incomplete. Use /selfish:resume to continue."
if [ -n "$REASON" ]; then
  MSG="${MSG} (end reason: ${REASON})"
fi

echo "$MSG" >&2

exit 0
