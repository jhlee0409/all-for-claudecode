#!/bin/bash
set -euo pipefail
# PostToolUseFailure Hook: Output hints matching error patterns on tool failure

# shellcheck source=afc-state.sh
. "$(dirname "$0")/afc-state.sh"

# shellcheck disable=SC2329
cleanup() {
  # Placeholder for temporary resource cleanup if needed
  :
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
FAILURES_LOG="$PROJECT_DIR/.claude/.afc-failures.log"

# Parse input from stdin
INPUT=$(cat)

# Extract tool_name
if command -v jq &> /dev/null; then
  TOOL_NAME=$(printf '%s\n' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
  ERROR=$(printf '%s\n' "$INPUT" | jq -r '.error // empty' 2>/dev/null || true)
else
  TOOL_NAME=$(printf '%s\n' "$INPUT" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
  ERROR=$(printf '%s\n' "$INPUT" | grep -o '"error"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
fi

TOOL_NAME="${TOOL_NAME:-unknown}"
ERROR="${ERROR:-}"

# If pipeline is active, log failure (normalize error message to single line)
if afc_state_is_active && [ -n "$ERROR" ]; then
  ERROR_ONELINE=$(printf '%s\n' "$ERROR" | head -1 | cut -c1-200)
  printf '%s\n' "$(date +%s) $TOOL_NAME: $ERROR_ONELINE" >> "$FAILURES_LOG"
fi

# Error pattern matching
HINT=""
case "$ERROR" in
  *EACCES*)
    HINT="Check file permissions. You may need chmod or sudo."
    ;;
  *ENOENT*|*"No such file"*)
    HINT="Check that the file or directory exists."
    ;;
  *ECONNREFUSED*)
    HINT="Check that the target server/service is running."
    ;;
  *"command not found"*)
    HINT="Check that the required tool is installed."
    ;;
  *"shellcheck"*)
    HINT="Install shellcheck: brew install shellcheck (macOS) or apt install shellcheck (Linux)"
    ;;
  *"ENOMEM"*|*"Cannot allocate"*)
    HINT="Out of memory. Terminate other processes or check resources."
    ;;
  *)
    HINT=""
    ;;
esac

# If hint exists, output JSON (sanitize variables to prevent JSON injection)
if [ -n "$HINT" ]; then
  # Generate safe JSON with jq if available, otherwise strip special chars and use printf
  if command -v jq &> /dev/null; then
    jq -n --arg ctx "[afc:hint] $HINT (tool: $TOOL_NAME)" \
      '{"hookSpecificOutput":{"hookEventName":"PostToolUseFailure","additionalContext":$ctx}}' 2>/dev/null || true
  else
    # shellcheck disable=SC1003
    SAFE_HINT=$(printf '%s' "$HINT" | tr -d '"' | tr -d '\\')
    # shellcheck disable=SC1003
    SAFE_TOOL=$(printf '%s' "$TOOL_NAME" | tr -d '"' | tr -d '\\')
    printf '{"hookSpecificOutput":{"hookEventName":"PostToolUseFailure","additionalContext":"[afc:hint] %s (tool: %s)"}}\n' "$SAFE_HINT" "$SAFE_TOOL"
  fi
fi

exit 0
