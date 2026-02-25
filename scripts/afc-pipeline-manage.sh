#!/bin/bash
set -euo pipefail

# Pipeline Management: Manage afc pipeline state
# Uses .afc-state.json for all state (replaces legacy flag files)
#
# Usage:
#   afc-pipeline-manage.sh start <feature-name>
#   afc-pipeline-manage.sh phase <phase-name>
#   afc-pipeline-manage.sh ci-pass
#   afc-pipeline-manage.sh end [--force]
#   afc-pipeline-manage.sh status
#   afc-pipeline-manage.sh log <event_type> <message>
#   afc-pipeline-manage.sh phase-tag <phase_number>
#   afc-pipeline-manage.sh phase-tag-clean

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
FLAG_DIR="$PROJECT_DIR/.claude"

# Source state library
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=afc-state.sh
. "$SCRIPT_DIR/afc-state.sh"

# shellcheck disable=SC2329
cleanup() {
  local exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    echo "[afc:pipeline] Abnormal exit (code: $exit_code)" >&2
  fi
  exit "$exit_code"
}
trap cleanup EXIT

mkdir -p "$FLAG_DIR"

COMMAND="${1:-}"
if [ -z "$COMMAND" ]; then
  echo "[afc] Usage: $0 {start|phase|ci-pass|end|status} [args]" >&2
  exit 1
fi

case "$COMMAND" in
  start)
    if [ -z "${2:-}" ]; then
      echo "[afc:pipeline] Feature name required" >&2
      exit 1
    fi
    # Sanitize feature name (strip newlines, path traversal, limit length)
    FEATURE=$(printf '%s' "$2" | tr -d '\n\r/"\\&' | cut -c1-100)
    if [ -z "$FEATURE" ]; then
      echo "[afc:pipeline] Feature name invalid after sanitization" >&2
      exit 1
    fi

    # Prevent duplicate execution
    if afc_state_is_active; then
      EXISTING=$(afc_state_read feature || echo "unknown")
      echo "[afc] WARNING: Pipeline already active: $EXISTING" >&2
      echo "  → Use '$0 end --force' to clear, or '$0 status' to check" >&2
      exit 1
    fi

    afc_state_init "$FEATURE"

    # Safety snapshot
    if cd "$PROJECT_DIR" 2>/dev/null; then
      git tag -f "afc/pre-auto" 2>/dev/null || true
    fi

    echo "Pipeline started: $FEATURE (safety tag: afc/pre-auto)"
    ;;

  phase)
    PHASE="${2:?Phase name required}"
    if afc_is_valid_phase "$PHASE"; then
      afc_state_write "phase" "$PHASE"
      afc_state_invalidate_ci
      afc_state_checkpoint "$PHASE"
      echo "Phase: $PHASE"
    else
      printf "[afc:pipeline] Invalid phase: %s\n  → Valid phases: %s\n" "$PHASE" "$AFC_VALID_PHASES" >&2
      exit 1
    fi
    ;;

  ci-pass)
    afc_state_ci_pass
    echo "CI passed at $(date '+%H:%M:%S')"
    ;;

  end)
    FORCE="${2:-}"
    FEATURE=""
    if afc_state_is_active; then
      FEATURE=$(afc_state_read feature || echo "")
    elif [ "$FORCE" != "--force" ]; then
      echo "[afc:pipeline] No active pipeline to end" >&2
      exit 0
    fi

    afc_state_delete
    # Clean sidecar changes file if it exists (jq-less fallback)
    rm -f "$FLAG_DIR/.afc-state.changes.log"
    rm -f "$FLAG_DIR/.afc-failures.log" "$FLAG_DIR/.afc-task-results.log" "$FLAG_DIR/.afc-config-audit.log"

    # Clean up safety tag and phase tags (on successful completion)
    if cd "$PROJECT_DIR" 2>/dev/null; then
      git tag -d "afc/pre-auto" 2>/dev/null || true
      for TAG in $(git tag -l 'afc/phase-*' 2>/dev/null || true); do
        git tag -d "$TAG" 2>/dev/null || true
      done
    fi

    echo "Pipeline ended: ${FEATURE:-unknown}"
    ;;

  status)
    if afc_state_is_active; then
      echo "Active: $(afc_state_read feature || echo 'unknown')"
      PHASE=$(afc_state_read phase 2>/dev/null || true)
      [ -n "$PHASE" ] && echo "Phase: $PHASE"
      CI_TS=$(afc_state_read ciPassedAt 2>/dev/null || true)
      [ -n "$CI_TS" ] && echo "CI: passed ($CI_TS)"
      CHANGES=$(afc_state_read_changes 2>/dev/null || true)
      if [ -n "$CHANGES" ]; then
        CHANGE_COUNT=$(printf '%s\n' "$CHANGES" | wc -l | tr -d ' ')
        echo "Changes: $CHANGE_COUNT files"
      fi
      # Show checkpoint count if available
      if command -v jq >/dev/null 2>&1; then
        CP_COUNT=$(jq '.phaseCheckpoints | length' "$_AFC_STATE_FILE" 2>/dev/null || echo 0)
        if [ "$CP_COUNT" -gt 0 ]; then
          echo "Checkpoints: $CP_COUNT phases recorded"
        fi
      fi
    else
      echo "No active pipeline"
    fi
    ;;

  log)
    EVENT="${2:-}"
    MSG="${3:-}"
    if [ -z "$EVENT" ]; then
      echo "[afc] Usage: $0 log <event_type> <message>" >&2
      exit 1
    fi
    "$SCRIPT_DIR/afc-timeline-log.sh" "$EVENT" "$MSG"
    ;;

  phase-tag)
    PHASE_NUM="${2:?Phase number required}"
    # Sanitize to digits only
    PHASE_NUM=$(printf '%s' "$PHASE_NUM" | tr -dc '0-9' | cut -c1-2)
    if [ -z "$PHASE_NUM" ]; then
      echo "[afc:pipeline] Invalid phase number" >&2
      exit 1
    fi
    if cd "$PROJECT_DIR" 2>/dev/null; then
      git tag -f "afc/phase-${PHASE_NUM}" 2>/dev/null || true
      echo "Phase tag created: afc/phase-${PHASE_NUM}"
    else
      echo "[afc:pipeline] Cannot create tag: not a git repo" >&2
      exit 1
    fi
    ;;

  phase-tag-clean)
    if cd "$PROJECT_DIR" 2>/dev/null; then
      TAGS=$(git tag -l 'afc/phase-*' 2>/dev/null || true)
      if [ -n "$TAGS" ]; then
        COUNT=0
        for TAG in $TAGS; do
          git tag -d "$TAG" 2>/dev/null || true
          COUNT=$((COUNT + 1))
        done
        echo "Removed $COUNT phase tags"
      else
        echo "No phase tags to remove"
      fi
    else
      echo "[afc:pipeline] Cannot clean tags: not a git repo" >&2
      exit 0
    fi
    ;;

  *)
    echo "[afc] Usage: $0 {start|phase|ci-pass|end|status|log|phase-tag|phase-tag-clean} [args]" >&2
    exit 1
    ;;
esac

exit 0
