#!/bin/bash
set -euo pipefail
# PreToolUse Hook: Block dangerous Bash commands while pipeline is active
# Prevents git push --force, reset --hard, checkout ., restore ., clean -f, etc.
# Exception: reset --hard is allowed for selfish/pre- tag rollback

# shellcheck disable=SC2329
cleanup() {
  # Placeholder for temporary resource cleanup if needed
  :
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PIPELINE_FLAG="$PROJECT_DIR/.claude/.selfish-active"

# If pipeline is inactive -> allow
if [ ! -f "$PIPELINE_FLAG" ]; then
  printf '{"decision":"allow"}\n'
  exit 0
fi

# Parse tool input from stdin
INPUT=$(cat)

# If stdin is empty -> allow
if [ -z "$INPUT" ]; then
  printf '{"decision":"allow"}\n'
  exit 0
fi

# Extract command with jq if available, otherwise grep/sed fallback
if command -v jq &> /dev/null; then
  COMMAND=$(printf '%s\n' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
else
  COMMAND=$(printf '%s\n' "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
fi

# If command is empty -> allow
if [ -z "$COMMAND" ]; then
  printf '{"decision":"allow"}\n'
  exit 0
fi

# Check for dangerous patterns
DENY_REASON=""

case "$COMMAND" in
  *"push --force"*|*"push -f "*|*"push -f")
    DENY_REASON="git push --force is blocked during pipeline"
    ;;
  *"reset --hard"*)
    # Allow selfish/pre- tag rollback
    if [[ "$COMMAND" != *"selfish/pre-"* ]]; then
      DENY_REASON="git reset --hard is blocked during pipeline"
    fi
    ;;
  *"checkout ."*|*"checkout -- ."*)
    DENY_REASON="git checkout . is blocked during pipeline"
    ;;
  *"restore ."*)
    DENY_REASON="git restore . is blocked during pipeline"
    ;;
  *"clean -f"*)
    DENY_REASON="git clean -f is blocked during pipeline"
    ;;
esac

if [ -n "$DENY_REASON" ]; then
  printf '{"decision":"deny","reason":"SELFISH GUARD: %s"}\n' "$DENY_REASON"
else
  printf '{"decision":"allow"}\n'
fi

exit 0
