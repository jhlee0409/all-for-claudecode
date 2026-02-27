#!/bin/bash
set -euo pipefail
# PreToolUse Hook: Block spec.md writes during implement/review/clean phases
# Prevents agents from weakening acceptance criteria (spec immutability)
# Only active when pipeline is running AND phase is implement/review/clean

# shellcheck source=afc-state.sh
. "$(dirname "$0")/afc-state.sh"

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

ALLOW='{"hookSpecificOutput":{"permissionDecision":"allow"}}'

# Consume stdin immediately (prevents SIGPIPE if exiting early)
INPUT=$(cat)

# If pipeline is inactive -> allow
if ! afc_state_is_active; then
  printf '%s\n' "$ALLOW"
  exit 0
fi

# Read current phase
PHASE="$(afc_state_read phase || echo '')"

# Only guard during implement, review, clean phases
case "$PHASE" in
  implement|review|clean) ;;
  *)
    printf '%s\n' "$ALLOW"
    exit 0
    ;;
esac

if [ -z "$INPUT" ]; then
  printf '%s\n' "$ALLOW"
  exit 0
fi

# Extract file_path from tool_input (Edit, Write, NotebookEdit all use file_path)
FILE_PATH=""
if command -v jq &> /dev/null; then
  FILE_PATH=$(printf '%s\n' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
else
  FILE_PATH=$(printf '%s\n' "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
fi

if [ -z "$FILE_PATH" ]; then
  printf '%s\n' "$ALLOW"
  exit 0
fi

# Check if file path targets spec.md inside afc specs directory
# Match: any path containing /specs/ and ending with spec.md
if printf '%s' "$FILE_PATH" | grep -qE '/specs/[^/]+/spec\.md$'; then
  printf '{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":"[afc:guard] spec.md is immutable during %s phase. Acceptance criteria cannot be modified after spec phase."}}\n' "$PHASE"
  exit 0
fi

printf '%s\n' "$ALLOW"
exit 0
