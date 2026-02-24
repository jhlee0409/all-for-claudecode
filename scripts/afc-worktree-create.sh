#!/bin/bash
set -euo pipefail

# WorktreeCreate Hook: Inject pipeline context into new worktrees
# Ensures worker worktrees have access to pipeline state and config

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PIPELINE_FLAG="$PROJECT_DIR/.claude/.afc-active"

# Read hook data from stdin
INPUT=$(cat)

# Exit silently if pipeline is inactive
if [ ! -f "$PIPELINE_FLAG" ]; then
  exit 0
fi

# Parse worktree_path from stdin JSON
WORKTREE_PATH=""
if command -v jq &>/dev/null; then
  WORKTREE_PATH=$(printf '%s\n' "$INPUT" | jq -r '.worktree_path // empty' 2>/dev/null || true)
else
  WORKTREE_PATH=$(printf '%s\n' "$INPUT" | grep -o '"worktree_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
fi

# Exit if no worktree path provided
if [ -z "$WORKTREE_PATH" ]; then
  exit 0
fi

# Read pipeline state
FEATURE=$(head -1 "$PIPELINE_FLAG" 2>/dev/null | tr -d '\n\r' || echo "unknown")
PHASE=""
if [ -f "$PROJECT_DIR/.claude/.afc-phase" ]; then
  PHASE=$(head -1 "$PROJECT_DIR/.claude/.afc-phase" 2>/dev/null | tr -d '\n\r' || echo "unknown")
fi

# Inject pipeline context into worktree
CONTEXT="[AFC WORKTREE] Feature: $FEATURE | Phase: ${PHASE:-unknown} | Source: $PROJECT_DIR"

# Output as hookSpecificOutput JSON
if command -v jq &>/dev/null; then
  jq -n --arg ctx "$CONTEXT" \
    '{"hookSpecificOutput":{"additionalContext":$ctx}}' 2>/dev/null || true
else
  # shellcheck disable=SC1003
  SAFE_CONTEXT=$(printf '%s' "$CONTEXT" | tr -d '"' | tr -d '\\' | cut -c1-2000)
  printf '{"hookSpecificOutput":{"additionalContext":"%s"}}\n' "$SAFE_CONTEXT"
fi

exit 0
