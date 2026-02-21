#!/bin/bash
set -euo pipefail

# Pipeline Management: Manage selfish pipeline state flags
# Manages flag files referenced by other hook scripts
#
# Usage:
#   selfish-pipeline-manage.sh start <feature-name>
#   selfish-pipeline-manage.sh phase <phase-name>
#   selfish-pipeline-manage.sh ci-pass
#   selfish-pipeline-manage.sh end [--force]
#   selfish-pipeline-manage.sh status

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
FLAG_DIR="$PROJECT_DIR/.claude"
PIPELINE_FLAG="$FLAG_DIR/.selfish-active"
PHASE_FLAG="$FLAG_DIR/.selfish-phase"
CI_FLAG="$FLAG_DIR/.selfish-ci-passed"
CHANGES_LOG="$FLAG_DIR/.selfish-changes.log"

# shellcheck disable=SC2329
cleanup() {
  local exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    echo "selfish-pipeline-manage: exited with code $exit_code" >&2
  fi
  exit "$exit_code"
}
trap cleanup EXIT

mkdir -p "$FLAG_DIR"

COMMAND="${1:-}"
if [ -z "$COMMAND" ]; then
  echo "Usage: $0 {start|phase|ci-pass|end|status} [args]" >&2
  exit 1
fi

case "$COMMAND" in
  start)
    FEATURE="${2:?Feature name required}"

    # Prevent duplicate execution
    if [ -f "$PIPELINE_FLAG" ]; then
      EXISTING=$(cat "$PIPELINE_FLAG")
      echo "WARNING: Pipeline already active: $EXISTING" >&2
      echo "Use '$0 end --force' to clear, or '$0 status' to check." >&2
      exit 1
    fi

    echo "$FEATURE" > "$PIPELINE_FLAG"
    echo "spec" > "$PHASE_FLAG"
    rm -f "$CI_FLAG" "$CHANGES_LOG"

    # Safety snapshot
    if cd "$PROJECT_DIR" 2>/dev/null; then
      git tag -f "selfish/pre-auto" 2>/dev/null || true
    fi

    echo "Pipeline started: $FEATURE (safety tag: selfish/pre-auto)"
    ;;

  phase)
    PHASE="${2:?Phase name required}"
    case "$PHASE" in
      spec|plan|tasks|implement|review|clean)
        echo "$PHASE" > "$PHASE_FLAG"
        rm -f "$CI_FLAG"  # Reset CI for new Phase
        echo "Phase: $PHASE"
        ;;
      *)
        echo "Invalid phase: $PHASE (valid: spec|plan|tasks|implement|review|clean)" >&2
        exit 1
        ;;
    esac
    ;;

  ci-pass)
    date +%s > "$CI_FLAG"
    echo "CI passed at $(date '+%H:%M:%S')"
    ;;

  end)
    FORCE="${2:-}"
    FEATURE=""
    if [ -f "$PIPELINE_FLAG" ]; then
      FEATURE=$(cat "$PIPELINE_FLAG")
    elif [ "$FORCE" != "--force" ]; then
      echo "No active pipeline to end." >&2
      exit 0
    fi

    rm -f "$PIPELINE_FLAG" "$PHASE_FLAG" "$CI_FLAG" "$CHANGES_LOG"
    rm -f "$FLAG_DIR/.selfish-failures.log" "$FLAG_DIR/.selfish-task-results.log" "$FLAG_DIR/.selfish-config-audit.log"

    # Clean up safety tag (on successful completion)
    if cd "$PROJECT_DIR" 2>/dev/null; then
      git tag -d "selfish/pre-auto" 2>/dev/null || true
    fi

    echo "Pipeline ended: ${FEATURE:-unknown}"
    ;;

  status)
    if [ -f "$PIPELINE_FLAG" ]; then
      echo "Active: $(cat "$PIPELINE_FLAG")"
      [ -f "$PHASE_FLAG" ] && echo "Phase: $(cat "$PHASE_FLAG")"
      [ -f "$CI_FLAG" ] && echo "CI: passed ($(cat "$CI_FLAG"))"
      if [ -f "$CHANGES_LOG" ]; then
        CHANGE_COUNT=$(wc -l < "$CHANGES_LOG" | tr -d ' ')
        echo "Changes: $CHANGE_COUNT files"
      fi
    else
      echo "No active pipeline"
    fi
    ;;

  *)
    echo "Usage: $0 {start|phase|ci-pass|end|status} [args]" >&2
    exit 1
    ;;
esac

exit 0
