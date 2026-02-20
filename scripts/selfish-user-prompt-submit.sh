#!/bin/bash
set -euo pipefail

# UserPromptSubmit Hook: 매 프롬프트에 파이프라인 Phase/Feature 컨텍스트 주입
# 파이프라인 비활성 시 즉시 exit 0 (오버헤드 최소화)

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PIPELINE_FLAG="$PROJECT_DIR/.claude/.selfish-active"
PHASE_FLAG="$PROJECT_DIR/.claude/.selfish-phase"

# stdin 소비 (필수 — 미소비 시 파이프 깨짐)
cat > /dev/null

# 파이프라인 비활성 시 조용히 종료
if [ ! -f "$PIPELINE_FLAG" ]; then
  exit 0
fi

# Feature/Phase 읽기 + JSON 안전 처리 (특수문자 제거)
FEATURE="$(head -1 "$PIPELINE_FLAG" | tr -d '\n\r' | tr -d '"' | cut -c1-100)"
PHASE="unknown"
if [ -f "$PHASE_FLAG" ]; then
  PHASE="$(head -1 "$PHASE_FLAG" | tr -d '\n\r' | tr -d '"' | cut -c1-100)"
fi

# stdout으로 additionalContext 출력 (Claude 컨텍스트에 주입)
printf '{"hookSpecificOutput":{"additionalContext":"[Pipeline: %s] [Phase: %s]"}}' "$FEATURE" "$PHASE"

exit 0
