#!/bin/bash
# PostToolUse Hook: 파일 변경 추적
# Edit/Write 도구 사용 후 변경된 파일을 기록
# CI 게이트에서 어떤 파일이 변경되었는지 추적

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PIPELINE_FLAG="$PROJECT_DIR/.claude/.selfish-active"

# jq 필수 의존성 확인
if ! command -v jq &> /dev/null; then
  exit 0
fi
CHANGES_LOG="$PROJECT_DIR/.claude/.selfish-changes.log"
CI_FLAG="$PROJECT_DIR/.claude/.selfish-ci-passed"

# 파이프라인 비활성이면 → 스킵
if [ ! -f "$PIPELINE_FLAG" ]; then
  exit 0
fi

# stdin에서 tool input 파싱
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -n "$FILE_PATH" ]; then
  # 변경 로그에 추가 (중복 제거)
  echo "$FILE_PATH" >> "$CHANGES_LOG"
  sort -u -o "$CHANGES_LOG" "$CHANGES_LOG"

  # 파일이 변경되었으므로 CI 결과 무효화
  rm -f "$CI_FLAG"
fi

exit 0
