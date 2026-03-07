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
PIPELINE_ACTIVE=0

# 1. Check for active pipeline
if afc_state_is_active; then
  PIPELINE_ACTIVE=1
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
elif [ -f "$PROJECT_DIR/.claude/.afc-state.json" ]; then
  # 1a. Zombie state cleanup — file exists but afc_state_is_active returned false
  rm -f "$PROJECT_DIR/.claude/.afc-state.json"
  OUTPUT="${OUTPUT:+$OUTPUT | }[ZOMBIE STATE CLEANED] Removed invalid .afc-state.json"
fi

# 1b. Version mismatch detection
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$PLUGIN_ROOT/package.json" ]; then
  # Read plugin version
  if command -v jq >/dev/null 2>&1; then
    PLUGIN_VERSION=$(jq -r '.version // empty' "$PLUGIN_ROOT/package.json" 2>/dev/null || true)
  else
    PLUGIN_VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$PLUGIN_ROOT/package.json" 2>/dev/null | head -1 | sed 's/.*: *"//;s/"//') || true
  fi

  if [ -n "${PLUGIN_VERSION:-}" ]; then
    # Read AFC block version from global CLAUDE.md
    GLOBAL_CLAUDE="$HOME/.claude/CLAUDE.md"
    if [ -f "$GLOBAL_CLAUDE" ]; then
      BLOCK_VERSION=$(grep -o 'AFC:VERSION:[0-9][0-9.]*' "$GLOBAL_CLAUDE" 2>/dev/null | head -1 | sed 's/AFC:VERSION://' || true)
      if [ -n "${BLOCK_VERSION:-}" ] && [ "$BLOCK_VERSION" != "$PLUGIN_VERSION" ]; then
        OUTPUT="${OUTPUT:+$OUTPUT | }[AFC VERSION MISMATCH] v$PLUGIN_VERSION installed but CLAUDE.md block is v$BLOCK_VERSION. Run /afc:init to update."
      fi
    fi
  fi
fi

# 2. Auto-memory checkpoint cleanup (prevent stale context pollution)
# Auto-memory files are auto-loaded into every conversation by Claude Code.
# Stale checkpoints from previous sessions can confuse the model.
# Only remove auto-memory when project-local copy also exists (prevents stranded checkpoint data loss).
LOCAL_CHECKPOINT="$PROJECT_DIR/.claude/afc/memory/checkpoint.md"
if [ "$PIPELINE_ACTIVE" -eq 0 ] && [ -f "$CHECKPOINT" ] && [ -f "$LOCAL_CHECKPOINT" ]; then
  rm -f "$CHECKPOINT"
fi

# 3. Check if project-local checkpoint exists (for user notification only)
if [ -f "$LOCAL_CHECKPOINT" ]; then
  RAW_LINE=$(grep 'Auto-generated:' "$LOCAL_CHECKPOINT" 2>/dev/null || echo "")
  FIRST_LINE=$(printf '%s\n' "$RAW_LINE" | head -1)
  CHECKPOINT_DATE="${FIRST_LINE##*Auto-generated: }"
  if [ -n "$CHECKPOINT_DATE" ]; then
    if [ -n "$OUTPUT" ]; then
      OUTPUT="$OUTPUT | Checkpoint: $CHECKPOINT_DATE"
    else
      OUTPUT="[CHECKPOINT EXISTS] Date: $CHECKPOINT_DATE — Run /afc:resume to restore"
    fi
  fi
fi

# 4. Learner queue notification (lowest priority, advisory only)
LEARNER_CONFIG="$PROJECT_DIR/.claude/afc/learner.json"
LEARNER_QUEUE="$PROJECT_DIR/.claude/.afc-learner-queue.jsonl"
if [ -f "$LEARNER_CONFIG" ] && [ -f "$LEARNER_QUEUE" ]; then
  # Prune stale entries (older than 7 days)
  if command -v date >/dev/null 2>&1; then
    CUTOFF=$(date -u -v-7d '+%Y-%m-%dT' 2>/dev/null || date -u -d '7 days ago' '+%Y-%m-%dT' 2>/dev/null || true)
    if [ -n "$CUTOFF" ]; then
      TMP_QUEUE="${LEARNER_QUEUE}.tmp"
      grep -E "\"timestamp\":\"${CUTOFF:0:4}" "$LEARNER_QUEUE" > "$TMP_QUEUE" 2>/dev/null || true
      # Keep entries whose timestamp >= cutoff (simple lexicographic comparison)
      while IFS= read -r line; do
        TS=$(printf '%s' "$line" | sed 's/.*"timestamp":"//;s/".*//' 2>/dev/null || true)
        if [ -n "$TS" ] && [ "$TS" \> "$CUTOFF" ] 2>/dev/null; then
          printf '%s\n' "$line"
        fi
      done < "$LEARNER_QUEUE" > "$TMP_QUEUE" 2>/dev/null || true
      if [ -f "$TMP_QUEUE" ]; then
        mv "$TMP_QUEUE" "$LEARNER_QUEUE"
      fi
    fi
  fi
  LEARNER_COUNT=0
  if [ -f "$LEARNER_QUEUE" ]; then
    LEARNER_COUNT=$(wc -l < "$LEARNER_QUEUE" 2>/dev/null | tr -d ' ')
  fi
  if [ "$LEARNER_COUNT" -ge 2 ]; then
    OUTPUT="${OUTPUT:+$OUTPUT | }[Learner: $LEARNER_COUNT patterns pending — run /afc:learner to review]"
  fi
fi

# 5. Check for safety tag
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
