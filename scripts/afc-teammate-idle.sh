#!/bin/bash
set -euo pipefail
# TeammateIdle Hook: Block idle during implement/review Phase while pipeline is active
# Physically prevents Claude from stopping mid-task
#
# Gap fix: "Prompts are not enforcement" -> Physical enforcement via exit 2

# shellcheck source=afc-state.sh
. "$(dirname "$0")/afc-state.sh"

# trap: Preserve exit code on abnormal termination + stderr message
# shellcheck disable=SC2329
cleanup() {
  local exit_code=$?
  if [ "$exit_code" -ne 0 ] && [ "$exit_code" -ne 2 ]; then
    echo "[afc:teammate] Abnormal exit (code: $exit_code)" >&2
  fi
  exit "$exit_code"
}
trap cleanup EXIT

# Consume stdin (required -- pipe breaks if not consumed)
cat > /dev/null

# If pipeline is not active -> pass through
if ! afc_state_is_active; then
  exit 0
fi

FEATURE="$(afc_state_read feature || echo '')"

# Check current Phase
CURRENT_PHASE="$(afc_state_read phase || echo '')"

# Block idle during implement/review Phase -> force work to continue
case "${CURRENT_PHASE:-}" in
  implement|review)
    printf "[afc:teammate] Pipeline '%s' Phase '%s' is active.\n  → Complete the current task before going idle\n" "${FEATURE:-unknown}" "${CURRENT_PHASE:-unknown}" >&2
    exit 2
    ;;
  *)
    exit 0
    ;;
esac
