#!/bin/bash
set -euo pipefail

# Session Start Hook: Restore pipeline state on session start
# Inject context so progress state is not lost after resume/compact
#
# Gap fix: Enforces OMC session continuity via physical script

# shellcheck source=afc-state.sh
. "$(dirname "$0")/afc-state.sh"

# shellcheck disable=SC2329
cleanup() {
  local exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    echo "[afc:session] session-start-context.sh exited abnormally" >&2
  fi
  exit "$exit_code"
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Consume stdin (required -- pipe breaks if not consumed)
cat > /dev/null

# Dynamically derive auto-memory directory from project path
PROJECT_PATH=$(cd "$PROJECT_DIR" 2>/dev/null && pwd || echo "$PROJECT_DIR")
ENCODED_PATH="${PROJECT_PATH//\//-}"
MEMORY_DIR="$HOME/.claude/projects/$ENCODED_PATH/memory"
CHECKPOINT="$MEMORY_DIR/checkpoint.md"
OUTPUT=""

# 1. Check for active pipeline
if afc_state_is_active; then
  FEATURE=$(afc_state_read feature || true)
  OUTPUT="[AFC PIPELINE ACTIVE] Feature: $FEATURE"

  # tasks.md progress
  TASKS_FILE="$PROJECT_DIR/.claude/afc/specs/$FEATURE/tasks.md"
  if [ -f "$TASKS_FILE" ]; then
    DONE=$(grep -cE '\[x\]' "$TASKS_FILE" 2>/dev/null || echo 0)
    TOTAL=$(grep -cE '\[(x| )\]' "$TASKS_FILE" 2>/dev/null || echo 0)
    OUTPUT="$OUTPUT | Tasks: $DONE/$TOTAL"
  fi

  # CI pass status
  CI_TIMESTAMP=$(afc_state_read ciPassedAt 2>/dev/null || true)
  if [ -n "$CI_TIMESTAMP" ]; then
    OUTPUT="$OUTPUT | Last CI: PASSED ($CI_TIMESTAMP)"
  fi
fi

# 2. Check if checkpoint exists (project-local first, fallback to auto-memory)
LOCAL_CHECKPOINT="$PROJECT_DIR/.claude/afc/memory/checkpoint.md"
CHECKPOINT_FILE=""
if [ -f "$LOCAL_CHECKPOINT" ]; then
  CHECKPOINT_FILE="$LOCAL_CHECKPOINT"
elif [ -f "$CHECKPOINT" ]; then
  CHECKPOINT_FILE="$CHECKPOINT"
fi

if [ -n "$CHECKPOINT_FILE" ]; then
  RAW_LINE=$(grep 'Auto-generated:' "$CHECKPOINT_FILE" 2>/dev/null || echo "")
  FIRST_LINE=$(echo "$RAW_LINE" | head -1)
  CHECKPOINT_DATE="${FIRST_LINE##*Auto-generated: }"
  if [ -n "$CHECKPOINT_DATE" ]; then
    if [ -n "$OUTPUT" ]; then
      OUTPUT="$OUTPUT | Checkpoint: $CHECKPOINT_DATE"
    else
      OUTPUT="[CHECKPOINT EXISTS] Date: $CHECKPOINT_DATE — Run /afc:resume to restore"
    fi
  fi
fi

# 3. Check for safety tag
HAS_SAFETY_TAG=$(cd "$PROJECT_DIR" 2>/dev/null && git tag -l 'afc/pre-*' 2>/dev/null | head -1 || echo "")
if [ -n "$HAS_SAFETY_TAG" ]; then
  if [ -n "$OUTPUT" ]; then
    OUTPUT="$OUTPUT | Safety tag: $HAS_SAFETY_TAG"
  fi
fi

# Output (stdout -> injected into Claude context)
if [ -n "$OUTPUT" ]; then
  printf '%s\n' "$OUTPUT"
fi

exit 0
