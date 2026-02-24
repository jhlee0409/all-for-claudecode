#!/bin/bash
set -euo pipefail
# JSONL Event Logger: Appends structured events to .claude/.afc-timeline.jsonl
#
# Usage:
#   afc-timeline-log.sh <event_type> <message> [extra_json_fields]
#
# event_type: phase-start, phase-end, gate-pass, gate-fail, error,
#             pipeline-start, pipeline-end
# message:    human-readable description
# extra_json_fields: optional JSON object string to merge (e.g. '{"tool":"bash"}')

# shellcheck source=afc-state.sh
. "$(dirname "$0")/afc-state.sh"

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
FLAG_DIR="$PROJECT_DIR/.claude"
TIMELINE_FILE="$FLAG_DIR/.afc-timeline.jsonl"
ROTATE_FILE="$FLAG_DIR/.afc-timeline.jsonl.1"
MAX_BYTES=1048576  # 1 MB

EVENT_TYPE="${1:-}"
MESSAGE="${2:-}"
EXTRA="${3:-}"

# Validate required arguments
if [ -z "$EVENT_TYPE" ] || [ -z "$MESSAGE" ]; then
  printf 'Usage: %s <event_type> <message> [extra_json_fields]\n' "$0" >&2
  exit 0
fi

# Sanitize inputs (strip newlines; limit length)
EVENT_TYPE=$(printf '%s' "$EVENT_TYPE" | tr -d '\n\r' | cut -c1-64)
MESSAGE=$(printf '%s' "$MESSAGE"     | tr -d '\n\r' | cut -c1-500)

# Read pipeline state (gracefully handle missing state)
FEATURE="none"
PHASE="none"
if afc_state_is_active; then
  FEATURE=$(afc_state_read feature || echo "none")
  FEATURE=$(printf '%s' "$FEATURE" | cut -c1-100)
  PHASE=$(afc_state_read phase || echo "none")
  PHASE=$(printf '%s' "$PHASE" | cut -c1-64)
fi

# Timestamp (no jq dependency)
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Escape a string for JSON (handle backslash, double-quote, and control chars)
json_escape() {
  printf '%s' "$1" \
    | sed 's/\\/\\\\/g' \
    | sed 's/"/\\"/g' \
    | tr -d '\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017' \
    | tr -d '\020\021\022\023\024\025\026\027\030\031\032\033\034\035\036\037'
}

TS_ESC=$(json_escape "$TS")
EVENT_ESC=$(json_escape "$EVENT_TYPE")
MSG_ESC=$(json_escape "$MESSAGE")
FEATURE_ESC=$(json_escape "$FEATURE")
PHASE_ESC=$(json_escape "$PHASE")

# Build the base JSON line
BASE="{\"ts\":\"${TS_ESC}\",\"event\":\"${EVENT_ESC}\",\"msg\":\"${MSG_ESC}\",\"feature\":\"${FEATURE_ESC}\",\"phase\":\"${PHASE_ESC}\"}"

# Merge extra JSON fields if provided (append before closing brace)
if [ -n "$EXTRA" ]; then
  # Strip outer braces from EXTRA and append, only if it looks like a JSON object
  INNER=$(printf '%s' "$EXTRA" | sed 's/^[[:space:]]*{//;s/}[[:space:]]*$//')
  if [ -n "$INNER" ]; then
    LINE="${BASE%\}},${INNER}}"
  else
    LINE="$BASE"
  fi
else
  LINE="$BASE"
fi

# Ensure the flag directory exists
mkdir -p "$FLAG_DIR"

# Auto-rotate if the timeline file exceeds MAX_BYTES
if [ -f "$TIMELINE_FILE" ]; then
  FILE_SIZE=$(wc -c < "$TIMELINE_FILE" | tr -d ' ')
  if [ "$FILE_SIZE" -ge "$MAX_BYTES" ]; then
    mv "$TIMELINE_FILE" "$ROTATE_FILE"
  fi
fi

# Append the JSONL line
printf '%s\n' "$LINE" >> "$TIMELINE_FILE"

exit 0
