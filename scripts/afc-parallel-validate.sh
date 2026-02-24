#!/bin/bash
set -euo pipefail

# Parallel Task Validator: Parse tasks.md and check for file path conflicts
# among [P]-marked (parallel) tasks within the same phase.
#
# Usage: afc-parallel-validate.sh <tasks_file_path>
# Exit 0: valid (no overlaps, or no [P] tasks found)
# Exit 1: overlaps detected — prints conflict details

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

# PROJECT_DIR kept for convention consistency with other afc scripts
# shellcheck disable=SC2034
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

TASKS_FILE="${1:-}"
if [ -z "$TASKS_FILE" ]; then
  printf 'Usage: %s <tasks_file_path>\n' "$0" >&2
  exit 1
fi

if [ ! -f "$TASKS_FILE" ]; then
  printf 'Error: file not found: %s\n' "$TASKS_FILE" >&2
  exit 1
fi

# ------------------------------------------------------------------
# Parse phases and [P] tasks
# Phase headers match:   ## Phase N: ...
# Task lines match:      - [ ] T{NNN} [P] {desc} `{path}` ...
# ------------------------------------------------------------------

current_phase=""
total_p_tasks=0
conflict_found=0
conflict_messages=""

# We process line by line using a while loop.
# Two associative arrays are used per phase to track:
#   phase_files[file_path]="task_id" — first task that claimed the file
#   phase_tasks[file_path]="task_id" — same map for conflict lookup
# Because bash 3 (macOS default) lacks associative arrays we use temp files.

TMPDIR_WORK="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf '$TMPDIR_WORK'; :" EXIT

# File that accumulates seen paths for the current phase:
#   format: <file_path><TAB><task_id>
phase_index="$TMPDIR_WORK/phase_index.tsv"

flush_phase() {
  # Reset the per-phase index for a new phase
  : > "$phase_index"
}

flush_phase

while IFS= read -r line || [ -n "$line" ]; do
  # Detect phase header: ## Phase N: ...
  if printf '%s\n' "$line" | grep -qE '^## Phase [0-9]+'; then
    # Extract phase number
    current_phase="$(printf '%s\n' "$line" | sed 's/^## Phase \([0-9]*\).*/\1/')"
    flush_phase
    continue
  fi

  # Only process [P]-marked task lines when inside a phase
  [ -z "$current_phase" ] && continue

  # Match task lines containing [P] marker
  if ! printf '%s\n' "$line" | grep -qE '^\s*-\s*\[[ xX]\]\s+T[0-9]+\s+\[P\]'; then
    continue
  fi

  # Extract task ID: first T{NNN} token
  task_id="$(printf '%s\n' "$line" | grep -oE 'T[0-9]+' | head -1)"
  [ -z "$task_id" ] && continue

  # Extract backtick-wrapped file path (first occurrence)
  file_path="$(printf '%s\n' "$line" | sed "s/.*\`\([^\`]*\)\`.*/\1/" | head -1)"

  # Skip if no file path found or extraction failed (line unchanged means no backtick)
  if [ -z "$file_path" ] || [ "$file_path" = "$line" ]; then
    total_p_tasks=$((total_p_tasks + 1))
    continue
  fi

  total_p_tasks=$((total_p_tasks + 1))

  # Look for this file_path in current phase index
  existing_task="$(grep -F "${file_path}	" "$phase_index" | cut -f2 | head -1 || true)"

  if [ -n "$existing_task" ]; then
    # Conflict detected
    conflict_found=1
    msg="CONFLICT: Phase ${current_phase} — ${existing_task} and ${task_id} both target ${file_path}"
    if [ -z "$conflict_messages" ]; then
      conflict_messages="$msg"
    else
      conflict_messages="${conflict_messages}
${msg}"
    fi
  else
    # Record this file path for the current phase
    printf '%s\t%s\n' "$file_path" "$task_id" >> "$phase_index"
  fi

done < "$TASKS_FILE"

# Count distinct phases that had [P] tasks by checking how many phase headers
# had at least one [P] task line (reparse for count only)
phases_with_p=0
current_phase_count=""
phase_had_p=0

while IFS= read -r line || [ -n "$line" ]; do
  if printf '%s\n' "$line" | grep -qE '^## Phase [0-9]+'; then
    if [ "$phase_had_p" -eq 1 ]; then
      phases_with_p=$((phases_with_p + 1))
    fi
    current_phase_count="$(printf '%s\n' "$line" | sed 's/^## Phase \([0-9]*\).*/\1/')"
    phase_had_p=0
    continue
  fi
  [ -z "$current_phase_count" ] && continue
  if printf '%s\n' "$line" | grep -qE '^\s*-\s*\[[ xX]\]\s+T[0-9]+\s+\[P\]'; then
    phase_had_p=1
  fi
done < "$TASKS_FILE"

# Flush last phase
if [ "$phase_had_p" -eq 1 ]; then
  phases_with_p=$((phases_with_p + 1))
fi

# ------------------------------------------------------------------
# Output
# ------------------------------------------------------------------

if [ "$total_p_tasks" -eq 0 ]; then
  printf 'Valid: no [P] tasks found, nothing to validate\n'
  exit 0
fi

if [ "$conflict_found" -eq 1 ]; then
  printf '%s\n' "$conflict_messages"
  exit 1
fi

printf 'Valid: %d [P] tasks across %d phases, no file overlaps\n' \
  "$total_p_tasks" "$phases_with_p"
exit 0
