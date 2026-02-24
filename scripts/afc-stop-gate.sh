#!/bin/bash
set -euo pipefail
# Stop Gate Hook: Block stop while pipeline is active and CI has not passed
# Physically prevents Claude from skipping CI and claiming "done"
#
# Gap fix: "Prompts are not enforcement" -> Physical enforcement via exit 2

# trap: Preserve exit code on abnormal termination + stderr message
# shellcheck disable=SC2329
cleanup() {
  local exit_code=$?
  if [ "$exit_code" -ne 0 ] && [ "$exit_code" -ne 2 ]; then
    echo "AFC GATE: Abnormal exit (exit code: $exit_code)" >&2
  fi
  exit "$exit_code"
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PIPELINE_FLAG="${PROJECT_DIR}/.claude/.afc-active"
CI_FLAG="${PROJECT_DIR}/.claude/.afc-ci-passed"
PHASE_FLAG="${PROJECT_DIR}/.claude/.afc-phase"

# Consume stdin (required -- pipe breaks if not consumed)
INPUT=$(cat)

# If pipeline is not active -> pass through
if [ ! -f "$PIPELINE_FLAG" ]; then
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

FEATURE="$(head -1 "$PIPELINE_FLAG" | tr -d '\n\r')"

# Check current Phase if phase file exists
CURRENT_PHASE=""
if [ -f "$PHASE_FLAG" ]; then
  CURRENT_PHASE="$(head -1 "$PHASE_FLAG" | tr -d '\n\r')"
fi

# Spec/Plan/Tasks Phase (1-3) do not require CI -> pass through
case "${CURRENT_PHASE:-}" in
  spec|plan|tasks)
    exit 0
    ;;
esac

# Implement/Review/Clean Phase (4-6) require CI to pass
if [ ! -f "$CI_FLAG" ]; then
  echo "AFC GATE: CI has not been run. Pipeline '${FEATURE:-unknown}' Phase '${CURRENT_PHASE:-unknown}' requires passing the CI gate. Run your CI command and record the timestamp in .claude/.afc-ci-passed." >&2
  exit 2
fi

# Verify CI passed within the last 10 minutes (prevent stale results)
CI_TIME="$(cat "$CI_FLAG" 2>/dev/null | head -1 | tr -dc '0-9' || true)"
CI_TIME="${CI_TIME:-0}"
NOW="$(date +%s)"
if [ "$CI_TIME" -gt 0 ]; then
  DIFF=$(( NOW - CI_TIME ))
  if [ "$DIFF" -gt 600 ]; then
    echo "AFC GATE: CI results are stale (${DIFF} seconds ago). Please run your CI command again." >&2
    exit 2
  fi
fi

exit 0
