#!/bin/bash
set -euo pipefail
# PreToolUse Hook: TDD Guard — blocks non-test file writes during implement phase
# Only active when: pipeline active + phase=implement + tdd=strict (or warns on guide)
# tdd setting read from afc.config.md CI Commands YAML

# shellcheck source=afc-state.sh
. "$(dirname "$0")/afc-state.sh"

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

ALLOW='{"hookSpecificOutput":{"permissionDecision":"allow"}}'

# Early exit: TDD guard only applies during active pipeline
if ! afc_state_is_active; then
  cat > /dev/null  # consume stdin to prevent SIGPIPE
  printf '%s\n' "$ALLOW"
  exit 0
fi

# Early exit: only guard during implement phase
PHASE="$(afc_state_read phase || echo '')"
if [ "$PHASE" != "implement" ]; then
  cat > /dev/null  # consume stdin to prevent SIGPIPE
  printf '%s\n' "$ALLOW"
  exit 0
fi

# Consume stdin now that we know we need to inspect it
INPUT=$(cat)

# Read tdd setting from afc.config.md (YAML in markdown — grep/sed parse)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONFIG_FILE="$PROJECT_DIR/.claude/afc.config.md"
TDD_MODE="off"

if [ -f "$CONFIG_FILE" ]; then
  TDD_MODE=$(grep -E '^tdd:' "$CONFIG_FILE" | head -1 | sed 's/^tdd:[[:space:]]*"//;s/".*$//' 2>/dev/null || echo "off")
fi

# Normalize: empty or missing -> off
TDD_MODE="${TDD_MODE:-off}"

# If tdd is off -> allow immediately (0ms overhead goal)
if [ "$TDD_MODE" = "off" ]; then
  printf '%s\n' "$ALLOW"
  exit 0
fi

if [ -z "$INPUT" ]; then
  printf '%s\n' "$ALLOW"
  exit 0
fi

# Extract file_path from tool_input
FILE_PATH=""
if command -v jq &> /dev/null; then
  FILE_PATH=$(printf '%s\n' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
else
  FILE_PATH=$(printf '%s\n' "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
fi

if [ -z "$FILE_PATH" ]; then
  printf '%s\n' "$ALLOW"
  exit 0
fi

# Check if the file is a test file — always allow test file edits
# Patterns: *.test.*, *.spec.*, *_test.*, *_spec.*, *_test.go, spec/*, __tests__/*, test/*, tests/*
BASENAME=$(basename "$FILE_PATH")
if printf '%s' "$BASENAME" | grep -qE '\.(test|spec)\.[^.]+$'; then
  printf '%s\n' "$ALLOW"
  exit 0
fi
if printf '%s' "$BASENAME" | grep -qE '_(test|spec)\.[^.]+$'; then
  printf '%s\n' "$ALLOW"
  exit 0
fi
if printf '%s' "$FILE_PATH" | grep -qE '(^|/)(spec|__tests__|tests?)/'; then
  printf '%s\n' "$ALLOW"
  exit 0
fi

# Non-code files (markdown, json, yaml, config) — always allow
if printf '%s' "$BASENAME" | grep -qE '\.(md|json|ya?ml|toml|txt|csv|lock|gitignore)$'; then
  printf '%s\n' "$ALLOW"
  exit 0
fi

# At this point: implement phase + tdd is strict or guide + file is not a test file + file is code
# Sanitize BASENAME for JSON safety (remove double quotes and backslashes)
SAFE_BASENAME=$(printf '%s' "$BASENAME" | tr -d '"\\')

if [ "$TDD_MODE" = "strict" ]; then
  printf '{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":"[afc:tdd-guard] TDD strict mode: write test file first before implementing. Target: %s"}}\n' "$SAFE_BASENAME"
  exit 0
fi

if [ "$TDD_MODE" = "guide" ]; then
  printf '{"hookSpecificOutput":{"permissionDecision":"allow","additionalContext":"[afc:tdd-guard] TDD guide: consider writing tests first for %s"}}\n' "$SAFE_BASENAME"
  exit 0
fi

# Fallback: unknown tdd value -> allow
printf '%s\n' "$ALLOW"
exit 0
