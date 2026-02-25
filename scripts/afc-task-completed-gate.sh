#!/bin/bash
set -euo pipefail
# TaskCompleted Gate Hook: Block task completion while pipeline is active and CI has not passed
# Physically prevents Claude from skipping CI and completing a task
#
# Gap fix: "Prompts are not enforcement" -> Physical enforcement via exit 2

# shellcheck source=afc-state.sh
. "$(dirname "$0")/afc-state.sh"

# trap: Preserve exit code on abnormal termination + stderr message
# shellcheck disable=SC2329
cleanup() {
  local exit_code=$?
  if [ "$exit_code" -ne 0 ] && [ "$exit_code" -ne 2 ]; then
    echo "[afc:task-gate] Abnormal exit (code: $exit_code)" >&2
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

# Preparatory phases do not require CI -> pass through
if afc_is_ci_exempt "${CURRENT_PHASE:-}"; then
  exit 0
fi

# Implement/Review/Clean Phase (4-6) require CI to pass
CI_TIME="$(afc_state_read ciPassedAt 2>/dev/null || echo '')"
CI_TIME="$(printf '%s' "$CI_TIME" | tr -dc '0-9')"
CI_TIME="${CI_TIME:-0}"

if [ "$CI_TIME" -eq 0 ]; then
  printf "[afc:task-gate] CI has not been run. Pipeline '%s' Phase '%s' requires CI gate.\n  → Run your CI command to pass the gate\n" "${FEATURE:-unknown}" "${CURRENT_PHASE:-unknown}" >&2
  exit 2
fi

# Verify CI passed within the last 10 minutes (prevent stale results)
NOW="$(date +%s)"
if [ "$CI_TIME" -gt 0 ]; then
  DIFF=$(( NOW - CI_TIME ))
  if [ "$DIFF" -gt 600 ]; then
    printf "[afc:task-gate] CI results are stale (%ss ago).\n  → Run your CI command again\n" "$DIFF" >&2
    exit 2
  fi
fi

exit 0
