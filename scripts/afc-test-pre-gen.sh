#!/bin/bash
set -euo pipefail

# afc-test-pre-gen.sh — Generate ShellSpec test skeletons for testable tasks
# Reads a tasks.md file, identifies tasks targeting .sh scripts, and generates
# pending ShellSpec spec files for scripts that lack test coverage.
#
# Usage: afc-test-pre-gen.sh <tasks_file> [output_dir]
#   tasks_file : path to a tasks.md file
#   output_dir : directory for generated spec files (default: spec/ relative to project root)
# Exit: 0 = success, 1 = error

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

# --- Argument validation ---
TASKS_FILE="${1:-}"
if [ -z "$TASKS_FILE" ]; then
  printf '[afc:test-pre-gen] Usage: %s <tasks_file> [output_dir]\n' "$0" >&2
  exit 1
fi

if [ ! -f "$TASKS_FILE" ]; then
  printf '[afc:test-pre-gen] Error: file not found: %s\n' "$TASKS_FILE" >&2
  exit 1
fi

OUTPUT_DIR="${2:-${PROJECT_DIR}/spec}"
mkdir -p "$OUTPUT_DIR"

# --- Counters ---
TASKS_ANALYZED=0
TESTABLE_SH=0
SKIPPED_NON_SH=0
ALREADY_EXISTS=0
GENERATED=0
GENERATED_FILES=""

# --- Parse tasks ---
# Match lines like: - [ ] T001 ... `scripts/some-name.sh`
# Also handles: - [x] T001 ... (checked tasks are still analyzed)
while IFS= read -r line || [ -n "$line" ]; do
  # Only match task lines: - [ ] TNNN or - [x] TNNN
  if ! printf '%s\n' "$line" | grep -qE '^\s*-\s*\[[ xX]\]\s+T[0-9]+'; then
    continue
  fi

  TASKS_ANALYZED=$((TASKS_ANALYZED + 1))

  # Extract all backtick-quoted file paths from the line
  # shellcheck disable=SC2207,SC2016
  PATHS=($(printf '%s\n' "$line" | grep -oE '`[^`]+`' | tr -d '`'))

  if [ ${#PATHS[@]} -eq 0 ]; then
    continue
  fi

  HAS_SH_TARGET=false
  for fpath in "${PATHS[@]}"; do
    # Only process .sh files under scripts/
    case "$fpath" in
      scripts/*.sh)
        HAS_SH_TARGET=true
        TESTABLE_SH=$((TESTABLE_SH + 1))

        # Extract script name from path (e.g., scripts/afc-blast-radius.sh -> afc-blast-radius.sh)
        SCRIPT_NAME="${fpath##*/}"
        # Derive spec name (e.g., afc-blast-radius.sh -> afc-blast-radius_spec.sh)
        SPEC_NAME="${SCRIPT_NAME%.sh}_spec.sh"
        SPEC_PATH="${OUTPUT_DIR}/${SPEC_NAME}"

        # Check if spec already exists
        if [ -f "$SPEC_PATH" ]; then
          ALREADY_EXISTS=$((ALREADY_EXISTS + 1))
          printf '[afc:test-pre-gen] Skip (exists): %s\n' "$SPEC_NAME" >&2
          continue
        fi

        # Generate ShellSpec skeleton
        cat > "$SPEC_PATH" << SKELETON
#!/bin/bash
# shellcheck shell=bash
# Auto-generated test skeleton for ${SCRIPT_NAME}
# TODO: Replace Pending examples with real tests

Describe "${SCRIPT_NAME}"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "\$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "basic usage"
    It "exits 0 on valid input"
      Pending "implement test"
    End

    It "exits 1 on missing arguments"
      Pending "implement test"
    End
  End
End
SKELETON

        GENERATED=$((GENERATED + 1))
        if [ -n "$GENERATED_FILES" ]; then
          GENERATED_FILES="${GENERATED_FILES}, ${SPEC_NAME}"
        else
          GENERATED_FILES="${SPEC_NAME}"
        fi
        printf '[afc:test-pre-gen] Generated: %s\n' "$SPEC_NAME" >&2
        ;;
      *)
        # Non-.sh file — counted once per task below
        ;;
    esac
  done

  if [ "$HAS_SH_TARGET" = false ]; then
    SKIPPED_NON_SH=$((SKIPPED_NON_SH + 1))
  fi
done < "$TASKS_FILE"

# --- Summary report ---
printf 'Test pre-generation:\n'
printf '  Tasks analyzed: %d\n' "$TASKS_ANALYZED"
printf '  Testable (.sh): %d\n' "$TESTABLE_SH"
printf '  Skipped (non-.sh): %d\n' "$SKIPPED_NON_SH"
printf '  Already exists: %d\n' "$ALREADY_EXISTS"
printf '  Generated: %d skeletons\n' "$GENERATED"
if [ -n "$GENERATED_FILES" ]; then
  printf '  Files: %s\n' "$GENERATED_FILES"
else
  printf '  Files: (none)\n'
fi
