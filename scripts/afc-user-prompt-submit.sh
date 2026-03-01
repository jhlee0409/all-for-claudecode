#!/bin/bash
set -euo pipefail

# UserPromptSubmit Hook: Two modes of operation:
# 1. Pipeline INACTIVE: Extract prompt from stdin, match keywords → inject AFC skill routing hint
# 2. Pipeline ACTIVE: Inject Phase/Feature context + drift checkpoint at thresholds
# Exit 0 immediately if no action needed (minimize overhead)

# shellcheck source=afc-state.sh
. "$(dirname "$0")/afc-state.sh"

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

# Read stdin into variable (required -- pipe breaks if not consumed)
INPUT="$(cat)"

# --- Branch: Pipeline INACTIVE → keyword-based routing hint ---
if ! afc_state_is_active; then
  # Extract prompt field from stdin JSON
  if command -v jq &>/dev/null; then
    PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)"
  else
    # grep fallback: extract "prompt":"..." value
    PROMPT="$(printf '%s' "$INPUT" | grep -o '"prompt"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/^"prompt"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)"
  fi

  # Skip short prompts (less than 10 bytes — likely not a real request)
  # Use wc -c for byte length (Korean chars = 3 bytes each, more reliable than ${#})
  PROMPT_LEN=$(printf '%s' "$PROMPT" | wc -c | tr -d ' ')
  if [ "$PROMPT_LEN" -lt 10 ]; then
    exit 0
  fi

  # Keyword matching table → AFC skill routing
  MATCHED_SKILL=""
  NEEDS_SOURCE_VERIFY=false

  # Pre-filter: single grep to reject non-matching prompts early (~90% of cases)
  if ! printf '%s' "$PROMPT" | grep -iqE 'spec|ideate|research|debug|test|review|plan|implement|analyze|brainstorm|broken|coverage|investigate|design|specification|fix|how to|스펙|아이디어|브레인스톰|리서치|연구|조사|디버그|버그|에러|오류|고장|안됨|안되|테스트|커버리지|리뷰|검토|설계|플랜|아키텍처|구현|추가|수정|리팩|만들어|개발|분석|탐색|살펴|점검|요구사항|명세'; then
    exit 0
  fi

  # Classification: English uses -w (whole word) to avoid false positives (e.g. "latest" matching "test")
  # Korean uses plain substring match (Korean chars are self-delimiting)
  # Order matters: more specific patterns first
  if printf '%s' "$PROMPT" | grep -iqwE 'spec|specification' || printf '%s' "$PROMPT" | grep -iqE '스펙|요구사항|명세'; then
    MATCHED_SKILL="spec"
  elif printf '%s' "$PROMPT" | grep -iqwE 'ideate|brainstorm' || printf '%s' "$PROMPT" | grep -iqE '아이디어|브레인스톰'; then
    MATCHED_SKILL="ideate"
  elif printf '%s' "$PROMPT" | grep -iqwE 'research' || printf '%s' "$PROMPT" | grep -iqE '리서치|연구|조사.*깊'; then
    MATCHED_SKILL="research"
    NEEDS_SOURCE_VERIFY=true
  elif printf '%s' "$PROMPT" | grep -iqwE 'debug|fix|broken' || printf '%s' "$PROMPT" | grep -iqE '디버그|버그|에러|오류|고장|안됨|안되'; then
    MATCHED_SKILL="debug"
  elif printf '%s' "$PROMPT" | grep -iqwE 'test|coverage' || printf '%s' "$PROMPT" | grep -iqE '테스트|커버리지'; then
    MATCHED_SKILL="test"
  elif printf '%s' "$PROMPT" | grep -iqwE 'review' || printf '%s' "$PROMPT" | grep -iqE '리뷰|검토|코드.*리뷰|PR.*확인'; then
    MATCHED_SKILL="review"
  elif printf '%s' "$PROMPT" | grep -iqwE 'plan|design|how to' || printf '%s' "$PROMPT" | grep -iqE '설계|플랜|아키텍처'; then
    MATCHED_SKILL="plan"
  elif printf '%s' "$PROMPT" | grep -iqwE 'implement' || printf '%s' "$PROMPT" | grep -iqE '구현|추가|수정|리팩|만들어|개발'; then
    MATCHED_SKILL="implement"
  elif printf '%s' "$PROMPT" | grep -iqwE 'analyze|investigate' || printf '%s' "$PROMPT" | grep -iqE '분석|조사|탐색|살펴|점검'; then
    MATCHED_SKILL="analyze"
    NEEDS_SOURCE_VERIFY=true
  fi

  # No match → exit silently
  if [ -z "$MATCHED_SKILL" ]; then
    exit 0
  fi

  # Build routing hint
  CONTEXT="[AFC ROUTE] This request matches afc:${MATCHED_SKILL}. Use the Skill tool to invoke it. Do NOT use raw Task agents or OMC agents."

  # Add source verification hint for analysis/research skills
  if [ "$NEEDS_SOURCE_VERIFY" = true ]; then
    CONTEXT="${CONTEXT} [SOURCE VERIFY] When making claims about external systems/APIs, verify against official docs. Do not treat project CLAUDE.md as authoritative spec for external tools."
  fi

  # Output additionalContext
  if command -v jq &>/dev/null; then
    jq -n --arg c "$CONTEXT" '{"hookSpecificOutput":{"additionalContext":$c}}'
  else
    SAFE_CONTEXT="${CONTEXT//\\/\\\\}"
    SAFE_CONTEXT="${SAFE_CONTEXT//\"/\\\"}"
    printf '{"hookSpecificOutput":{"additionalContext":"%s"}}\n' "$SAFE_CONTEXT"
  fi

  exit 0
fi

# --- Branch: Pipeline ACTIVE → existing Phase/Feature context ---

# Read Feature/Phase + JSON-safe processing (strip special characters)
FEATURE="$(afc_state_read feature || echo '')"
FEATURE="$(printf '%s' "$FEATURE" | tr -d '"' | cut -c1-100)"
PHASE="$(afc_state_read phase || echo 'unknown')"
PHASE="$(printf '%s' "$PHASE" | tr -d '"' | cut -c1-100)"

# Increment per-phase prompt counter + pipeline-wide total
CALL_COUNT=$(afc_state_increment promptCount 2>/dev/null || echo 0)
afc_state_increment totalPromptCount >/dev/null 2>&1 || echo "[afc:prompt-submit] totalPromptCount increment failed" >&2

# Build context message
CONTEXT="[Pipeline: ${FEATURE}] [Phase: ${PHASE}]"

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

# Output additionalContext to stdout (injected into Claude context)
# Use jq for safe JSON encoding; printf fallback strips remaining quotes
if command -v jq &> /dev/null; then
  jq -n --arg c "$CONTEXT" '{"hookSpecificOutput":{"additionalContext":$c}}'
else
  SAFE_CONTEXT="${CONTEXT//\\/\\\\}"
  SAFE_CONTEXT="${SAFE_CONTEXT//\"/\\\"}"
  printf '{"hookSpecificOutput":{"additionalContext":"%s"}}\n' "$SAFE_CONTEXT"
fi

exit 0
