#!/bin/bash
set -euo pipefail

# UserPromptSubmit Hook: Two modes of operation:
# 1. Pipeline INACTIVE: Detect user intent from prompt and inject specific skill routing hint
# 2. Pipeline ACTIVE: Inject Phase/Feature context + drift checkpoint at thresholds

# shellcheck source=afc-state.sh
. "$(dirname "$0")/afc-state.sh"

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

# Read stdin (contains user prompt JSON)
INPUT=$(cat)

# --- Branch: Pipeline INACTIVE -> intent-based skill routing ---
# The model has CLAUDE.md routing table but static instructions lose effectiveness
# as context grows. Reading the actual prompt and suggesting a SPECIFIC skill
# is far more actionable than a generic "check routing table" reminder.
if ! afc_state_is_active; then

  # Extract prompt text from stdin JSON
  USER_TEXT=""
  if command -v jq >/dev/null 2>&1; then
    USER_TEXT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)
  else
    # shellcheck disable=SC2001
    # Note: sed fallback truncates at first embedded escaped quote — acceptable for keyword matching
    USER_TEXT=$(printf '%s' "$INPUT" | sed 's/.*"prompt"[[:space:]]*:[[:space:]]*"//;s/".*//' 2>/dev/null || true)
  fi

  # Skip if prompt is already an explicit slash command
  if printf '%s' "$USER_TEXT" | grep -qE '^\s*/afc:' 2>/dev/null; then
    exit 0
  fi

  # Normalize: lowercase + truncate for matching
  LOWER=$(printf '%s' "$USER_TEXT" | tr '[:upper:]' '[:lower:]' | cut -c1-500)

  # Compact skill catalog: injected when regex misses, so the model classifies semantically
  FALLBACK_HINT="[afc] Route via Skill tool if applicable — debug(bug/에러/수정/fix) | review(코드검토/리뷰/PR) | test(테스트/coverage) | spec(요구사항/스펙) | plan(설계/계획) | implement(구현/리팩터) | auto(새기능/feature) | consult(조언/상의/discuss) | analyze(분석/trace) | research(조사/리서치) | security(보안/취약점) | architect(아키텍처/설계) | qa(품질감사) | launch(릴리스/배포) | triage(PR정리/이슈분류) | issue(이슈분석) | resolve(LLM리뷰대응) | clean(정리/cleanup) | ideate(아이디어/brainstorm) | doctor(진단/health) | release-notes(변경이력)"

  # Early exit for empty prompts (context-only messages, malformed JSON)
  if [ -z "$LOWER" ]; then
    if command -v jq >/dev/null 2>&1; then
      jq -n --arg c "$FALLBACK_HINT" '{"hookSpecificOutput":{"additionalContext":$c}}'
    else
      SAFE_FALLBACK="${FALLBACK_HINT//\\/\\\\}"
      SAFE_FALLBACK="${SAFE_FALLBACK//\"/\\\"}"
      printf '{"hookSpecificOutput":{"additionalContext":"%s"}}\n' "$SAFE_FALLBACK"
    fi
    exit 0
  fi

  # Intent detection: priority-ordered if/elif chain.
  # Each pattern targets strong-signal phrases to minimize false positives.
  # The model retains final authority — this is a hint, not enforcement.
  # Patterns include Korean (한국어) variants for natural language coverage.
  SKILL=""
  # High confidence: distinctive multi-word or rare keywords
  if printf '%s' "$LOWER" | grep -qE '(bug|broken|debug|not working|crash|exception|에러|버그|오류|안.?됨|안.?돼|안.?되|고장)' 2>/dev/null; then
    SKILL="afc:debug"
  elif printf '%s' "$LOWER" | grep -qE '(code review|pr review|코드.?리뷰|pr.?리뷰|코드.?검토)' 2>/dev/null; then
    SKILL="afc:review"
  elif printf '%s' "$LOWER" | grep -qE '(write test|add test|test coverage|improve coverage|unit test|integration test|e2e test|테스트.?작성|테스트.?추가|커버리지)' 2>/dev/null; then
    SKILL="afc:test"
  elif printf '%s' "$LOWER" | grep -qE '(security scan|security review|security audit|vulnerabilit|보안.?검사|보안.?스캔|보안.?리뷰|취약점)' 2>/dev/null; then
    SKILL="afc:security"
  elif printf '%s' "$LOWER" | grep -qE '(architecture|architect|system design|아키텍처|시스템.?설계|구조.?설계)' 2>/dev/null; then
    SKILL="afc:architect"
  elif printf '%s' "$LOWER" | grep -qE '(doctor|health check|diagnose.*project|진단|상태.?확인|헬스.?체크)' 2>/dev/null; then
    SKILL="afc:doctor"
  elif printf '%s' "$LOWER" | grep -qE '(quality audit|qa audit|project quality|품질.?감사|품질.?점검|qa.?점검)' 2>/dev/null; then
    SKILL="afc:qa"
  # NOTE: release-notes MUST come before launch — 릴리스.?노트 vs 릴리스 순서 의존
  elif printf '%s' "$LOWER" | grep -qE '(release note|릴리스.?노트|변경.?이력|release.?note)' 2>/dev/null; then
    SKILL="afc:release-notes"
  elif printf '%s' "$LOWER" | grep -qE '(new release|version bump|changelog|publish.*package|릴리스|버전.?업|배포.?준비)' 2>/dev/null; then
    SKILL="afc:launch"
  elif printf '%s' "$LOWER" | grep -qE '(triage|pr.?정리|이슈.?정리|백로그.?정리|pr.?분류|이슈.?분류)' 2>/dev/null; then
    SKILL="afc:triage"
  elif printf '%s' "$LOWER" | grep -qE '(issue.*분석|이슈.*분석|analyze.*issue|issue.*#[0-9]|이슈.*#[0-9])' 2>/dev/null; then
    SKILL="afc:issue"
  elif printf '%s' "$LOWER" | grep -qE '(review.*comment|resolve.*comment|coderabbit|copilot.*review|리뷰.*코멘트|봇.*리뷰|bot.*review.*fix)' 2>/dev/null; then
    SKILL="afc:resolve"
  # Medium confidence: still distinctive but broader
  elif printf '%s' "$LOWER" | grep -qE '(specification|requirements|acceptance criteria|요구.?사항|기능.?정의|인수.?조건)' 2>/dev/null; then
    SKILL="afc:spec"
  elif printf '%s' "$LOWER" | grep -qE '(brainstorm|ideate|what to build|product brief|아이디어|브레인스토밍|뭘.*만들)' 2>/dev/null; then
    SKILL="afc:ideate"
  elif printf '%s' "$LOWER" | grep -qE '(expert advice|discuss|advice|think together|같이.*생각|함께.*생각|상의|조언|의견.*구|자문|상담)' 2>/dev/null; then
    SKILL="afc:consult"
  elif printf '%s' "$LOWER" | grep -qE '(analyz|trace.*flow|how does.*work|분석|추적|어떻게.*동작|흐름.*파악)' 2>/dev/null; then
    SKILL="afc:analyze"
  elif printf '%s' "$LOWER" | grep -qE '(research|investigat|compare.*lib|조사|리서치|비교.*라이브러리|탐색)' 2>/dev/null; then
    SKILL="afc:research"
  elif printf '%s' "$LOWER" | grep -qE '(clean.*up|cleanup|아티팩트.?정리|파이프라인.?정리|산출물.?정리)' 2>/dev/null; then
    SKILL="afc:clean"
  # Lower confidence: common verbs — auto for non-trivial feature scopes
  elif printf '%s' "$LOWER" | grep -qE '(새.*기능|신규.*기능|기능.*개발|기능.*만들|feature.*develop|build.*feature|develop.*feature|create.*feature)' 2>/dev/null; then
    SKILL="afc:auto"
  elif printf '%s' "$LOWER" | grep -qE '(implement|add feature|refactor|modify.*code|리팩터|리팩토링|코드.?수정)' 2>/dev/null; then
    SKILL="afc:implement"
  elif printf '%s' "$LOWER" | grep -qE '(fix|error|issue|problem|failing|수정|고쳐|문제)' 2>/dev/null; then
    SKILL="afc:debug"
  elif printf '%s' "$LOWER" | grep -qE '(review|검토|리뷰)' 2>/dev/null; then
    SKILL="afc:review"
  elif printf '%s' "$LOWER" | grep -qE '(spec[^a-z]|spec$|스펙)' 2>/dev/null; then
    SKILL="afc:spec"
  elif printf '%s' "$LOWER" | grep -qE '(plan[^a-z]|plan$|계획|설계)' 2>/dev/null; then
    SKILL="afc:plan"
  fi

  # Build output (no TASK HYGIENE in inactive mode — stop-gate handles cleanup scope)
  if [ -n "$SKILL" ]; then
    HINT="[afc:route -> ${SKILL}] Detected intent from user prompt. Invoke /${SKILL} via Skill tool."
  else
    HINT="$FALLBACK_HINT"
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -n --arg c "$HINT" '{"hookSpecificOutput":{"additionalContext":$c}}'
  else
    SAFE_HINT="${HINT//\\/\\\\}"
    SAFE_HINT="${SAFE_HINT//\"/\\\"}"
    printf '{"hookSpecificOutput":{"additionalContext":"%s"}}\n' "$SAFE_HINT"
  fi
  exit 0
