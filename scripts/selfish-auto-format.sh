#!/bin/bash
set -euo pipefail

# PostToolUse Hook: 변경된 파일 자동 포맷팅
# 포맷터를 백그라운드에서 실행하여 Claude 작업 흐름을 차단하지 않음
#
# 동작: stdin에서 file_path 추출 → 확장자별 포맷터 백그라운드 실행 → 즉시 exit 0

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

# stdin에서 hook 데이터 읽기
INPUT=$(cat 2>/dev/null || true)
if [ -z "$INPUT" ]; then
  exit 0
fi

# file_path 추출 (jq 우선, fallback grep/sed)
if command -v jq &> /dev/null; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
else
  FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
fi

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# 프로젝트 루트의 포맷터 설정 확인
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# 확장자별 포맷터를 백그라운드로 실행
format_file() {
  local file="$1"
  case "$file" in
    *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.scss|*.md|*.html|*.yaml|*.yml)
      # prettier 확인 (프로젝트 로컬 npx 또는 글로벌)
      if [ -f "$PROJECT_DIR/node_modules/.bin/prettier" ]; then
        "$PROJECT_DIR/node_modules/.bin/prettier" --write "$file" 2>/dev/null || true
      elif command -v npx &> /dev/null && [ -f "$PROJECT_DIR/package.json" ]; then
        npx --no-install prettier --write "$file" 2>/dev/null || true
      fi
      ;;
    *.py)
      if command -v black &> /dev/null; then
        black --quiet "$file" 2>/dev/null || true
      elif command -v autopep8 &> /dev/null; then
        autopep8 --in-place "$file" 2>/dev/null || true
      fi
      ;;
    *.go)
      if command -v gofmt &> /dev/null; then
        gofmt -w "$file" 2>/dev/null || true
      fi
      ;;
    *.rs)
      if command -v rustfmt &> /dev/null; then
        rustfmt "$file" 2>/dev/null || true
      fi
      ;;
  esac
}

# 백그라운드 실행 후 즉시 exit (Claude 비차단)
format_file "$FILE_PATH" &
disown

exit 0
