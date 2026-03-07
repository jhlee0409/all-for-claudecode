#!/bin/bash
set -euo pipefail

# UserPromptSubmit Hook: Learner signal collection
# Detects correction/preference patterns in user prompts via keyword pre-filter.
# Writes structured metadata to JSONL queue (file only, NO stdout).
# Gated behind .claude/afc/learner.json existence (opt-in).

# shellcheck source=afc-state.sh
. "$(dirname "$0")/afc-state.sh"

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LEARNER_CONFIG="$PROJECT_DIR/.claude/afc/learner.json"
QUEUE_FILE="$PROJECT_DIR/.claude/.afc-learner-queue.jsonl"

# Gate: exit immediately if learner is not enabled
if [ ! -f "$LEARNER_CONFIG" ]; then
  exit 0
fi

# Read stdin (contains user prompt JSON)
INPUT=$(cat)

# Extract prompt text
USER_TEXT=""
if command -v jq >/dev/null 2>&1; then
  USER_TEXT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)
else
  # shellcheck disable=SC2001
  USER_TEXT=$(printf '%s' "$INPUT" | sed 's/.*"prompt"[[:space:]]*:[[:space:]]*"//;s/".*//' 2>/dev/null || true)
fi

# Skip empty prompts and explicit slash commands
if [ -z "$USER_TEXT" ]; then
  exit 0
fi
if printf '%s' "$USER_TEXT" | grep -qE '^\s*/afc:' 2>/dev/null; then
  exit 0
fi

# Normalize: lowercase + truncate for matching
LOWER=$(printf '%s' "$USER_TEXT" | tr '[:upper:]' '[:lower:]' | cut -c1-500)

# --- Keyword pre-filter ---
# Only high-confidence correction/preference anchors.
# Designed for low false-positive rate: these patterns indicate
# reusable behavioral preferences, not task-specific redirections.
SIGNAL_TYPE=""
CATEGORY=""

# Explicit memory requests (highest confidence)
if printf '%s' "$LOWER" | grep -qE '(from now on|remember that|remember this|앞으로는|앞으로 항상|기억해)' 2>/dev/null; then
  SIGNAL_TYPE="explicit-preference"
  CATEGORY="workflow"
# Universal preference patterns (high confidence)
elif printf '%s' "$LOWER" | grep -qE '^(always |never |항상 |절대 )' 2>/dev/null; then
  SIGNAL_TYPE="universal-preference"
  CATEGORY="style"
# Correction with permanent intent
elif printf '%s' "$LOWER" | grep -qE '(don.t ever|do not ever|stop (using|doing)|금지|쓰지.?마|하지.?마)' 2>/dev/null; then
  SIGNAL_TYPE="permanent-correction"
  CATEGORY="style"
# Naming/convention preferences
elif printf '%s' "$LOWER" | grep -qE '(use .+ instead of|prefer .+ over|\.+ not \.+|대신 .+ 써|말고 .+ 써)' 2>/dev/null; then
  SIGNAL_TYPE="convention-preference"
  CATEGORY="naming"
fi

# No signal detected — exit silently
if [ -z "$SIGNAL_TYPE" ]; then
  exit 0
fi

# --- Extract safe excerpt (max 80 chars, redacted) ---
# Take the first sentence or 80 chars, whichever is shorter
EXCERPT=$(printf '%s' "$USER_TEXT" | head -1 | cut -c1-80)
# Redact potential secrets (key=value, token patterns, URLs with credentials)
EXCERPT=$(printf '%s' "$EXCERPT" | sed -E \
  's/([Kk]ey|[Tt]oken|[Pp]assword|[Ss]ecret|[Aa]uth)[[:space:]]*[=:][[:space:]]*[^ ]*/\1=***REDACTED***/g' \
  | sed -E 's|https?://[^@]*@|https://***@|g')

# --- Queue cap check (max 50 entries) ---
QUEUE_SIZE=0
if [ -f "$QUEUE_FILE" ]; then
  QUEUE_SIZE=$(wc -l < "$QUEUE_FILE" | tr -d ' ')
fi
if [ "$QUEUE_SIZE" -ge 50 ]; then
  exit 0
fi

# --- Determine pipeline context ---
SOURCE="standalone"
if afc_state_is_active; then
  FEATURE=$(afc_state_read feature 2>/dev/null || echo "unknown")
  PHASE=$(afc_state_read phase 2>/dev/null || echo "unknown")
  SOURCE="pipeline:${FEATURE}:${PHASE}"
fi

# --- Append structured metadata to JSONL (atomic write) ---
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# Ensure parent directory exists
mkdir -p "$(dirname "$QUEUE_FILE")"

if command -v jq >/dev/null 2>&1; then
  jq -nc \
    --arg type "$SIGNAL_TYPE" \
    --arg cat "$CATEGORY" \
    --arg excerpt "$EXCERPT" \
    --arg ts "$TIMESTAMP" \
    --arg src "$SOURCE" \
    '{signal_type: $type, category: $cat, excerpt: $excerpt, timestamp: $ts, source: $src}' \
    >> "$QUEUE_FILE"
else
  # Safe JSON construction without jq
  SAFE_EXCERPT="${EXCERPT//\\/\\\\}"
  SAFE_EXCERPT="${SAFE_EXCERPT//\"/\\\"}"
  printf '{"signal_type":"%s","category":"%s","excerpt":"%s","timestamp":"%s","source":"%s"}\n' \
    "$SIGNAL_TYPE" "$CATEGORY" "$SAFE_EXCERPT" "$TIMESTAMP" "$SOURCE" \
    >> "$QUEUE_FILE"
fi

exit 0
