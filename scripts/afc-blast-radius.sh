#!/bin/bash
set -euo pipefail

# Blast Radius Analyzer: Traces source/dependency fan-out for planned changes
# Detects circular source chains and generates an impact report.
#
# Usage: afc-blast-radius.sh <plan_file_or_dir> [project_root]
#   - plan file: parses File Change Map table to extract planned file changes
#   - directory:  scans all .sh files for dependency analysis
#
# Exit 0: analysis complete (no cycles)
# Exit 1: cycle detected or error

TMPDIR_WORK=""

# shellcheck disable=SC2329
cleanup() {
  if [ -n "$TMPDIR_WORK" ] && [ -d "$TMPDIR_WORK" ]; then
    rm -rf "$TMPDIR_WORK"
  fi
}
trap cleanup EXIT

# ── Args ──────────────────────────────────────────────────

INPUT_PATH="${1:-}"
PROJECT_ROOT="${2:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"

if [ -z "$INPUT_PATH" ]; then
  printf '[afc:blast-radius] Usage: %s <plan_file_or_dir> [project_root]\n' "$0" >&2
  exit 1
fi

if [ ! -e "$INPUT_PATH" ]; then
  printf '[afc:blast-radius] Error: path not found: %s\n' "$INPUT_PATH" >&2
  exit 1
fi

TMPDIR_WORK="$(mktemp -d)"

PLANNED_FILES="$TMPDIR_WORK/planned.txt"
ALL_DEPS="$TMPDIR_WORK/deps.txt"
DIRECT_DEPENDENTS="$TMPDIR_WORK/dependents.txt"
HOOKS_REFS="$TMPDIR_WORK/hooks_refs.txt"
FAN_OUT="$TMPDIR_WORK/fan_out.txt"
CYCLE_RESULT="$TMPDIR_WORK/cycle.txt"
: > "$PLANNED_FILES"
: > "$ALL_DEPS"
: > "$DIRECT_DEPENDENTS"
: > "$HOOKS_REFS"
: > "$FAN_OUT"
: > "$CYCLE_RESULT"

# ── Parse planned files ──────────────────────────────────

if [ -f "$INPUT_PATH" ]; then
  # Parse plan.md: extract file paths from File Change Map table
  # Format: | `path/to/file` | Action | description | ~N |
  while IFS= read -r line || [ -n "$line" ]; do
    # Match lines with backtick-delimited paths in table cells
    # shellcheck disable=SC2016
    if printf '%s\n' "$line" | grep -qE '^\|.*`[^`]+`.*\|'; then
      file_path=""
      # shellcheck disable=SC2016
      file_path=$(printf '%s\n' "$line" | sed -n 's/^|[[:space:]]*`\([^`]*\)`.*/\1/p')
      if [ -n "$file_path" ]; then
        printf '%s\n' "$file_path" >> "$PLANNED_FILES"
      fi
    fi
  done < "$INPUT_PATH"
elif [ -d "$INPUT_PATH" ]; then
  # Directory mode: scan all .sh files
  find "$INPUT_PATH" -name '*.sh' -type f 2>/dev/null | while IFS= read -r f; do
    # Make path relative to project root if possible
    rel_path="${f#"$PROJECT_ROOT"/}"
    printf '%s\n' "$rel_path" >> "$PLANNED_FILES"
  done
fi

PLANNED_COUNT=$(wc -l < "$PLANNED_FILES" | tr -d ' ')

if [ "$PLANNED_COUNT" -eq 0 ]; then
  printf 'Impact Analysis:\n'
  printf '  Planned changes: 0 files\n'
  printf '  Direct dependents: 0 files\n'
  printf '  High fan-out (>5 dependents): none\n'
  printf '  Cross-references: none\n'
  printf '  Circular dependencies: none\n'
  printf '  Total blast radius: 0 files\n'
  exit 0
fi

# ── Build source dependency map ──────────────────────────
# Scan all .sh files in the project for `source` and `. ` directives

SCRIPTS_DIR="$PROJECT_ROOT/scripts"
ALL_SH_FILES="$TMPDIR_WORK/all_sh.txt"
: > "$ALL_SH_FILES"

# Collect all shell scripts in the project
if [ -d "$SCRIPTS_DIR" ]; then
  find "$SCRIPTS_DIR" -name '*.sh' -type f 2>/dev/null >> "$ALL_SH_FILES"
fi
# Also check spec/ directory for test files that may source scripts
if [ -d "$PROJECT_ROOT/spec" ]; then
  find "$PROJECT_ROOT/spec" -name '*.sh' -type f 2>/dev/null >> "$ALL_SH_FILES"
fi

