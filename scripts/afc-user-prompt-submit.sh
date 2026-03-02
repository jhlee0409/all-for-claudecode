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

  # Early exit for empty prompts (context-only messages, malformed JSON)
  if [ -z "$LOWER" ]; then
    if command -v jq >/dev/null 2>&1; then
      jq -n --arg c "[afc] If this request matches an afc skill, invoke it via Skill tool. See CLAUDE.md routing table." \
        '{"hookSpecificOutput":{"additionalContext":$c}}'
    else
      printf '{"hookSpecificOutput":{"additionalContext":"[afc] If this request matches an afc skill, invoke it via Skill tool. See CLAUDE.md routing table."}}\n'
    fi
    exit 0
  fi

  # Intent detection: priority-ordered if/elif chain.
  # Each pattern targets strong-signal phrases to minimize false positives.
  # The model retains final authority — this is a hint, not enforcement.
  SKILL=""
  # High confidence: distinctive multi-word or rare keywords
  if printf '%s' "$LOWER" | grep -qE '(bug|broken|debug|not working|crash|exception)' 2>/dev/null; then
    SKILL="afc:debug"
  elif printf '%s' "$LOWER" | grep -qE '(code review|pr review)' 2>/dev/null; then
    SKILL="afc:review"
  elif printf '%s' "$LOWER" | grep -qE '(write test|add test|test coverage|improve coverage)' 2>/dev/null; then
    SKILL="afc:test"
  elif printf '%s' "$LOWER" | grep -qE '(security scan|security review|security audit|vulnerabilit)' 2>/dev/null; then
    SKILL="afc:security"
  elif printf '%s' "$LOWER" | grep -qE '(architecture|architect|system design)' 2>/dev/null; then
    SKILL="afc:architect"
  elif printf '%s' "$LOWER" | grep -qE '(doctor|health check|diagnose.*project)' 2>/dev/null; then
    SKILL="afc:doctor"
  elif printf '%s' "$LOWER" | grep -qE '(quality audit|qa audit|project quality)' 2>/dev/null; then
    SKILL="afc:qa"
  elif printf '%s' "$LOWER" | grep -qE '(new release|version bump|changelog|publish.*package)' 2>/dev/null; then
    SKILL="afc:launch"
  # Medium confidence: still distinctive but broader
  elif printf '%s' "$LOWER" | grep -qE '(specification|requirements|acceptance criteria)' 2>/dev/null; then
    SKILL="afc:spec"
  elif printf '%s' "$LOWER" | grep -qE '(brainstorm|ideate|what to build|product brief)' 2>/dev/null; then
    SKILL="afc:ideate"
  elif printf '%s' "$LOWER" | grep -qE '(expert advice)' 2>/dev/null; then
    SKILL="afc:consult"
  elif printf '%s' "$LOWER" | grep -qE '(analyz|trace.*flow|how does.*work)' 2>/dev/null; then
    SKILL="afc:analyze"
  elif printf '%s' "$LOWER" | grep -qE '(research|investigat|compare.*lib)' 2>/dev/null; then
    SKILL="afc:research"
  # Lower confidence: common verbs
  elif printf '%s' "$LOWER" | grep -qE '(implement|add feature|refactor|modify.*code)' 2>/dev/null; then
    SKILL="afc:implement"
  elif printf '%s' "$LOWER" | grep -qE '(review)' 2>/dev/null; then
    SKILL="afc:review"
  elif printf '%s' "$LOWER" | grep -qE '(spec[^a-z]|spec$)' 2>/dev/null; then
    SKILL="afc:spec"
  elif printf '%s' "$LOWER" | grep -qE '(plan[^a-z]|plan$)' 2>/dev/null; then
    SKILL="afc:plan"
  fi

  # Build output (no TASK HYGIENE in inactive mode — stop-gate handles cleanup scope)
  if [ -n "$SKILL" ]; then
    HINT="[afc:route -> ${SKILL}] Detected intent from user prompt. Invoke /${SKILL} via Skill tool."
  else
    HINT="[afc] If this request matches an afc skill, invoke it via Skill tool. See CLAUDE.md routing table."
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -n --arg c "$HINT" '{"hookSpecificOutput":{"additionalContext":$c}}'
  else
    printf '{"hookSpecificOutput":{"additionalContext":"%s"}}\n' "$HINT"
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

# Build context message
CONTEXT="[Pipeline: ${FEATURE}] [Phase: ${PHASE}] [TASK HYGIENE: Mark completed tasks via TaskUpdate(status: completed) -- do not leave stale tasks]"

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
if command -v jq >/dev/null 2>&1; then
  jq -n --arg c "$CONTEXT" '{"hookSpecificOutput":{"additionalContext":$c}}'
else
  SAFE_CONTEXT="${CONTEXT//\\/\\\\}"
  SAFE_CONTEXT="${SAFE_CONTEXT//\"/\\\"}"
  printf '{"hookSpecificOutput":{"additionalContext":"%s"}}\n' "$SAFE_CONTEXT"
fi

exit 0
