#!/bin/bash
set -euo pipefail

# PostCompact Hook: Restore pipeline context after compaction
# Injects pipeline state and key context into the post-compact conversation
# so the model is aware of the active feature, phase, and critical decisions.

# shellcheck source=afc-state.sh
. "$(dirname "$0")/afc-state.sh"

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Consume stdin (required -- pipe breaks if not consumed)
cat > /dev/null

# Exit silently if pipeline is inactive
if ! afc_state_is_active; then
  exit 0
fi

# Read pipeline state
FEATURE=$(afc_state_read feature || echo "unknown")
PHASE=$(afc_state_read phase || echo "unknown")

# Read context.md first 30 lines if it exists
CONTEXT_FILE="$PROJECT_DIR/.claude/afc/specs/$FEATURE/context.md"
if [ -f "$CONTEXT_FILE" ]; then
  CONTEXT_CONTENT=$(head -30 "$CONTEXT_FILE" 2>/dev/null || echo "")
else
  CONTEXT_CONTENT="no context.md"
fi

# Build restore message
RESTORE_MSG="[afc:restored] Pipeline: $FEATURE, Phase: $PHASE. Key context after compaction:
$CONTEXT_CONTENT"

# Output as hookSpecificOutput JSON
if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$RESTORE_MSG" \
    '{"hookSpecificOutput":{"additionalContext":$ctx}}' 2>/dev/null || true
else
  # Sanitize for JSON safety — remove double quotes and backslashes
  # shellcheck disable=SC1003
  SAFE_MSG=$(printf '%s' "$RESTORE_MSG" | tr -d '"' | tr -d '\\' | cut -c1-3000)
  printf '{"hookSpecificOutput":{"additionalContext":"%s"}}\n' "$SAFE_MSG"
fi

exit 0
