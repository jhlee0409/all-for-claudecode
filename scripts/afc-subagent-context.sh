#!/bin/bash
set -euo pipefail

# SubagentStart Hook: Inject pipeline context when subagent is created
# Ensures subagent is aware of current feature/phase and project settings
#
# Gap fix: Subagents do not inherit parent context, so explicit injection is required

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

# 1. Read feature name
FEATURE=$(afc_state_read feature || echo "unknown")

# 2. Read current phase
PHASE=$(afc_state_read phase || echo "unknown")

# 3. Build context string
CONTEXT="[AFC PIPELINE] Feature: $FEATURE | Phase: $PHASE"

# 4. Extract config sections from afc.config.md
CONFIG_FILE="$PROJECT_DIR/.claude/afc.config.md"

if [ -f "$CONFIG_FILE" ]; then
  # Extract Architecture section (## Architecture to next ##)
  # shellcheck disable=SC2001
  ARCH=$(sed -n '/^## Architecture/,/^## /p' "$CONFIG_FILE" 2>/dev/null | sed '1d;/^## /d;/^$/d' | head -15 | tr '\n' ' ' | sed 's/  */ /g;s/^ *//;s/ *$//')
  if [ -n "$ARCH" ]; then
    CONTEXT="$CONTEXT | Architecture: $ARCH"
  fi

  # Extract Code Style section (## Code Style to next ##)
  # shellcheck disable=SC2001
  STYLE=$(sed -n '/^## Code Style/,/^## /p' "$CONFIG_FILE" 2>/dev/null | sed '1d;/^## /d;/^$/d' | head -15 | tr '\n' ' ' | sed 's/  */ /g;s/^ *//;s/ *$//')
  if [ -n "$STYLE" ]; then
    CONTEXT="$CONTEXT | Code Style: $STYLE"
  fi

  # Extract Project Context section (## Project Context to next ## or EOF)
  # shellcheck disable=SC2001
  PROJ_CTX=$(sed -n '/^## Project Context/,/^## /p' "$CONFIG_FILE" 2>/dev/null | sed '1d;/^## /d;/^$/d' | head -15 | tr '\n' ' ' | sed 's/  */ /g;s/^ *//;s/ *$//')
  if [ -n "$PROJ_CTX" ]; then
    CONTEXT="$CONTEXT | Project Context: $PROJ_CTX"
  fi
fi

# 5. Output as hookSpecificOutput JSON (required for SubagentStart context injection)
if command -v jq &>/dev/null; then
  jq -n --arg ctx "$CONTEXT" \
    '{"hookSpecificOutput":{"additionalContext":$ctx}}' 2>/dev/null || true
else
  # Sanitize for JSON safety
  # shellcheck disable=SC1003
  SAFE_CONTEXT=$(printf '%s' "$CONTEXT" | tr -d '"' | tr -d '\\' | cut -c1-2000)
  printf '{"hookSpecificOutput":{"additionalContext":"%s"}}\n' "$SAFE_CONTEXT"
fi

exit 0