fi

# --- Branch: Pipeline ACTIVE -> existing Phase/Feature context ---

# Read Feature/Phase + JSON-safe processing (strip special characters + newlines)
FEATURE="$(afc_state_read feature || echo '')"
FEATURE="$(printf '%s' "$FEATURE" | tr -d '"\n\r' | cut -c1-100)"
PHASE="$(afc_state_read phase || echo 'unknown')"
PHASE="$(printf '%s' "$PHASE" | tr -d '"\n\r' | cut -c1-100)"

# Increment per-phase prompt counter + pipeline-wide total
CALL_COUNT=$(afc_state_increment promptCount 2>/dev/null || echo 0)
afc_state_increment totalPromptCount >/dev/null 2>&1 || echo "[afc:prompt-submit] totalPromptCount increment failed" >&2
TOTAL_COUNT=$(afc_state_read totalPromptCount 2>/dev/null || echo 0)

# Build context message
CONTEXT="[Pipeline: ${FEATURE}] [Phase: ${PHASE}] [TASK HYGIENE: Mark completed tasks via TaskUpdate(status: completed) -- do not leave stale tasks]"

# P1.1: Phase-Boundary Compact 권고
# Inject compact recommendation on first prompt after a phase transition
PHASE_TRANSITION=$(afc_state_read phaseTransition 2>/dev/null || echo "")
if [ "$PHASE_TRANSITION" = "true" ]; then
  afc_state_write "phaseTransition" "false"
  case "$PHASE" in
    plan)
      COMPACT_MSG="이전 phase(spec) 컨텍스트 정리 권장: /compact Preserve spec.md acceptance criteria, edge cases, and NFRs"
      ;;
    implement)
      COMPACT_MSG="이전 phase(plan) 컨텍스트 정리 권장: /compact Preserve File Change Map, Implementation Context, and ADR decisions"
      ;;
    review)
      COMPACT_MSG="이전 phase(implement) 컨텍스트 정리 권장: /compact Preserve changed files list, CI results, and unresolved issues"
      ;;
    clean)
      COMPACT_MSG="이전 phase(review) 컨텍스트 정리 권장: /compact Preserve review findings and fix status"
      ;;
    *)
      COMPACT_MSG=""
      ;;
  esac
  if [ -n "$COMPACT_MSG" ]; then
    CONTEXT="${CONTEXT} [afc:context] ${COMPACT_MSG}"
  fi
