#!/bin/bash
set -euo pipefail
# TaskCompleted Gate Hook: Block task completion while pipeline is active and CI has not passed
# Physically prevents Claude from skipping CI and completing a task
#
# Gap fix: "Prompts are not enforcement" -> Physical enforcement via exit 2

# trap: Preserve exit code on abnormal termination + stderr message
# shellcheck disable=SC2329
cleanup() {
  local exit_code=$?
  if [ "$exit_code" -ne 0 ] && [ "$exit_code" -ne 2 ]; then
    echo "SELFISH TASK GATE: Abnormal exit (exit code: $exit_code)" >&2
  fi
  exit "$exit_code"
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PIPELINE_FLAG="${PROJECT_DIR}/.claude/.selfish-active"
CI_FLAG="${PROJECT_DIR}/.claude/.selfish-ci-passed"
PHASE_FLAG="${PROJECT_DIR}/.claude/.selfish-phase"

# If pipeline is not active -> pass through
if [ ! -f "$PIPELINE_FLAG" ]; then
  exit 0
fi

FEATURE="$(head -1 "$PIPELINE_FLAG" | tr -d '\n\r')"

# Check current Phase if phase file exists
CURRENT_PHASE=""
if [ -f "$PHASE_FLAG" ]; then
  CURRENT_PHASE="$(cat "$PHASE_FLAG")"
fi
CURRENT_PHASE="${CURRENT_PHASE:-}"

# Spec/Plan/Tasks Phase (1-3) do not require CI -> pass through
case "${CURRENT_PHASE:-}" in
  spec|plan|tasks)
    exit 0
    ;;
esac

# Implement/Review/Clean Phase (4-6) require CI to pass
if [ ! -f "$CI_FLAG" ]; then
  echo "SELFISH TASK GATE: yarn ci has not been run. Pipeline '${FEATURE:-unknown}' Phase '${CURRENT_PHASE:-unknown}' requires passing the CI gate. Run yarn ci and record the timestamp in .claude/.selfish-ci-passed." >&2
  exit 2
fi

# Verify CI passed within the last 10 minutes (prevent stale results)
CI_TIME="$(cat "$CI_FLAG" 2>/dev/null | head -1 | tr -dc '0-9')"
CI_TIME="${CI_TIME:-0}"
NOW="$(date +%s)"
if [ "$CI_TIME" -gt 0 ]; then
  DIFF=$(( NOW - CI_TIME ))
  if [ "$DIFF" -gt 600 ]; then
    echo "SELFISH TASK GATE: CI results are stale (${DIFF} seconds ago). Please run yarn ci again." >&2
    exit 2
  fi
fi

exit 0
