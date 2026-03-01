#!/bin/bash
set -euo pipefail

# UserPromptSubmit Hook: Two modes of operation:
# 1. Pipeline INACTIVE: No action (routing handled by CLAUDE.md intent-based skill table)
# 2. Pipeline ACTIVE: Inject Phase/Feature context + drift checkpoint at thresholds
# Exit 0 immediately if no action needed (minimize overhead)

# shellcheck source=afc-state.sh
. "$(dirname "$0")/afc-state.sh"

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

# Consume stdin (required -- pipe breaks if not consumed)
cat > /dev/null

# --- Branch: Pipeline INACTIVE → no action needed ---
# Routing is handled by CLAUDE.md intent-based skill routing table.
# The main model classifies user intent natively — no hook-level keyword matching.
if ! afc_state_is_active; then
  exit 0
fi

# --- Branch: Pipeline ACTIVE → existing Phase/Feature context ---

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

# Drift checkpoint: inject plan constraints at every N prompts during implement/review
# AFC_DRIFT_THRESHOLD sourced from afc-state.sh (SSOT)
if [ "$CALL_COUNT" -gt 0 ] && [ $((CALL_COUNT % AFC_DRIFT_THRESHOLD)) -eq 0 ]; then
  case "$PHASE" in
    implement|review)
      DRIFT_MSG="[DRIFT CHECKPOINT: ${CALL_COUNT} prompts in phase] Re-read plan.md constraints and acceptance criteria. Verify current work aligns with spec intent."
      CONTEXT="${CONTEXT} ${DRIFT_MSG}"
      ;;
  esac
fi

# Output additionalContext to stdout (injected into Claude context)
# Use jq for safe JSON encoding; printf fallback strips remaining quotes
if command -v jq &> /dev/null; then
  jq -n --arg c "$CONTEXT" '{"hookSpecificOutput":{"additionalContext":$c}}'
else
  SAFE_CONTEXT="${CONTEXT//\\/\\\\}"
  SAFE_CONTEXT="${SAFE_CONTEXT//\"/\\\"}"
  printf '{"hookSpecificOutput":{"additionalContext":"%s"}}\n' "$SAFE_CONTEXT"
fi

exit 0
