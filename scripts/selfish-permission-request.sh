#!/bin/bash
set -euo pipefail

# PermissionRequest Hook: Auto-allow CI-related Bash commands during implement/review Phase
# Only exact whitelist matches allowed; commands with chaining (&&/;/|/$()) fall through to default behavior (user confirmation)

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PIPELINE_FLAG="$PROJECT_DIR/.claude/.selfish-active"
PHASE_FLAG="$PROJECT_DIR/.claude/.selfish-phase"

# Read hook data from stdin
INPUT=$(cat)

# Exit silently if pipeline is inactive
if [ ! -f "$PIPELINE_FLAG" ]; then
  exit 0
fi

# Only active during implement/review Phase
PHASE=""
if [ -f "$PHASE_FLAG" ]; then
  PHASE="$(head -1 "$PHASE_FLAG" | tr -d '\n\r')"
fi
case "${PHASE:-}" in
  implement|review) ;;
  *) exit 0 ;;
esac

# Parse tool_input.command
COMMAND=""
if command -v jq >/dev/null 2>&1; then
  COMMAND=$(printf '%s\n' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
else
  COMMAND=$(printf '%s\n' "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
fi

# If command is empty, fall through to default behavior
if [ -z "$COMMAND" ]; then
  exit 0
fi

# Detect command chaining/substitution/newlines -- fall through to default behavior if found (security)
if printf '%s' "$COMMAND" | grep -qE '&&|;|\||\$\(|`'; then
  exit 0
fi
# Fall through to default behavior if newlines found (prevent multi-line bypass)
case "$COMMAND" in
  *$'\n'*) exit 0 ;;
esac

# Whitelist exact match (uses space + $ to prevent prefix matching)
ALLOWED=false
case "$COMMAND" in
  "npm run lint"|"npm test"|"npm run test:all")
    ALLOWED=true
    ;;
esac

# Prefix matching (allow paths after shellcheck, prettier, chmod +x)
if [ "$ALLOWED" = "false" ]; then
  case "$COMMAND" in
    "shellcheck "*)
      ALLOWED=true
      ;;
    "prettier "*)
      ALLOWED=true
      ;;
    "chmod +x "*)
      # Only allow paths within project directory (block path traversal)
      TARGET="${COMMAND#chmod +x }"
      case "$TARGET" in
        *..*)  ;;  # Block path traversal
        "$PROJECT_DIR"/*|./scripts/*|scripts/*) ALLOWED=true ;;
      esac
      ;;
  esac
fi

# Output allow decision
if [ "$ALLOWED" = "true" ]; then
  printf '{"hookSpecificOutput":{"decision":{"behavior":"allow"}}}'
fi

# If ALLOWED=false, exit 0 with no output -> default behavior (user confirmation)
exit 0
