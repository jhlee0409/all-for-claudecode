#!/bin/bash
set -euo pipefail

# WorktreeRemove Hook: Archive worker results when worktree is removed
# Ensures task results are preserved in the main project log

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PIPELINE_FLAG="$PROJECT_DIR/.claude/.afc-active"
RESULTS_LOG="$PROJECT_DIR/.claude/.afc-task-results.log"

# Read hook data from stdin
INPUT=$(cat)

# Exit silently if pipeline is inactive (also handles race condition on pipeline end)
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

# Archive worktree task results to main project
WORKTREE_RESULTS="$WORKTREE_PATH/.claude/.afc-task-results.log"
if [ -f "$WORKTREE_RESULTS" ]; then
  printf '%s\n' "--- worktree: $WORKTREE_PATH ---" >> "$RESULTS_LOG"
  cat "$WORKTREE_RESULTS" >> "$RESULTS_LOG" 2>/dev/null || true
fi

exit 0
