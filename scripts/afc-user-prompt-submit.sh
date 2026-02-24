#!/bin/bash
set -euo pipefail

# UserPromptSubmit Hook: Inject pipeline Phase/Feature context on every prompt
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

# Output additionalContext to stdout (injected into Claude context)
printf '{"hookSpecificOutput":{"additionalContext":"[Pipeline: %s] [Phase: %s]"}}\n' "$FEATURE" "$PHASE"

exit 0
