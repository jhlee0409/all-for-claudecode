#!/bin/bash
# Session Start Hook: 세션 시작 시 파이프라인 상태 복원
# resume/compact 후에도 진행 상태를 잃지 않도록 컨텍스트 주입
#
# Gap 해결: OMC의 세션 연속성 → 물리적 스크립트로 강제

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
# Auto-memory 디렉토리를 프로젝트 경로에서 동적 파생
PROJECT_PATH=$(cd "$PROJECT_DIR" 2>/dev/null && pwd || echo "$PROJECT_DIR")
ENCODED_PATH=$(echo "$PROJECT_PATH" | sed 's|/|-|g')
MEMORY_DIR="$HOME/.claude/projects/$ENCODED_PATH/memory"
CHECKPOINT="$MEMORY_DIR/checkpoint.md"
PIPELINE_FLAG="$PROJECT_DIR/.claude/.selfish-active"

OUTPUT=""

# 1. 활성 파이프라인 확인
if [ -f "$PIPELINE_FLAG" ]; then
  FEATURE=$(cat "$PIPELINE_FLAG")
  OUTPUT="[SELFISH PIPELINE ACTIVE] Feature: $FEATURE"

  # tasks.md 진행 상태
  TASKS_FILE="$PROJECT_DIR/specs/$FEATURE/tasks.md"
  if [ -f "$TASKS_FILE" ]; then
    DONE=$(grep -cE '\[x\]' "$TASKS_FILE" 2>/dev/null || echo 0)
    TOTAL=$(grep -cE '\[(x| )\]' "$TASKS_FILE" 2>/dev/null || echo 0)
    OUTPUT="$OUTPUT | Tasks: $DONE/$TOTAL"
  fi

  # CI 통과 여부
  CI_FLAG="$PROJECT_DIR/.claude/.selfish-ci-passed"
  if [ -f "$CI_FLAG" ]; then
    OUTPUT="$OUTPUT | Last CI: PASSED ($(cat "$CI_FLAG"))"
  fi
fi

# 2. 체크포인트 존재 확인
if [ -f "$CHECKPOINT" ]; then
  CHECKPOINT_DATE=$(grep '자동 생성:' "$CHECKPOINT" 2>/dev/null | head -1 | sed 's/.*자동 생성: //')
  if [ -n "$CHECKPOINT_DATE" ]; then
    if [ -n "$OUTPUT" ]; then
      OUTPUT="$OUTPUT | Checkpoint: $CHECKPOINT_DATE"
    else
      OUTPUT="[CHECKPOINT EXISTS] Date: $CHECKPOINT_DATE — Run /selfish.resume to restore"
    fi
  fi
fi

# 3. Safety tag 확인
BRANCH=$(cd "$PROJECT_DIR" 2>/dev/null && git branch --show-current 2>/dev/null)
HAS_SAFETY_TAG=$(cd "$PROJECT_DIR" 2>/dev/null && git tag -l 'selfish/pre-*' 2>/dev/null | head -1)
if [ -n "$HAS_SAFETY_TAG" ]; then
  if [ -n "$OUTPUT" ]; then
    OUTPUT="$OUTPUT | Safety tag: $HAS_SAFETY_TAG"
  fi
fi

# 출력 (stdout → Claude 컨텍스트에 주입됨)
if [ -n "$OUTPUT" ]; then
  echo "$OUTPUT"
fi

exit 0
