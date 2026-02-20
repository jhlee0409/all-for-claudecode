#!/bin/bash
set -euo pipefail
# Notification Hook: 작업 완료 및 권한 승인 필요 시 OS 알림 발송
# idle_prompt → 작업 완료 알림, permission_prompt → 권한 승인 요청 알림

# shellcheck disable=SC2329
cleanup() {
  # 임시 자원 정리가 필요한 경우를 위한 placeholder
  :
}
trap cleanup EXIT

# stdin에서 JSON 읽기
INPUT=$(cat)

# notification_type, message 파싱: jq 우선, grep/sed 폴백
NOTIFICATION_TYPE=""
MESSAGE=""
if command -v jq &>/dev/null; then
  NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // empty' 2>/dev/null || true)
  MESSAGE=$(echo "$INPUT" | jq -r '.message // empty' 2>/dev/null || true)
else
  NOTIFICATION_TYPE=$(echo "$INPUT" | grep -o '"notification_type"[[:space:]]*:[[:space:]]*"[^"]*"' 2>/dev/null \
    | sed 's/.*:[[:space:]]*"//;s/"$//' || true)
  MESSAGE=$(echo "$INPUT" | grep -o '"message"[[:space:]]*:[[:space:]]*"[^"]*"' 2>/dev/null \
    | sed 's/.*:[[:space:]]*"//;s/"$//' || true)
fi

# notification_type에 따라 제목 설정
case "$NOTIFICATION_TYPE" in
  idle_prompt)
    TITLE="Claude 작업 완료"
    ;;
  permission_prompt)
    TITLE="권한 승인 필요"
    ;;
  *)
    exit 0
    ;;
esac

# 플랫폼 감지 후 알림 발송 (hooks.json의 async: true로 비차단)
# 메시지 sanitize (AppleScript/shell 인젝션 방지)
SAFE_MESSAGE=$(printf '%s' "$MESSAGE" | sed 's/[\"\\]/\\&/g' | head -1 | cut -c1-200)
SAFE_TITLE=$(printf '%s' "$TITLE" | sed 's/[\"\\]/\\&/g')

OS=$(uname -s)
case "$OS" in
  Darwin)
    osascript -e "display notification \"$SAFE_MESSAGE\" with title \"$SAFE_TITLE\"" &>/dev/null || true
    ;;
  Linux)
    if command -v notify-send &>/dev/null; then
      notify-send "$TITLE" "$MESSAGE" &>/dev/null || true
    fi
    ;;
  *)
    exit 0
    ;;
esac

exit 0
