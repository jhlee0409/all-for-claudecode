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
  printf '{"hookSpecificOutput":{"permissionDecision":"allow"}}\n'
  exit 0
fi

# Parse tool input from stdin
INPUT=$(cat)

# If stdin is empty -> allow
if [ -z "$INPUT" ]; then
  printf '{"hookSpecificOutput":{"permissionDecision":"allow"}}\n'
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
  printf '{"hookSpecificOutput":{"permissionDecision":"allow"}}\n'
  exit 0
fi

# Check for dangerous patterns
DENY_REASON=""
SAFE_ALTERNATIVE=""

case "$COMMAND" in
  *"push --force"*|*"push -f "*|*"push -f")
    DENY_REASON="git push --force is blocked during pipeline"
    SAFE_ALTERNATIVE="git push"
    ;;
  *"reset --hard"*)
    # Allow selfish/pre- tag rollback
    if [[ "$COMMAND" != *"selfish/pre-"* ]]; then
      DENY_REASON="git reset --hard is blocked during pipeline"
      SAFE_ALTERNATIVE="git stash"
    fi
    ;;
  *"checkout ."*|*"checkout -- ."*)
    DENY_REASON="git checkout . is blocked during pipeline"
    SAFE_ALTERNATIVE="git diff"
    ;;
  *"restore ."*)
    DENY_REASON="git restore . is blocked during pipeline"
    SAFE_ALTERNATIVE="git diff"
    ;;
  *"clean -f"*)
    DENY_REASON="git clean -f is blocked during pipeline"
    SAFE_ALTERNATIVE="git clean -n"
    ;;
esac

if [ -n "$DENY_REASON" ]; then
  if [ -n "$SAFE_ALTERNATIVE" ]; then
    printf '{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":"SELFISH GUARD: %s. Safe alternative: %s","updatedInput":{"command":"%s"}}}\n' "$DENY_REASON" "$SAFE_ALTERNATIVE" "$SAFE_ALTERNATIVE"
  else
    printf '{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":"SELFISH GUARD: %s"}}\n' "$DENY_REASON"
  fi
else
  printf '{"hookSpecificOutput":{"permissionDecision":"allow"}}\n'
fi

exit 0
