#!/bin/bash
set -euo pipefail
# ConfigChange Hook: Audit and block config changes while pipeline is active
# policy_settings changes are logged only; other changes are blocked (exit 2)

# trap: Preserve exit code on abnormal termination + stderr message
# shellcheck disable=SC2329
cleanup() {
  local exit_code=$?
  if [ "$exit_code" -ne 0 ] && [ "$exit_code" -ne 2 ]; then
    echo "AFC CONFIG: Abnormal exit (exit code: $exit_code)" >&2
  fi
  exit "$exit_code"
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PIPELINE_FLAG="${PROJECT_DIR}/.claude/.afc-active"
AUDIT_LOG="${PROJECT_DIR}/.claude/.afc-config-audit.log"

# Read hook data from stdin
INPUT=$(cat)

# Exit silently if pipeline is inactive
if [ ! -f "$PIPELINE_FLAG" ]; then
  exit 0
fi

# Parse source (jq preferred, grep/sed fallback)
SOURCE=""
if command -v jq >/dev/null 2>&1; then
  SOURCE=$(printf '%s\n' "$INPUT" | jq -r '.source // empty' 2>/dev/null || true)
else
  SOURCE=$(printf '%s\n' "$INPUT" | grep -o '"source"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
fi
SOURCE=$(printf '%s' "$SOURCE" | head -1 | tr -d '\n\r' | cut -c1-500)

# Parse file_path (jq preferred, grep/sed fallback)
FILE_PATH=""
if command -v jq >/dev/null 2>&1; then
  FILE_PATH=$(printf '%s\n' "$INPUT" | jq -r '.file_path // empty' 2>/dev/null || true)
else
  FILE_PATH=$(printf '%s\n' "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
fi
FILE_PATH=$(printf '%s' "$FILE_PATH" | head -1 | tr -d '\n\r' | cut -c1-500)

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# policy_settings changes are logged only (not blocked)
if [ "$SOURCE" = "policy_settings" ]; then
  printf '[%s] source=%s path=%s\n' "$TIMESTAMP" "$SOURCE" "$FILE_PATH" >> "$AUDIT_LOG"
  exit 0
fi

# Other changes: Write audit log + block
printf '[%s] source=%s path=%s\n' "$TIMESTAMP" "$SOURCE" "$FILE_PATH" >> "$AUDIT_LOG"
echo "AFC CONFIG: Config change detected while pipeline is active. source=${SOURCE} path=${FILE_PATH}" >&2
exit 2
