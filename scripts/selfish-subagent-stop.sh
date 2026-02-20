#!/bin/bash
set -euo pipefail

# SubagentStop Hook: Log subagent completion/failure results to pipeline log
# Enables pipeline orchestrator to track task progress

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PIPELINE_FLAG="$PROJECT_DIR/.claude/.selfish-active"
RESULTS_LOG="$PROJECT_DIR/.claude/.selfish-task-results.log"

# Read hook data from stdin
INPUT=$(cat)

# Parse stop_hook_active (prevent infinite loop -- CRITICAL)
if command -v jq >/dev/null 2>&1; then
  STOP_HOOK_ACTIVE=$(printf '%s\n' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
else
  if printf '%s\n' "$INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
    STOP_HOOK_ACTIVE="true"
  else
    STOP_HOOK_ACTIVE="false"
  fi
fi

# Exit immediately if stop_hook_active is true (prevent recursive calls)
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# Exit silently if pipeline is inactive
if [ ! -f "$PIPELINE_FLAG" ]; then
  exit 0
fi

# Parse subagent info (jq fallback: grep does not support escaped quotes -- accepted limitation)
if command -v jq >/dev/null 2>&1; then
  AGENT_ID=$(printf '%s\n' "$INPUT" | jq -r '.agent_id // "unknown"' 2>/dev/null)
  AGENT_TYPE=$(printf '%s\n' "$INPUT" | jq -r '.agent_type // "unknown"' 2>/dev/null)
  LAST_MSG=$(printf '%s\n' "$INPUT" | jq -r '.last_assistant_message // "no message"' 2>/dev/null)
else
  AGENT_ID=$(printf '%s\n' "$INPUT" | grep -o '"agent_id"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"//;s/"$//' || echo "unknown")
  AGENT_TYPE=$(printf '%s\n' "$INPUT" | grep -o '"agent_type"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"//;s/"$//' || echo "unknown")
  LAST_MSG=$(printf '%s\n' "$INPUT" | grep -o '"last_assistant_message"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"//;s/"$//' | tr -d '\000-\037' || echo "no message")
fi

# Sanitize values: prevent log explosion + remove control characters
LAST_MSG=$(printf '%s\n' "$LAST_MSG" | head -1 | cut -c1-500)
AGENT_ID=$(printf '%s\n' "$AGENT_ID" | head -1 | tr -d '\n\r')
AGENT_TYPE=$(printf '%s\n' "$AGENT_TYPE" | head -1 | tr -d '\n\r' | cut -c1-100)

# Write to results log
echo "$(date +%s) [${AGENT_TYPE}] ${AGENT_ID}: ${LAST_MSG}" >> "$RESULTS_LOG"

exit 0
