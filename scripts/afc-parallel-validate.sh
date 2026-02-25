#!/bin/bash
set -euo pipefail

# Parallel Task Validator: Parse tasks.md and check for file path conflicts
# among [P]-marked (parallel) tasks within the same phase.
# Calls Node.js ESM version if available, falls back to bash implementation.
#
# Usage: afc-parallel-validate.sh <tasks_file_path>
# Exit 0: valid (no overlaps, or no [P] tasks found)
# Exit 1: overlaps detected — prints conflict details

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

TASKS_FILE="${1:-}"
if [ -z "$TASKS_FILE" ]; then
  printf 'Usage: %s <tasks_file_path>\n' "$0" >&2
  exit 1
fi

if [ ! -f "$TASKS_FILE" ]; then
  printf 'Error: file not found: %s\n' "$TASKS_FILE" >&2
  exit 1
fi

# --- Node.js fast path ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if command -v node >/dev/null 2>&1; then
  node "$SCRIPT_DIR/afc-parallel-validate.mjs" "$TASKS_FILE"
  exit $?
fi

# --- Bash fallback ---

current_phase=""
total_p_tasks=0
conflict_found=0
conflict_messages=""

TMPDIR_WORK="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf '$TMPDIR_WORK'; :" EXIT

phase_index="$TMPDIR_WORK/phase_index.tsv"

flush_phase() {
  : > "$phase_index"
}

flush_phase

while IFS= read -r line || [ -n "$line" ]; do
  if printf '%s\n' "$line" | grep -qE '^## Phase [0-9]+'; then
    current_phase="$(printf '%s\n' "$line" | sed 's/^## Phase \([0-9]*\).*/\1/')"
    flush_phase
    continue
  fi

  [ -z "$current_phase" ] && continue

  if ! printf '%s\n' "$line" | grep -qE '^\s*-\s*\[[ xX]\]\s+T[0-9]+\s+\[P\]'; then
    continue
  fi

  task_id="$(printf '%s\n' "$line" | grep -oE 'T[0-9]+' | head -1)"
  [ -z "$task_id" ] && continue

  # shellcheck disable=SC2016
  file_paths_raw="$(printf '%s\n' "$line" | grep -oE '`[^`]+`' | sed 's/`//g' || true)"
  file_paths=""
  if [ -n "$file_paths_raw" ]; then
    file_paths="$(printf '%s\n' "$file_paths_raw" | grep -E '[/.]' || true)"
  fi

  if [ -z "$file_paths" ]; then
    total_p_tasks=$((total_p_tasks + 1))
    continue
  fi

  total_p_tasks=$((total_p_tasks + 1))

  while IFS= read -r file_path; do
    [ -z "$file_path" ] && continue

    existing_task="$(grep -F "${file_path}	" "$phase_index" | cut -f2 | head -1 || true)"

    if [ -n "$existing_task" ]; then
      conflict_found=1
      msg="CONFLICT: Phase ${current_phase} — ${existing_task} and ${task_id} both target ${file_path}"
      if [ -z "$conflict_messages" ]; then
        conflict_messages="$msg"
      else
        conflict_messages="${conflict_messages}
${msg}"
      fi
    else
      printf '%s\t%s\n' "$file_path" "$task_id" >> "$phase_index"
    fi
  done <<EOF_PATHS
$file_paths
EOF_PATHS

done < "$TASKS_FILE"

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

if [ "$phase_had_p" -eq 1 ]; then
  phases_with_p=$((phases_with_p + 1))
fi

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
