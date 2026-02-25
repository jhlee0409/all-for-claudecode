#!/bin/bash
set -euo pipefail
# Stop TODO Check: Scan recently changed files for leftover TODO/FIXME/HACK
# Replaces the haiku agent hook — runs as command for zero-overhead when pipeline inactive.
#
# Returns exit 2 (block stop) if unresolved markers found in pipeline files.
# Returns exit 0 (allow stop) otherwise.

# shellcheck source=afc-state.sh
. "$(dirname "$0")/afc-state.sh"

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

# Consume stdin
INPUT=$(cat)

# Exit immediately if pipeline is not active (zero overhead)
if ! afc_state_is_active; then
  exit 0
fi

# Parse stop_hook_active to prevent infinite loop
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

# Read current phase — only check in implementation/review/clean phases
CURRENT_PHASE="$(afc_state_read phase || echo '')"
if afc_is_ci_exempt "${CURRENT_PHASE:-}"; then
  exit 0
fi

# Read changed files from state
CHANGES=""
CHANGES=$(afc_state_read_changes 2>/dev/null || true)

if [ -z "$CHANGES" ]; then
  exit 0
fi

# Check up to 5 recently changed files for TODO/FIXME/HACK markers
FOUND_MARKERS=""
COUNT=0
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

while IFS= read -r file_path; do
  [ -z "$file_path" ] && continue
  COUNT=$((COUNT + 1))
  [ "$COUNT" -gt 5 ] && break

  FULL_PATH="$PROJECT_DIR/$file_path"
  [ -f "$FULL_PATH" ] || continue

  MARKERS=$(grep -nE '\b(TODO|FIXME|HACK)\b' "$FULL_PATH" 2>/dev/null | head -3 || true)
  if [ -n "$MARKERS" ]; then
    FOUND_MARKERS="${FOUND_MARKERS}${file_path}:\n${MARKERS}\n\n"
  fi
done <<< "$CHANGES"

if [ -n "$FOUND_MARKERS" ]; then
  printf "[afc:todo-check] Unresolved markers found in changed files:\n%b" "$FOUND_MARKERS" >&2
  printf "[afc:todo-check] Resolve TODO/FIXME/HACK markers before completing the pipeline.\n" >&2
  exit 2
fi

exit 0
