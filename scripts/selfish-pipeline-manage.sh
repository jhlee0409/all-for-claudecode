#!/bin/bash
# Pipeline Management: selfish 파이프라인 상태 플래그 관리
# 다른 hook 스크립트들이 참조하는 플래그 파일을 관리
#
# 사용법:
#   .claude/hooks/selfish-pipeline-manage.sh start <feature-name>
#   .claude/hooks/selfish-pipeline-manage.sh phase <phase-name>
#   .claude/hooks/selfish-pipeline-manage.sh ci-pass
#   .claude/hooks/selfish-pipeline-manage.sh end
#   .claude/hooks/selfish-pipeline-manage.sh status

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
FLAG_DIR="$PROJECT_DIR/.claude"
PIPELINE_FLAG="$FLAG_DIR/.selfish-active"
PHASE_FLAG="$FLAG_DIR/.selfish-phase"
CI_FLAG="$FLAG_DIR/.selfish-ci-passed"
CHANGES_LOG="$FLAG_DIR/.selfish-changes.log"

mkdir -p "$FLAG_DIR"

case "$1" in
  start)
    FEATURE="${2:?Feature name required}"
    echo "$FEATURE" > "$PIPELINE_FLAG"
    echo "spec" > "$PHASE_FLAG"
    rm -f "$CI_FLAG" "$CHANGES_LOG"

    # Safety snapshot
    cd "$PROJECT_DIR"
    git tag -f "selfish/pre-auto" 2>/dev/null

    echo "Pipeline started: $FEATURE (safety tag: selfish/pre-auto)"
    ;;

  phase)
    PHASE="${2:?Phase name required}"
    case "$PHASE" in
      spec|plan|tasks|implement|review|clean)
        echo "$PHASE" > "$PHASE_FLAG"
        rm -f "$CI_FLAG"  # 새 Phase에서는 CI 초기화
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
    FEATURE=""
    [ -f "$PIPELINE_FLAG" ] && FEATURE=$(cat "$PIPELINE_FLAG")
    rm -f "$PIPELINE_FLAG" "$PHASE_FLAG" "$CI_FLAG" "$CHANGES_LOG"

    # Safety tag 정리 (성공 완료 시)
    cd "$PROJECT_DIR"
    git tag -d "selfish/pre-auto" 2>/dev/null

    echo "Pipeline ended: ${FEATURE:-unknown}"
    ;;

  status)
    if [ -f "$PIPELINE_FLAG" ]; then
      echo "Active: $(cat "$PIPELINE_FLAG")"
      [ -f "$PHASE_FLAG" ] && echo "Phase: $(cat "$PHASE_FLAG")"
      [ -f "$CI_FLAG" ] && echo "CI: passed ($(cat "$CI_FLAG"))"
      [ -f "$CHANGES_LOG" ] && echo "Changes: $(wc -l < "$CHANGES_LOG") files"
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
