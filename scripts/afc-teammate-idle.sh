#!/bin/bash
set -euo pipefail
# TeammateIdle Hook: Block idle during implement/review Phase while pipeline is active
# Physically prevents Claude from stopping mid-task
#
# Gap fix: "Prompts are not enforcement" -> Physical enforcement via exit 2

# trap: Preserve exit code on abnormal termination + stderr message
# shellcheck disable=SC2329
cleanup() {
  local exit_code=$?
  if [ "$exit_code" -ne 0 ] && [ "$exit_code" -ne 2 ]; then
    echo "AFC TEAMMATE GATE: Abnormal exit (exit code: $exit_code)" >&2
  fi
  exit "$exit_code"
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PIPELINE_FLAG="${PROJECT_DIR}/.claude/.afc-active"
PHASE_FLAG="${PROJECT_DIR}/.claude/.afc-phase"

# Consume stdin (required -- pipe breaks if not consumed)
cat > /dev/null

# If pipeline is not active -> pass through
if [ ! -f "$PIPELINE_FLAG" ]; then
  exit 0
fi

FEATURE="$(head -1 "$PIPELINE_FLAG" | tr -d '\n\r')"

# Check current Phase if phase file exists
CURRENT_PHASE=""
if [ -f "$PHASE_FLAG" ]; then
  CURRENT_PHASE="$(head -1 "$PHASE_FLAG" | tr -d '\n\r')"
fi
CURRENT_PHASE="${CURRENT_PHASE:-}"

# Block idle during implement/review Phase -> force work to continue
case "${CURRENT_PHASE:-}" in
  implement|review)
    echo "AFC TEAMMATE GATE: Pipeline '${FEATURE:-unknown}' Phase '${CURRENT_PHASE:-unknown}' is active. Please complete the task." >&2
    exit 2
    ;;
  *)
    exit 0
    ;;
esac
