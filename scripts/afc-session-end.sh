#!/bin/bash
set -euo pipefail
# Session End Hook: Warn about incomplete pipeline on session end
# Notify user of in-progress work when leaving the session
#
# Gap fix: Ensures resumability via /afc:resume even after session ends

# shellcheck disable=SC2329
cleanup() {
  # Extend here if temporary file cleanup is needed
  :
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PIPELINE_FLAG="${PROJECT_DIR}/.claude/.afc-active"

# Consume stdin early (required -- pipe breaks if not consumed)
INPUT=$(cat)

# If pipeline is not active -> exit silently
if [ ! -f "$PIPELINE_FLAG" ]; then
  exit 0
fi

FEATURE=$(head -1 "$PIPELINE_FLAG" | tr -d '\n\r')

# Parse reason: jq preferred, grep/sed fallback
REASON=""
if command -v jq &>/dev/null; then
  REASON=$(printf '%s\n' "$INPUT" | jq -r '.reason // empty' 2>/dev/null || true)
else
  REASON=$(printf '%s\n' "$INPUT" | grep -o '"reason"[[:space:]]*:[[:space:]]*"[^"]*"' 2>/dev/null \
    | sed 's/.*:[[:space:]]*"//;s/"$//' || true)
fi

# Compose warning message (stderr -> displayed to user in SessionEnd)
MSG="AFC PIPELINE: Session ending with feature '${FEATURE}' incomplete. Use /afc:resume to continue."
if [ -n "$REASON" ]; then
  MSG="${MSG} (end reason: ${REASON})"
fi

printf '%s\n' "$MSG" >&2

exit 0
