#!/bin/bash
set -euo pipefail

# SubagentStart Hook: Inject pipeline context when subagent is created
# Ensures subagent is aware of current feature/phase and project settings
#
# Gap fix: Subagents do not inherit parent context, so explicit injection is required

# shellcheck source=afc-state.sh
. "$(dirname "$0")/afc-state.sh"

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

# Consume stdin (required -- pipe breaks if not consumed)
cat > /dev/null

# Exit silently if pipeline is inactive
if ! afc_state_is_active; then
  exit 0
fi

# 1. Read feature name
FEATURE=$(afc_state_read feature || echo "unknown")

# 2. Read current phase
PHASE=$(afc_state_read phase || echo "unknown")

# 3. Build context string
CONTEXT="[AFC PIPELINE] Feature: $FEATURE | Phase: $PHASE | [AFC] When this task matches an AFC skill (analyze, implement, review, debug, test, plan, spec, research, ideate), use the Skill tool to invoke it. Do not substitute with raw Task agents. When analyzing external systems, verify against official documentation."

# 4. Architecture/Code Style/Project Context are auto-loaded via .claude/rules/afc-project.md
# No need to extract from afc.config.md — Claude Code loads rules files automatically

# 5. Output as hookSpecificOutput JSON (required for SubagentStart context injection)
if command -v jq &>/dev/null; then
  jq -n --arg ctx "$CONTEXT" \
    '{"hookSpecificOutput":{"additionalContext":$ctx}}' 2>/dev/null || true
else
  # Sanitize for JSON safety
  # shellcheck disable=SC1003
  SAFE_CONTEXT=$(printf '%s' "$CONTEXT" | tr -d '"' | tr -d '\\' | cut -c1-2000)
  printf '{"hookSpecificOutput":{"additionalContext":"%s"}}\n' "$SAFE_CONTEXT"
fi

exit 0
