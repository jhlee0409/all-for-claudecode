#!/bin/bash
set -euo pipefail
# Pre-Compact Hook: Auto-checkpoint before context compaction
# Prevents loss of progress state during session interruption/compaction
#
# Gap fix: Enforces OMC auto-state-save via physical script

# shellcheck source=afc-state.sh
. "$(dirname "$0")/afc-state.sh"

# shellcheck disable=SC2329
cleanup() {
  # Extend here if temporary file cleanup is needed
  :
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Consume stdin (required -- pipe breaks if not consumed)
cat > /dev/null

# Dynamically derive auto-memory directory from project path
PROJECT_PATH=$(cd "$PROJECT_DIR" 2>/dev/null && pwd || true)
PROJECT_PATH="${PROJECT_PATH:-$PROJECT_DIR}"
ENCODED_PATH="${PROJECT_PATH//\//-}"
MEMORY_DIR="$HOME/.claude/projects/$ENCODED_PATH/memory"
CHECKPOINT="$MEMORY_DIR/checkpoint.md"

# Create memory directory if it doesn't exist
mkdir -p "$MEMORY_DIR"

# Collect current git status
BRANCH=$(cd "$PROJECT_DIR" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")

ALL_MODIFIED=$(cd "$PROJECT_DIR" 2>/dev/null && git diff --name-only 2>/dev/null || true)
MODIFIED=$(printf '%s\n' "$ALL_MODIFIED" | head -10)

ALL_STAGED=$(cd "$PROJECT_DIR" 2>/dev/null && git diff --cached --name-only 2>/dev/null || true)
STAGED=$(printf '%s\n' "$ALL_STAGED" | head -10)

# Count files (capture into variable instead of piping wc -l)
MODIFIED_COUNT=0
if [ -n "$ALL_MODIFIED" ]; then
  MODIFIED_RAW=$(printf '%s\n' "$ALL_MODIFIED" | wc -l)
  MODIFIED_COUNT=$(printf '%s' "$MODIFIED_RAW" | tr -d ' ')
fi

STAGED_COUNT=0
if [ -n "$ALL_STAGED" ]; then
  STAGED_RAW=$(printf '%s\n' "$ALL_STAGED" | wc -l)
  STAGED_COUNT=$(printf '%s' "$STAGED_RAW" | tr -d ' ')
fi

# Check afc pipeline active status
PIPELINE_FEATURE=""
if afc_state_is_active; then
  PIPELINE_FEATURE=$(afc_state_read feature || true)
fi

# Check tasks.md progress status
TASKS_DONE=0
TASKS_TOTAL=0
if [ -n "$PIPELINE_FEATURE" ] && [ -d "$PROJECT_DIR/.claude/afc/specs/$PIPELINE_FEATURE" ]; then
  TASKS_FILE="$PROJECT_DIR/.claude/afc/specs/$PIPELINE_FEATURE/tasks.md"
  if [ -f "$TASKS_FILE" ]; then
    TASKS_DONE=$(grep -cE '\[x\]' "$TASKS_FILE" 2>/dev/null || echo 0)
    TASKS_TOTAL=$(grep -cE '\[(x| )\]' "$TASKS_FILE" 2>/dev/null || echo 0)
  fi
fi

# Guard against empty lists
if [ -n "$MODIFIED" ]; then
  # shellcheck disable=SC2001
  MODIFIED_LIST=$(echo "$MODIFIED" | sed 's/^/  - /')
else
  MODIFIED_LIST="  (none)"
fi

if [ -n "$STAGED" ]; then
  # shellcheck disable=SC2001
  STAGED_LIST=$(echo "$STAGED" | sed 's/^/  - /')
else
  STAGED_LIST="  (none)"
fi

# Write checkpoint.md
cat > "$CHECKPOINT" << EOF
# Auto Checkpoint (Pre-Compact)
> Auto-generated: $(date '+%Y-%m-%d %H:%M:%S')
> Trigger: context compaction

## Git Status
- Branch: $BRANCH
- Modified files: ${MODIFIED_COUNT}
$MODIFIED_LIST

## Staged Files (${STAGED_COUNT})
$STAGED_LIST

## Pipeline Status
- Active: $([ -n "$PIPELINE_FEATURE" ] && echo "Yes ($PIPELINE_FEATURE)" || echo "No")
- Task progress: $TASKS_DONE/$TASKS_TOTAL

## Restore Command
\`\`\`
/afc:resume
\`\`\`
EOF

# Inject context via stdout (Claude can see this info after compaction)
echo "Auto-checkpoint saved to .claude/afc/memory/checkpoint.md (branch: $BRANCH, pipeline: ${PIPELINE_FEATURE:-inactive})"

exit 0
