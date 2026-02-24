#!/bin/bash
set -euo pipefail

# DAG Validator: Check task dependency graph for circular references
# Parses tasks.md and validates that depends: declarations form a valid DAG.
#
# Usage: afc-dag-validate.sh <tasks_file_path>
# Exit 0: valid DAG (no cycles)
# Exit 1: cycle detected — prints cycle path

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

# ------------------------------------------------------------------
# Parse tasks and dependencies
# ------------------------------------------------------------------

TMPDIR_WORK="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf '$TMPDIR_WORK'; :" EXIT

NODES_FILE="$TMPDIR_WORK/nodes.txt"
EDGES_FILE="$TMPDIR_WORK/edges.txt"
: > "$NODES_FILE"
: > "$EDGES_FILE"

while IFS= read -r line || [ -n "$line" ]; do
  # Match task lines: - [ ] T{NNN} or - [x] T{NNN}
  if ! printf '%s\n' "$line" | grep -qE '^\s*-\s*\[[ xX]\]\s+T[0-9]+'; then
    continue
  fi

  # Extract task ID
  task_id="$(printf '%s\n' "$line" | grep -oE 'T[0-9]+' | head -1)"
  [ -z "$task_id" ] && continue

  printf '%s\n' "$task_id" >> "$NODES_FILE"

  # Extract depends: [TXXX, TYYY] pattern
  deps_raw="$(printf '%s\n' "$line" | grep -oE 'depends:\s*\[([^]]*)\]' | sed 's/depends:[[:space:]]*\[//;s/\]//' || true)"
  if [ -n "$deps_raw" ]; then
    # Split by comma and trim
    printf '%s\n' "$deps_raw" | tr ',' '\n' | while IFS= read -r dep; do
      dep_id="$(printf '%s\n' "$dep" | grep -oE 'T[0-9]+' || true)"
      if [ -n "$dep_id" ]; then
        # Edge: dep_id → task_id (task_id depends on dep_id)
        printf '%s\t%s\n' "$dep_id" "$task_id" >> "$EDGES_FILE"
      fi
    done
  fi
done < "$TASKS_FILE"

TOTAL_TASKS=$(wc -l < "$NODES_FILE" | tr -d ' ')

if [ "$TOTAL_TASKS" -eq 0 ]; then
  printf 'Valid: no tasks found, nothing to validate\n'
  exit 0
fi

# ------------------------------------------------------------------
# DFS cycle detection using color marking
# WHITE=0 (unvisited), GRAY=1 (in stack), BLACK=2 (done)
# ------------------------------------------------------------------

COLOR_DIR="$TMPDIR_WORK/colors"
PARENT_DIR="$TMPDIR_WORK/parents"
mkdir -p "$COLOR_DIR" "$PARENT_DIR"

# Initialize all nodes as WHITE (0)
while IFS= read -r node; do
  printf '0' > "$COLOR_DIR/$node"
done < "$NODES_FILE"

CYCLE_FOUND=0
CYCLE_PATH=""

# DFS function using iteration with explicit stack (avoids bash recursion limits)
dfs_check() {
  local start="$1"
  local stack_file="$TMPDIR_WORK/stack.txt"
  printf '%s\n' "$start" > "$stack_file"

  while [ -s "$stack_file" ]; do
    # Read last line (top of stack)
    current="$(tail -1 "$stack_file")"

    color_file="$COLOR_DIR/$current"
    [ ! -f "$color_file" ] && { sed -i '' '$d' "$stack_file" 2>/dev/null || sed -i '$d' "$stack_file"; continue; }

    color="$(cat "$color_file")"

    if [ "$color" = "0" ]; then
      # Mark GRAY (visiting)
      printf '1' > "$color_file"

      # Push neighbors
      neighbors="$(grep -E "^${current}\t" "$EDGES_FILE" | cut -f2 || true)"
      if [ -n "$neighbors" ]; then
        while IFS= read -r neighbor; do
          [ -z "$neighbor" ] && continue
          nb_color_file="$COLOR_DIR/$neighbor"
          [ ! -f "$nb_color_file" ] && continue

          nb_color="$(cat "$nb_color_file")"
          if [ "$nb_color" = "1" ]; then
            # GRAY neighbor = cycle found
            CYCLE_FOUND=1
            # Build cycle path
            CYCLE_PATH="$neighbor → $current"
            # Trace back through stack
            while IFS= read -r stack_node; do
              if [ "$stack_node" = "$neighbor" ]; then
                break
              fi
            done < "$stack_file"
            CYCLE_PATH="CYCLE: $CYCLE_PATH → $neighbor"
            return
          elif [ "$nb_color" = "0" ]; then
            printf '%s\n' "$neighbor" >> "$stack_file"
          fi
        done <<EOF_NEIGHBORS
$neighbors
EOF_NEIGHBORS
      fi
    elif [ "$color" = "1" ]; then
      # All neighbors processed, mark BLACK
      printf '2' > "$color_file"
      # Pop from stack
      sed -i '' '$d' "$stack_file" 2>/dev/null || sed -i '$d' "$stack_file"
    else
      # BLACK — already done, pop
      sed -i '' '$d' "$stack_file" 2>/dev/null || sed -i '$d' "$stack_file"
    fi
  done
}

# Run DFS from each unvisited node
while IFS= read -r node; do
  color="$(cat "$COLOR_DIR/$node" 2>/dev/null || printf '0')"
  if [ "$color" = "0" ]; then
    dfs_check "$node"
    if [ "$CYCLE_FOUND" -eq 1 ]; then
      printf '%s\n' "$CYCLE_PATH"
      exit 1
    fi
  fi
done < "$NODES_FILE"

printf 'Valid: %d tasks, no circular dependencies\n' "$TOTAL_TASKS"
exit 0