# For each shell file, extract what it sources
# Format: sourcer<TAB>sourced_basename
while IFS= read -r sh_file || [ -n "$sh_file" ]; do
  [ -z "$sh_file" ] && continue
  [ ! -f "$sh_file" ] && continue

  sourcer_rel="${sh_file#"$PROJECT_ROOT"/}"

  # Match: source "path" or . "path" (with various quoting)
  # Lines like: . "$(dirname "$0")/afc-state.sh" have nested quotes,
  # so we extract the .sh basename directly from the line.
  while IFS= read -r src_line || [ -n "$src_line" ]; do
    [ -z "$src_line" ] && continue

    # Extract the last .sh filename from the source line
    sourced_base=""
    sourced_base=$(printf '%s\n' "$src_line" | grep -oE '[a-zA-Z0-9_.-]+\.sh' | tail -1 || true)
    [ -z "$sourced_base" ] && continue

    # Find the actual file path that matches this basename
    sourced_rel=""
    if [ -d "$SCRIPTS_DIR" ]; then
      sourced_match=$(find "$SCRIPTS_DIR" -name "$sourced_base" -type f 2>/dev/null | head -1 || true)
      if [ -n "$sourced_match" ]; then
        sourced_rel="${sourced_match#"$PROJECT_ROOT"/}"
      fi
    fi
    if [ -z "$sourced_rel" ]; then
      # Try spec/ or other dirs
      sourced_match=$(find "$PROJECT_ROOT" -name "$sourced_base" -type f -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/vendor/*" 2>/dev/null | head -1 || true)
      if [ -n "$sourced_match" ]; then
        sourced_rel="${sourced_match#"$PROJECT_ROOT"/}"
      else
        sourced_rel="scripts/$sourced_base"
      fi
    fi

    # Record: sourcer sources sourced_rel
    printf '%s\t%s\n' "$sourcer_rel" "$sourced_rel" >> "$ALL_DEPS"
  done < <(grep -nE '^\s*(\.|source)\s+' "$sh_file" 2>/dev/null || true)
done < "$ALL_SH_FILES"

# ── Find direct dependents of planned files ──────────────

while IFS= read -r planned || [ -n "$planned" ]; do
  [ -z "$planned" ] && continue
  planned_base="$(basename "$planned")"

  # Find scripts that source this planned file
  # shellcheck disable=SC2002
  while IFS=$'\t' read -r sourcer sourced || [ -n "$sourcer" ]; do
    sourced_base="$(basename "$sourced" 2>/dev/null || true)"
    if [ "$sourced_base" = "$planned_base" ] || [ "$sourced" = "$planned" ]; then
      printf '%s\n' "$sourcer" >> "$DIRECT_DEPENDENTS"
    fi
  done < "$ALL_DEPS"
done < "$PLANNED_FILES"

# Deduplicate dependents, exclude files already in planned list
if [ -s "$DIRECT_DEPENDENTS" ]; then
  sort -u "$DIRECT_DEPENDENTS" > "$TMPDIR_WORK/dependents_unique.txt"
  # Remove planned files from dependents (they are not "additional" impact)
  comm -23 "$TMPDIR_WORK/dependents_unique.txt" <(sort "$PLANNED_FILES") > "$DIRECT_DEPENDENTS" 2>/dev/null || \
    mv "$TMPDIR_WORK/dependents_unique.txt" "$DIRECT_DEPENDENTS"
fi

DEPENDENT_COUNT=$(wc -l < "$DIRECT_DEPENDENTS" | tr -d ' ')

# ── Compute fan-out per planned file ─────────────────────

while IFS= read -r planned || [ -n "$planned" ]; do
  [ -z "$planned" ] && continue
  planned_base="$(basename "$planned")"

  count=0
  while IFS=$'\t' read -r _sourcer sourced || [ -n "$_sourcer" ]; do
    sourced_base="$(basename "$sourced" 2>/dev/null || true)"
    if [ "$sourced_base" = "$planned_base" ] || [ "$sourced" = "$planned" ]; then
      count=$((count + 1))
    fi
  done < "$ALL_DEPS"

  if [ "$count" -gt 0 ]; then
    printf '%d\t%s\n' "$count" "$planned" >> "$FAN_OUT"
  fi
done < "$PLANNED_FILES"

# ── Check hooks.json cross-references ────────────────────

HOOKS_FILE="$PROJECT_ROOT/hooks/hooks.json"
if [ -f "$HOOKS_FILE" ]; then
  while IFS= read -r planned || [ -n "$planned" ]; do
    [ -z "$planned" ] && continue
    planned_base="$(basename "$planned")"

    if grep -q "$planned_base" "$HOOKS_FILE" 2>/dev/null; then
      printf '%s\n' "$planned_base" >> "$HOOKS_REFS"
    fi
  done < "$PLANNED_FILES"
fi

# Deduplicate hooks refs
if [ -s "$HOOKS_REFS" ]; then
  sort -u "$HOOKS_REFS" > "$TMPDIR_WORK/hooks_unique.txt"
  mv "$TMPDIR_WORK/hooks_unique.txt" "$HOOKS_REFS"
fi

# ── Cycle detection ──────────────────────────────────────
# Detect cycles using reachability: for each edge A→B, check if B can reach A.
# Simple and portable — no file-based DFS or md5 hashing needed.

CYCLE_FOUND=0

if [ -s "$ALL_DEPS" ]; then
  # Check each edge: if A sources B, does B (transitively) source A?
  while IFS=$'\t' read -r src dst || [ -n "$src" ]; do
    [ -z "$src" ] || [ -z "$dst" ] && continue

    # BFS from dst to see if we can reach src
    visited="$TMPDIR_WORK/visited.txt"
    queue="$TMPDIR_WORK/queue.txt"
    printf '%s\n' "$dst" > "$queue"
    : > "$visited"

    while [ -s "$queue" ]; do
      current=$(head -1 "$queue")
      # Remove first line from queue
      tail -n +2 "$queue" > "$TMPDIR_WORK/queue_tmp.txt"
      mv "$TMPDIR_WORK/queue_tmp.txt" "$queue"

      # Skip if already visited
      if grep -qxF "$current" "$visited" 2>/dev/null; then
        continue
      fi
      printf '%s\n' "$current" >> "$visited"

      # Check if we reached src → cycle
      if [ "$current" = "$src" ]; then
        CYCLE_FOUND=1
        # Build cycle path from visited trail
        cycle_str="CYCLE: ${src} -> ${dst} -> ${src}"
        printf '%s\n' "$cycle_str" > "$CYCLE_RESULT"
        break
      fi

      # Enqueue neighbors (files that current sources)
      while IFS=$'\t' read -r s d || [ -n "$s" ]; do
        if [ "$s" = "$current" ] && [ -n "$d" ]; then
          if ! grep -qxF "$d" "$visited" 2>/dev/null; then
            printf '%s\n' "$d" >> "$queue"
          fi
        fi
      done < "$ALL_DEPS"
    done

    if [ "$CYCLE_FOUND" -eq 1 ]; then
      break
    fi
  done < "$ALL_DEPS"
fi

# ── Generate Report ──────────────────────────────────────

# Collect all impacted files (planned + dependents + hooks-referenced scripts)
ALL_IMPACTED="$TMPDIR_WORK/all_impacted.txt"
cat "$PLANNED_FILES" > "$ALL_IMPACTED"
if [ -s "$DIRECT_DEPENDENTS" ]; then
  cat "$DIRECT_DEPENDENTS" >> "$ALL_IMPACTED"
fi
# hooks.json itself is impacted if any planned script is referenced
if [ -s "$HOOKS_REFS" ]; then
  printf 'hooks/hooks.json\n' >> "$ALL_IMPACTED"
fi
sort -u "$ALL_IMPACTED" > "$TMPDIR_WORK/all_impacted_unique.txt"
mv "$TMPDIR_WORK/all_impacted_unique.txt" "$ALL_IMPACTED"

TOTAL_RADIUS=$(wc -l < "$ALL_IMPACTED" | tr -d ' ')

printf 'Impact Analysis:\n'
printf '  Planned changes: %d files\n' "$PLANNED_COUNT"
printf '  Direct dependents: %d files\n' "$DEPENDENT_COUNT"

# High fan-out section
HIGH_FANOUT_PRINTED=0
if [ -s "$FAN_OUT" ]; then
  while IFS=$'\t' read -r count file || [ -n "$count" ]; do
    [ -z "$count" ] && continue
    if [ "$count" -gt 5 ]; then
      if [ "$HIGH_FANOUT_PRINTED" -eq 0 ]; then
        printf '  High fan-out (>5 dependents):\n'
        HIGH_FANOUT_PRINTED=1
      fi
      printf '    - %s (sourced by %d scripts)\n' "$file" "$count"
    fi
  done < <(sort -rn "$FAN_OUT")
fi
if [ "$HIGH_FANOUT_PRINTED" -eq 0 ]; then
  printf '  High fan-out (>5 dependents): none\n'
fi

# Cross-references section
if [ -s "$HOOKS_REFS" ]; then
  refs_list=""
  while IFS= read -r ref || [ -n "$ref" ]; do
    if [ -z "$refs_list" ]; then
      refs_list="$ref"
    else
      refs_list="$refs_list, $ref"
    fi
  done < "$HOOKS_REFS"
  printf '  Cross-references:\n'
  printf '    - hooks.json references: %s\n' "$refs_list"
else
  printf '  Cross-references: none\n'
fi

# Circular dependencies section
if [ "$CYCLE_FOUND" -eq 1 ] && [ -s "$CYCLE_RESULT" ]; then
  cycle_path=$(cat "$CYCLE_RESULT")
  printf '  Circular dependencies: %s\n' "$cycle_path"
else
  printf '  Circular dependencies: none\n'
fi

printf '  Total blast radius: %d files\n' "$TOTAL_RADIUS"

# Exit code: 1 if cycles found
if [ "$CYCLE_FOUND" -eq 1 ]; then
  exit 1
fi

exit 0
