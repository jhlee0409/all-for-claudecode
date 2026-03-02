#!/bin/bash
set -euo pipefail

# DAG Validator: Check task dependency graph for circular references
# Calls Node.js ESM version if available, falls back to bash implementation.
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

# --- Node.js fast path ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if command -v node >/dev/null 2>&1; then
  node "$SCRIPT_DIR/afc-dag-validate.mjs" "$TASKS_FILE"
  exit $?
fi

# --- Bash fallback ---

# Parse tasks and dependencies
TMPDIR_WORK="$(mktemp -d)"
# shellcheck disable=SC2329
cleanup() { rm -rf "$TMPDIR_WORK"; }
trap cleanup EXIT

NODES_FILE="$TMPDIR_WORK/nodes.txt"
EDGES_FILE="$TMPDIR_WORK/edges.txt"
: > "$NODES_FILE"
: > "$EDGES_FILE"

while IFS= read -r line || [ -n "$line" ]; do
  if ! printf '%s\n' "$line" | grep -qE '^\s*-\s*\[[ xX]\]\s+T[0-9]+'; then
    continue
  fi

  task_id="$(printf '%s\n' "$line" | grep -oE 'T[0-9]+' | head -1)"
  [ -z "$task_id" ] && continue

  printf '%s\n' "$task_id" >> "$NODES_FILE"

  deps_raw="$(printf '%s\n' "$line" | grep -oE 'depends:\s*\[([^]]*)\]' | sed 's/depends:[[:space:]]*\[//;s/\]//' || true)"
  if [ -n "$deps_raw" ]; then
    printf '%s\n' "$deps_raw" | tr ',' '\n' | while IFS= read -r dep; do
      dep_id="$(printf '%s\n' "$dep" | grep -oE 'T[0-9]+' || true)"
      if [ -n "$dep_id" ]; then
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

# DFS cycle detection using color marking
COLOR_DIR="$TMPDIR_WORK/colors"
mkdir -p "$COLOR_DIR"

while IFS= read -r node; do
  printf '0' > "$COLOR_DIR/$node"
done < "$NODES_FILE"

CYCLE_FOUND=0
CYCLE_PATH=""

dfs_check() {
  local start="$1"
  local stack_file="$TMPDIR_WORK/stack.txt"
  printf '%s\n' "$start" > "$stack_file"

  while [ -s "$stack_file" ]; do
    current="$(tail -1 "$stack_file")"

    color_file="$COLOR_DIR/$current"
    [ ! -f "$color_file" ] && { sed -i '' '$d' "$stack_file" 2>/dev/null || sed -i '$d' "$stack_file"; continue; }

    color="$(cat "$color_file")"

    if [ "$color" = "0" ]; then
      printf '1' > "$color_file"

      neighbors="$(grep -E "^${current}	" "$EDGES_FILE" | cut -f2 || true)"
      if [ -n "$neighbors" ]; then
        while IFS= read -r neighbor; do
          [ -z "$neighbor" ] && continue
          nb_color_file="$COLOR_DIR/$neighbor"
          [ ! -f "$nb_color_file" ] && continue

          nb_color="$(cat "$nb_color_file")"
          if [ "$nb_color" = "1" ]; then
            CYCLE_FOUND=1
            CYCLE_PATH="CYCLE: $neighbor → $current → $neighbor"
            return
          elif [ "$nb_color" = "0" ]; then
            printf '%s\n' "$neighbor" >> "$stack_file"
          fi
        done <<EOF_NEIGHBORS
$neighbors
EOF_NEIGHBORS
      fi
    elif [ "$color" = "1" ]; then
      printf '2' > "$color_file"
      sed -i '' '$d' "$stack_file" 2>/dev/null || sed -i '$d' "$stack_file"
    else
      sed -i '' '$d' "$stack_file" 2>/dev/null || sed -i '$d' "$stack_file"
    fi
  done
}

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
