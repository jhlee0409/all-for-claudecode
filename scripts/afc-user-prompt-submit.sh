#!/bin/bash
set -euo pipefail

# UserPromptSubmit Hook: Inject pipeline Phase/Feature context on every prompt
# Exit 0 immediately if pipeline is inactive (minimize overhead)

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PIPELINE_FLAG="$PROJECT_DIR/.claude/.afc-active"
PHASE_FLAG="$PROJECT_DIR/.claude/.afc-phase"

# Consume stdin (required -- pipe breaks if not consumed)
cat > /dev/null

# Exit silently if pipeline is inactive
if [ ! -f "$PIPELINE_FLAG" ]; then
  exit 0
fi

# Read Feature/Phase + JSON-safe processing (strip special characters)
FEATURE="$(head -1 "$PIPELINE_FLAG" | tr -d '\n\r' | tr -d '"' | cut -c1-100)"
PHASE="unknown"
if [ -f "$PHASE_FLAG" ]; then
  PHASE="$(head -1 "$PHASE_FLAG" | tr -d '\n\r' | tr -d '"' | cut -c1-100)"
fi

# Output additionalContext to stdout (injected into Claude context)
printf '{"hookSpecificOutput":{"additionalContext":"[Pipeline: %s] [Phase: %s]"}}\n' "$FEATURE" "$PHASE"

exit 0
