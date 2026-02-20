#!/bin/bash
set -euo pipefail
# TaskCompleted Gate Hook: 파이프라인 활성 중 CI 미통과 시 태스크 완료 차단
# Claude가 CI를 건너뛰고 태스크를 완료하는 것을 물리적으로 방지
#
# Gap 해결: "프롬프트는 강제가 아님" → exit 2로 물리적 차단

# trap: 비정상 종료 시 exit code 보존 + stderr 메시지
# shellcheck disable=SC2329
cleanup() {
  local exit_code=$?
  if [ "$exit_code" -ne 0 ] && [ "$exit_code" -ne 2 ]; then
    echo "SELFISH TASK GATE: 비정상 종료 (exit code: $exit_code)" >&2
  fi
  exit "$exit_code"
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PIPELINE_FLAG="${PROJECT_DIR}/.claude/.selfish-active"
CI_FLAG="${PROJECT_DIR}/.claude/.selfish-ci-passed"
PHASE_FLAG="${PROJECT_DIR}/.claude/.selfish-phase"

# 파이프라인이 활성이 아니면 → 통과
if [ ! -f "$PIPELINE_FLAG" ]; then
  exit 0
fi

FEATURE="$(head -1 "$PIPELINE_FLAG" | tr -d '\n\r')"

# Phase 파일이 있으면 현재 Phase 확인
CURRENT_PHASE=""
if [ -f "$PHASE_FLAG" ]; then
  CURRENT_PHASE="$(cat "$PHASE_FLAG")"
fi
CURRENT_PHASE="${CURRENT_PHASE:-}"

# Spec/Plan/Tasks Phase (1-3)는 CI 불필요 → 통과
case "${CURRENT_PHASE:-}" in
  spec|plan|tasks)
    exit 0
    ;;
esac

# Implement/Review/Clean Phase (4-6)에서는 CI 필수
if [ ! -f "$CI_FLAG" ]; then
  echo "SELFISH TASK GATE: yarn ci가 실행되지 않았습니다. 파이프라인 '${FEATURE:-unknown}' Phase '${CURRENT_PHASE:-unknown}'에서 CI 게이트를 통과해야 합니다. yarn ci를 실행한 후 .claude/.selfish-ci-passed에 timestamp를 기록하세요." >&2
  exit 2
fi

# CI가 10분 이내에 통과했는지 확인 (stale 방지)
CI_TIME="$(cat "$CI_FLAG" 2>/dev/null | head -1 | tr -dc '0-9')"
CI_TIME="${CI_TIME:-0}"
NOW="$(date +%s)"
if [ "$CI_TIME" -gt 0 ]; then
  DIFF=$(( NOW - CI_TIME ))
  if [ "$DIFF" -gt 600 ]; then
    echo "SELFISH TASK GATE: CI 결과가 오래되었습니다 (${DIFF}초 전). yarn ci를 다시 실행하세요." >&2
    exit 2
  fi
fi

exit 0
