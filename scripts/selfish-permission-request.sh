#!/bin/bash
set -euo pipefail

# PermissionRequest Hook: 파이프라인 implement/review Phase에서 CI 관련 Bash 명령 자동 허용
# 화이트리스트 정확 일치만 허용, 명령 체이닝(&&/;/|/$()) 포함 시 기본 동작(사용자 확인)

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PIPELINE_FLAG="$PROJECT_DIR/.claude/.selfish-active"
PHASE_FLAG="$PROJECT_DIR/.claude/.selfish-phase"

# stdin에서 hook 데이터 읽기
INPUT=$(cat)

# 파이프라인 비활성 시 조용히 종료
if [ ! -f "$PIPELINE_FLAG" ]; then
  exit 0
fi

# implement/review Phase만 동작
PHASE=""
if [ -f "$PHASE_FLAG" ]; then
  PHASE="$(head -1 "$PHASE_FLAG" | tr -d '\n\r')"
fi
case "${PHASE:-}" in
  implement|review) ;;
  *) exit 0 ;;
esac

# tool_input.command 파싱
COMMAND=""
if command -v jq >/dev/null 2>&1; then
  COMMAND=$(printf '%s\n' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
else
  COMMAND=$(printf '%s\n' "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
fi

# 빈 명령이면 기본 동작
if [ -z "$COMMAND" ]; then
  exit 0
fi

# 명령 체이닝/치환/개행 감지 — 포함 시 기본 동작 (보안)
if printf '%s' "$COMMAND" | grep -qE '&&|;|\||\$\(|`'; then
  exit 0
fi
# 개행 문자 포함 시 기본 동작 (multi-line 우회 방지)
case "$COMMAND" in
  *$'\n'*) exit 0 ;;
esac

# 화이트리스트 정확 일치 (prefix match 방지를 위해 공백 + $ 사용)
ALLOWED=false
case "$COMMAND" in
  "npm run lint"|"npm test"|"npm run test:all")
    ALLOWED=true
    ;;
esac

# prefix 매칭 (shellcheck, prettier, chmod +x 뒤에 경로 허용)
if [ "$ALLOWED" = "false" ]; then
  case "$COMMAND" in
    "shellcheck "*)
      ALLOWED=true
      ;;
    "prettier "*)
      ALLOWED=true
      ;;
    "chmod +x "*)
      # 프로젝트 디렉토리 내 경로만 허용
      TARGET="${COMMAND#chmod +x }"
      case "$TARGET" in
        "$PROJECT_DIR"/*|./scripts/*|scripts/*) ALLOWED=true ;;
      esac
      ;;
  esac
fi

# 허용 결정 출력
if [ "$ALLOWED" = "true" ]; then
  printf '{"hookSpecificOutput":{"decision":{"behavior":"allow"}}}'
fi

# ALLOWED=false면 출력 없이 exit 0 → 기본 동작 (사용자 확인)
exit 0
