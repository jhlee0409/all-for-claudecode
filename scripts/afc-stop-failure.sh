#!/bin/bash
set -euo pipefail
# StopFailure Hook: Output user-friendly error messages for API failures
# Receives error details from Claude Code on API/stop failure
#
# StopFailure output is ignored by Claude Code — stderr is shown to the user only

# shellcheck disable=SC2329
cleanup() {
  # Placeholder for temporary resource cleanup if needed
  :
}
trap cleanup EXIT

# Parse input from stdin
INPUT=$(cat)

# Extract error field
if command -v jq &>/dev/null; then
  ERROR=$(printf '%s\n' "$INPUT" | jq -r '.error // empty' 2>/dev/null || true)
else
  ERROR=$(printf '%s\n' "$INPUT" | grep -o '"error"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
fi

ERROR="${ERROR:-}"
ERROR=$(printf '%s\n' "$ERROR" | head -1 | cut -c1-200)

# Match error type and output user-friendly message to stderr
case "$ERROR" in
  *rate_limit*|*"rate limit"*|*"Rate limit"*)
    printf '[afc] Rate limit reached. Wait 30-60 seconds before retrying. If persistent, check your TPM/RPM limits.\n' >&2
    ;;
  *authentication_failed*|*"authentication failed"*|*"Authentication failed"*)
    printf "[afc] Authentication failed. Run 'gh auth login' or check your API key.\n" >&2
    ;;
  *server_error*|*"server error"*|*"Server error"*)
    printf '[afc] API server error. This is usually temporary — retry in a few seconds.\n' >&2
    ;;
  *)
    if [ -n "$ERROR" ]; then
      printf '[afc] API error: %s. Check Claude Code status.\n' "$ERROR" >&2
    fi
    ;;
esac

exit 0
