#!/bin/bash
# Pre-Compact Hook: 컨텍스트 압축 전 자동 체크포인트
# 세션 중단/압축 시 진행 상태가 소실되는 것을 방지
#
# Gap 해결: OMC의 자동 상태 저장 → 물리적 스크립트로 강제

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
# Auto-memory 디렉토리를 프로젝트 경로에서 동적 파생
PROJECT_PATH=$(cd "$PROJECT_DIR" 2>/dev/null && pwd || echo "$PROJECT_DIR")
ENCODED_PATH=$(echo "$PROJECT_PATH" | sed 's|/|-|g')
MEMORY_DIR="$HOME/.claude/projects/$ENCODED_PATH/memory"
CHECKPOINT="$MEMORY_DIR/checkpoint.md"

# memory 디렉토리 없으면 생성
mkdir -p "$MEMORY_DIR"

# 현재 git 상태 수집
BRANCH=$(cd "$PROJECT_DIR" 2>/dev/null && git branch --show-current 2>/dev/null || echo "unknown")
MODIFIED=$(cd "$PROJECT_DIR" 2>/dev/null && git diff --name-only 2>/dev/null | head -20)
STAGED=$(cd "$PROJECT_DIR" 2>/dev/null && git diff --cached --name-only 2>/dev/null | head -20)

# selfish pipeline 활성 상태 확인
PIPELINE_FLAG="$PROJECT_DIR/.claude/.selfish-active"
PIPELINE_FEATURE=""
if [ -f "$PIPELINE_FLAG" ]; then
  PIPELINE_FEATURE=$(cat "$PIPELINE_FLAG")
fi

# tasks.md 진행 상태 확인
TASKS_DONE=0
TASKS_TOTAL=0
if [ -n "$PIPELINE_FEATURE" ] && [ -d "$PROJECT_DIR/specs/$PIPELINE_FEATURE" ]; then
  TASKS_FILE="$PROJECT_DIR/specs/$PIPELINE_FEATURE/tasks.md"
  if [ -f "$TASKS_FILE" ]; then
    TASKS_DONE=$(grep -cE '\[x\]' "$TASKS_FILE" 2>/dev/null || echo 0)
    TASKS_TOTAL=$(grep -cE '\[(x| )\]' "$TASKS_FILE" 2>/dev/null || echo 0)
  fi
fi

# checkpoint.md 작성
cat > "$CHECKPOINT" << EOF
# Auto Checkpoint (Pre-Compact)
> 자동 생성: $(date '+%Y-%m-%d %H:%M:%S')
> 트리거: context compaction

## Git 상태
- 브랜치: $BRANCH
- 수정된 파일: $(echo "$MODIFIED" | wc -l | tr -d ' ')개
$(echo "$MODIFIED" | sed 's/^/  - /' | head -10)

## Staged 파일
$(echo "$STAGED" | sed 's/^/  - /' | head -10)

## Pipeline 상태
- 활성: $([ -f "$PIPELINE_FLAG" ] && echo "Yes ($PIPELINE_FEATURE)" || echo "No")
- 태스크 진행: $TASKS_DONE/$TASKS_TOTAL

## 복원 명령
\`\`\`
/selfish.resume
\`\`\`
EOF

# stdout으로 context 주입 (Claude가 압축 후 이 정보를 볼 수 있음)
echo "Auto-checkpoint saved to memory/checkpoint.md (branch: $BRANCH, pipeline: ${PIPELINE_FEATURE:-inactive})"

exit 0