fi

# Drift checkpoint: inject plan constraints at every N prompts during implement/review
# AFC_DRIFT_THRESHOLD sourced from afc-state.sh (SSOT)
if [ "$CALL_COUNT" -gt 0 ] && [ $((CALL_COUNT % AFC_DRIFT_THRESHOLD)) -eq 0 ]; then
  case "$PHASE" in
    implement|review)
      DRIFT_MSG="[DRIFT CHECKPOINT: ${CALL_COUNT} prompts in phase] Re-read plan.md constraints and acceptance criteria. Verify current work aligns with spec intent."
      CONTEXT="${CONTEXT} ${DRIFT_MSG}"
      ;;
  esac
fi

# P1.3: Context Budget Monitor
# Inject budget hints based on totalPromptCount across all phases
if [ "$TOTAL_COUNT" -ge 200 ]; then
  CONTEXT="${CONTEXT} [afc:context] ~90%+ context estimated (${TOTAL_COUNT} total prompts). Auto-compact imminent. /compact now with phase-specific preservation."
elif [ "$TOTAL_COUNT" -ge 150 ]; then
  CONTEXT="${CONTEXT} [afc:context] Context ~70%+ estimated (${TOTAL_COUNT} total prompts). /compact recommended: preserve current phase artifacts."
elif [ "$TOTAL_COUNT" -ge 100 ]; then
  CONTEXT="${CONTEXT} [afc:context] Context ~50%+ estimated (${TOTAL_COUNT} total prompts). Delegate verbose operations to subagents."
fi

# Output additionalContext to stdout (injected into Claude context)
# Use jq for safe JSON encoding; printf fallback strips remaining quotes
if command -v jq >/dev/null 2>&1; then
  jq -n --arg c "$CONTEXT" '{"hookSpecificOutput":{"additionalContext":$c}}'
else
  SAFE_CONTEXT="${CONTEXT//\\/\\\\}"
  SAFE_CONTEXT="${SAFE_CONTEXT//\"/\\\"}"
  printf '{"hookSpecificOutput":{"additionalContext":"%s"}}\n' "$SAFE_CONTEXT"
fi

exit 0
