#!/bin/bash
set -euo pipefail
# Stop Gate Hook: Block stop while pipeline is active and CI has not passed
# Physically prevents Claude from skipping CI and claiming "done"
#
# Gap fix: "Prompts are not enforcement" -> Physical enforcement via exit 2

# shellcheck source=afc-state.sh
. "$(dirname "$0")/afc-state.sh"

# trap: Preserve exit code on abnormal termination + stderr message
# shellcheck disable=SC2329
cleanup() {
  local exit_code=$?
  if [ "$exit_code" -ne 0 ] && [ "$exit_code" -ne 2 ]; then
    echo "[afc:gate] Abnormal exit (code: $exit_code)" >&2
  fi
  exit "$exit_code"
}
trap cleanup EXIT

# Consume stdin (required -- pipe breaks if not consumed)
INPUT=$(cat)

# If pipeline is not active -> pass through
if ! afc_state_is_active; then
  exit 0
fi

# Check stop_hook_active to prevent infinite loop (model keeps trying to stop, gets blocked, repeats)
STOP_HOOK_ACTIVE=""
if command -v jq &>/dev/null; then
  STOP_HOOK_ACTIVE=$(printf '%s\n' "$INPUT" | jq -r '.stop_hook_active // empty' 2>/dev/null || true)
else
  if printf '%s\n' "$INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' 2>/dev/null; then
    STOP_HOOK_ACTIVE="true"
  fi
fi
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

FEATURE="$(afc_state_read feature || echo '')"

# Check current Phase
CURRENT_PHASE="$(afc_state_read phase || echo '')"

# Spec/Plan/Tasks Phase (1-3) do not require CI -> pass through
case "${CURRENT_PHASE:-}" in
  spec|plan|tasks)
    exit 0
    ;;
esac

# Implement/Review/Clean Phase (4-6) require CI to pass
CI_TIME="$(afc_state_read ciPassedAt 2>/dev/null || echo '')"
CI_TIME="$(printf '%s' "$CI_TIME" | tr -dc '0-9')"
CI_TIME="${CI_TIME:-0}"

if [ "$CI_TIME" -eq 0 ]; then
  # Check last_assistant_message for premature completion claims
  LAST_MSG=""
  if command -v jq &>/dev/null; then
    LAST_MSG=$(printf '%s\n' "$INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null || true)
  else
    LAST_MSG=$(printf '%s\n' "$INPUT" | grep -o '"last_assistant_message"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
  fi
  LAST_MSG=$(printf '%s\n' "$LAST_MSG" | head -1 | cut -c1-500)

  if printf '%s\n' "$LAST_MSG" | grep -qiE '(done|complete[^s]|finished|implemented|all tasks)' 2>/dev/null; then
    printf "[afc:gate] CI has not passed. Pipeline '%s' Phase '%s' requires CI gate.\n  → Run your CI command and verify it passes\n" "${FEATURE:-unknown}" "${CURRENT_PHASE:-unknown}" >&2
  else
    printf "[afc:gate] CI has not been run. Pipeline '%s' Phase '%s' requires CI gate.\n  → Run your CI command to pass the gate\n" "${FEATURE:-unknown}" "${CURRENT_PHASE:-unknown}" >&2
  fi
  exit 2
fi

# Verify CI passed within the last 10 minutes (prevent stale results)
NOW="$(date +%s)"
if [ "$CI_TIME" -gt 0 ]; then
  DIFF=$(( NOW - CI_TIME ))
  if [ "$DIFF" -gt 600 ]; then
    printf "[afc:gate] CI results are stale (%ss ago).\n  → Run your CI command again\n" "$DIFF" >&2
    exit 2
  fi
fi

exit 0
