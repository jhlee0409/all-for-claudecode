#!/bin/bash
set -euo pipefail

# Session Start Hook: Restore pipeline state on session start
# Inject context so progress state is not lost after resume/compact
#
# Gap fix: Enforces OMC session continuity via physical script

# shellcheck disable=SC2329
cleanup() {
  local exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    echo "[selfish-pipeline] session-start-context.sh exited abnormally" >&2
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
PIPELINE_FLAG="$PROJECT_DIR/.claude/.selfish-active"

OUTPUT=""

# 1. Check for active pipeline
if [ -f "$PIPELINE_FLAG" ]; then
  FEATURE=$(head -1 "$PIPELINE_FLAG" 2>/dev/null | tr -d '\n\r' || true)
  OUTPUT="[SELFISH PIPELINE ACTIVE] Feature: $FEATURE"

  # tasks.md progress
  TASKS_FILE="$PROJECT_DIR/specs/$FEATURE/tasks.md"
  if [ -f "$TASKS_FILE" ]; then
    DONE=$(grep -cE '\[x\]' "$TASKS_FILE" 2>/dev/null || echo 0)
    TOTAL=$(grep -cE '\[(x| )\]' "$TASKS_FILE" 2>/dev/null || echo 0)
    OUTPUT="$OUTPUT | Tasks: $DONE/$TOTAL"
  fi

  # CI pass status
  CI_FLAG="$PROJECT_DIR/.claude/.selfish-ci-passed"
  if [ -f "$CI_FLAG" ]; then
    OUTPUT="$OUTPUT | Last CI: PASSED ($(cat "$CI_FLAG" 2>/dev/null || true))"
  fi
fi

# 2. Check if checkpoint exists
if [ -f "$CHECKPOINT" ]; then
  RAW_LINE=$(grep 'Auto-generated:' "$CHECKPOINT" 2>/dev/null || echo "")
  FIRST_LINE=$(echo "$RAW_LINE" | head -1)
  CHECKPOINT_DATE="${FIRST_LINE##*Auto-generated: }"
  if [ -n "$CHECKPOINT_DATE" ]; then
    if [ -n "$OUTPUT" ]; then
      OUTPUT="$OUTPUT | Checkpoint: $CHECKPOINT_DATE"
    else
      OUTPUT="[CHECKPOINT EXISTS] Date: $CHECKPOINT_DATE — Run /selfish:resume to restore"
    fi
  fi
fi

# 3. Check for safety tag
HAS_SAFETY_TAG=$(cd "$PROJECT_DIR" 2>/dev/null && git tag -l 'selfish/pre-*' 2>/dev/null | head -1 || echo "")
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
