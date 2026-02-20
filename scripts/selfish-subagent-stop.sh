#!/bin/bash
set -euo pipefail

# SubagentStop Hook: 서브에이전트 완료/실패 시 결과를 파이프라인 로그에 기록
# 파이프라인 오케스트레이터가 태스크 진행 상황을 추적할 수 있도록 함

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PIPELINE_FLAG="$PROJECT_DIR/.claude/.selfish-active"
RESULTS_LOG="$PROJECT_DIR/.claude/.selfish-task-results.log"

# stdin에서 hook 데이터 읽기
INPUT=$(cat)

# stop_hook_active 파싱 (무한 루프 방지 — CRITICAL)
if command -v jq >/dev/null 2>&1; then
  STOP_HOOK_ACTIVE=$(printf '%s\n' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
else
  if printf '%s\n' "$INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
    STOP_HOOK_ACTIVE="true"
  else
    STOP_HOOK_ACTIVE="false"
  fi
fi

# stop_hook_active가 true면 즉시 종료 (재귀 호출 방지)
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# 파이프라인 비활성 시 조용히 종료
if [ ! -f "$PIPELINE_FLAG" ]; then
  exit 0
fi

# 서브에이전트 정보 파싱 (jq fallback: grep은 escaped quotes 미지원 — 허용된 한계)
if command -v jq >/dev/null 2>&1; then
  AGENT_ID=$(printf '%s\n' "$INPUT" | jq -r '.agent_id // "unknown"' 2>/dev/null)
  AGENT_TYPE=$(printf '%s\n' "$INPUT" | jq -r '.agent_type // "unknown"' 2>/dev/null)
  LAST_MSG=$(printf '%s\n' "$INPUT" | jq -r '.last_assistant_message // "no message"' 2>/dev/null)
else
  AGENT_ID=$(printf '%s\n' "$INPUT" | grep -o '"agent_id"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"//;s/"$//' || echo "unknown")
  AGENT_TYPE=$(printf '%s\n' "$INPUT" | grep -o '"agent_type"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"//;s/"$//' || echo "unknown")
  LAST_MSG=$(printf '%s\n' "$INPUT" | grep -o '"last_assistant_message"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"//;s/"$//' | tr -d '\000-\037' || echo "no message")
fi

# 값 정리: 로그 폭발 방지 + 제어문자 제거
LAST_MSG=$(printf '%s\n' "$LAST_MSG" | head -1 | cut -c1-500)
AGENT_ID=$(printf '%s\n' "$AGENT_ID" | head -1 | tr -d '\n\r')
AGENT_TYPE=$(printf '%s\n' "$AGENT_TYPE" | head -1 | tr -d '\n\r' | cut -c1-100)

# 결과 로그에 기록
echo "$(date +%s) [${AGENT_TYPE}] ${AGENT_ID}: ${LAST_MSG}" >> "$RESULTS_LOG"

exit 0
