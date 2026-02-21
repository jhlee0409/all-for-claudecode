#!/bin/bash
set -euo pipefail
# Notification Hook: Send OS notifications on task completion and permission approval requests
# idle_prompt -> task completion notification, permission_prompt -> permission approval request notification

# shellcheck disable=SC2329
cleanup() {
  # Placeholder for temporary resource cleanup if needed
  :
}
trap cleanup EXIT

# Read JSON from stdin
INPUT=$(cat)

# Parse notification_type, message: jq preferred, grep/sed fallback
NOTIFICATION_TYPE=""
MESSAGE=""
if command -v jq &>/dev/null; then
  NOTIFICATION_TYPE=$(printf '%s\n' "$INPUT" | jq -r '.notification_type // empty' 2>/dev/null || true)
  MESSAGE=$(printf '%s\n' "$INPUT" | jq -r '.message // empty' 2>/dev/null || true)
else
  NOTIFICATION_TYPE=$(printf '%s\n' "$INPUT" | grep -o '"notification_type"[[:space:]]*:[[:space:]]*"[^"]*"' 2>/dev/null \
    | sed 's/.*:[[:space:]]*"//;s/"$//' || true)
  MESSAGE=$(printf '%s\n' "$INPUT" | grep -o '"message"[[:space:]]*:[[:space:]]*"[^"]*"' 2>/dev/null \
    | sed 's/.*:[[:space:]]*"//;s/"$//' || true)
fi

# Set title based on notification_type
case "$NOTIFICATION_TYPE" in
  idle_prompt)
    TITLE="Claude Task Complete"
    ;;
  permission_prompt)
    TITLE="Permission Approval Required"
    ;;
  *)
    exit 0
    ;;
esac

# Detect platform and send notification (non-blocking via async: true in hooks.json)
# Sanitize message (prevent AppleScript/shell injection)
SAFE_MESSAGE=$(printf '%s' "$MESSAGE" | sed 's/[\"\\]/\\&/g' | head -1 | cut -c1-200)
SAFE_TITLE=$(printf '%s' "$TITLE" | sed 's/[\"\\]/\\&/g')

OS=$(uname -s)
case "$OS" in
  Darwin)
    osascript -e "display notification \"$SAFE_MESSAGE\" with title \"$SAFE_TITLE\"" &>/dev/null || true
    ;;
  Linux)
    if command -v notify-send &>/dev/null; then
      notify-send "$SAFE_TITLE" "$SAFE_MESSAGE" &>/dev/null || true
    fi
    ;;
  *)
    exit 0
    ;;
esac

exit 0
