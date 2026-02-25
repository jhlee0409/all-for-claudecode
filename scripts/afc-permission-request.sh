#!/bin/bash
set -euo pipefail

# PermissionRequest Hook: Auto-allow CI-related Bash commands during implement/review Phase
# Only exact whitelist matches allowed; commands with chaining (&&/;/|/$()) fall through to default behavior (user confirmation)

# shellcheck source=afc-state.sh
. "$(dirname "$0")/afc-state.sh"

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Read hook data from stdin
INPUT=$(cat)

# Exit silently if pipeline is inactive
if ! afc_state_is_active; then
  exit 0
fi

# Only active during implement/review Phase
PHASE="$(afc_state_read phase || echo '')"
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

# Detect command chaining/substitution/redirects/newlines -- fall through to default behavior if found (security)
if printf '%s' "$COMMAND" | grep -qE '&&|;|\||\$\(|`|>|<'; then
  exit 0
fi
# Fall through to default behavior if newlines found (prevent multi-line bypass)
case "$COMMAND" in
  *$'\n'*) exit 0 ;;
esac

# Build dynamic whitelist from afc.config.md (CI/gate/test commands)
DYNAMIC_WHITELIST=""
CONFIG_FILE="$PROJECT_DIR/.claude/afc.config.md"
if [ -f "$CONFIG_FILE" ]; then
  # Extract ci, gate, test values from YAML code block
  # Handles both quoted and unquoted: ci: "npm run lint" or ci: npm run lint
  for key in ci gate test; do
    val=$(grep -E "^\s*${key}:\s*\"[^\"]*\"" "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/.*'"${key}"': *"\([^"]*\)".*/\1/' || true)
    if [ -n "$val" ] && [ "$val" != '""' ]; then
      DYNAMIC_WHITELIST="${DYNAMIC_WHITELIST:+${DYNAMIC_WHITELIST}|}${val}"
      # Generate PM-agnostic variants (npm → pnpm, yarn, bun)
      case "$val" in
        "npm run "*)
          suffix="${val#npm run }"
          DYNAMIC_WHITELIST="${DYNAMIC_WHITELIST}|pnpm run ${suffix}|yarn run ${suffix}|bun run ${suffix}"
          ;;
        "npm test"*)
          suffix="${val#npm test}"
          DYNAMIC_WHITELIST="${DYNAMIC_WHITELIST}|pnpm test${suffix}|yarn test${suffix}|bun test${suffix}"
          ;;
      esac
    fi
  done
fi

# Whitelist exact match (uses space + $ to prevent prefix matching)
ALLOWED=false

# Check dynamic whitelist first (from afc.config.md)
if [ -n "$DYNAMIC_WHITELIST" ]; then
  # Use printf + grep for safe matching (no eval)
  if printf '%s\n' "$DYNAMIC_WHITELIST" | tr '|' '\n' | grep -qxF "$COMMAND"; then
    ALLOWED=true
  fi
fi

# Hardcoded fallback whitelist (always active for backward compatibility)
if [ "$ALLOWED" = "false" ]; then
  case "$COMMAND" in
    "npm run lint"|"npm test"|"npm run test:all")
      ALLOWED=true
      ;;
  esac
fi

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
  printf '{"hookSpecificOutput":{"decision":{"behavior":"allow"}}}\n'
fi

# If ALLOWED=false, exit 0 with no output -> default behavior (user confirmation)
exit 0
