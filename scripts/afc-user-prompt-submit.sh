#!/bin/bash
set -euo pipefail

# UserPromptSubmit Hook: Inject pipeline Phase/Feature context on every prompt
# Also tracks prompt count and injects drift checkpoint at thresholds
# Exit 0 immediately if pipeline is inactive (minimize overhead)

# shellcheck source=afc-state.sh
. "$(dirname "$0")/afc-state.sh"

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

# Consume stdin (required -- pipe breaks if not consumed)
cat > /dev/null

# Exit silently if pipeline is inactive
if ! afc_state_is_active; then
  exit 0
fi

# Read Feature/Phase + JSON-safe processing (strip special characters)
FEATURE="$(afc_state_read feature || echo '')"
FEATURE="$(printf '%s' "$FEATURE" | tr -d '"' | cut -c1-100)"
PHASE="$(afc_state_read phase || echo 'unknown')"
PHASE="$(printf '%s' "$PHASE" | tr -d '"' | cut -c1-100)"

# Increment per-phase prompt counter + pipeline-wide total
CALL_COUNT=$(afc_state_increment promptCount 2>/dev/null || echo 0)
afc_state_increment totalPromptCount >/dev/null 2>&1 || echo "[afc:prompt-submit] totalPromptCount increment failed" >&2

# Build context message
CONTEXT="[Pipeline: ${FEATURE}] [Phase: ${PHASE}]"

# Drift checkpoint: inject plan constraints at every 50 prompts during implement/review
DRIFT_THRESHOLD=50
if [ "$CALL_COUNT" -gt 0 ] && [ $((CALL_COUNT % DRIFT_THRESHOLD)) -eq 0 ]; then
  case "$PHASE" in
    implement|review)
      DRIFT_MSG="[DRIFT CHECKPOINT: ${CALL_COUNT} prompts in phase] Re-read plan.md constraints and acceptance criteria. Verify current work aligns with spec intent."
      CONTEXT="${CONTEXT} ${DRIFT_MSG}"
      ;;
  esac
fi

# Output additionalContext to stdout (injected into Claude context)
printf '{"hookSpecificOutput":{"additionalContext":"%s"}}\n' "$CONTEXT"

exit 0
