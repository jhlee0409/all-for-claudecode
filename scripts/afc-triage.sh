#!/bin/bash
set -euo pipefail

# Triage Metadata Collector: Gathers PR and issue metadata via gh CLI
#
# Usage: afc-triage.sh [--pr|--issue|--all|#N #M ...]
#   --pr     Collect PRs only
#   --issue  Collect issues only
#   --all    Collect both (default)
#   #N #M    Collect specific items by number
#
# Output: JSON object with "prs" and "issues" arrays to stdout
# Exit 0: success
# Exit 1: gh CLI not available or API error

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

# ── Check prerequisites ──────────────────────────────────

if ! command -v gh >/dev/null 2>&1; then
  printf '[afc:triage] Error: gh CLI not found. Install from https://cli.github.com/\n' >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  printf '[afc:triage] Error: gh not authenticated. Run: gh auth login\n' >&2
  exit 1
fi

# ── Parse arguments ──────────────────────────────────────

MODE="all"
SPECIFIC_NUMBERS=()
DEEP_FLAG="false"

for arg in "$@"; do
  case "$arg" in
    --pr)    MODE="pr" ;;
    --issue) MODE="issue" ;;
    --all)   MODE="all" ;;
    --deep)  DEEP_FLAG="true" ;;
    \#*)
      # Strip leading # and add number
      num="${arg#\#}"
      if [[ "$num" =~ ^[0-9]+$ ]]; then
        SPECIFIC_NUMBERS+=("$num")
      fi
      ;;
    *)
      # Try as plain number
      if [[ "$arg" =~ ^[0-9]+$ ]]; then
        SPECIFIC_NUMBERS+=("$arg")
      fi
      ;;
  esac
done

# ── Collect metadata ─────────────────────────────────────

PR_JSON="[]"
ISSUE_JSON="[]"

if [ ${#SPECIFIC_NUMBERS[@]} -gt 0 ]; then
  # Specific items: try each as PR first, then as issue
  PR_ITEMS="[]"
  ISSUE_ITEMS="[]"

  for num in "${SPECIFIC_NUMBERS[@]}"; do
    # Try as PR
    pr_data=""
    pr_data=$(gh pr view "$num" --json number,title,headRefName,author,labels,additions,deletions,changedFiles,createdAt,updatedAt,reviewDecision,isDraft 2>/dev/null || true)

    if [ -n "$pr_data" ]; then
      if command -v jq >/dev/null 2>&1; then
        PR_ITEMS=$(printf '%s\n' "$PR_ITEMS" | jq --argjson item "$pr_data" '. + [$item]')
      else
        # Fallback: append raw JSON (best effort)
        PR_ITEMS="$pr_data"
      fi
    else
      # Try as issue
      issue_data=""
      issue_data=$(gh issue view "$num" --json number,title,labels,author,createdAt,updatedAt,comments 2>/dev/null || true)

      if [ -n "$issue_data" ]; then
        if command -v jq >/dev/null 2>&1; then
          ISSUE_ITEMS=$(printf '%s\n' "$ISSUE_ITEMS" | jq --argjson item "$issue_data" '. + [$item]')
        else
          ISSUE_ITEMS="$issue_data"
        fi
      else
        printf '[afc:triage] Warning: #%s not found as PR or issue\n' "$num" >&2
      fi
    fi
  done

  PR_JSON="$PR_ITEMS"
  ISSUE_JSON="$ISSUE_ITEMS"
else
  # Bulk collection by mode
  if [ "$MODE" = "pr" ] || [ "$MODE" = "all" ]; then
    PR_JSON=$(gh pr list --json number,title,headRefName,author,labels,additions,deletions,changedFiles,createdAt,updatedAt,reviewDecision,isDraft --limit 50 2>/dev/null || printf '[]')
  fi

  if [ "$MODE" = "issue" ] || [ "$MODE" = "all" ]; then
    ISSUE_JSON=$(gh issue list --json number,title,labels,author,createdAt,updatedAt,comments --limit 50 2>/dev/null || printf '[]')
  fi
fi

# ── Build output ─────────────────────────────────────────

if command -v jq >/dev/null 2>&1; then
  jq -n \
    --argjson prs "$PR_JSON" \
    --argjson issues "$ISSUE_JSON" \
    --arg deep "$DEEP_FLAG" \
    '{prs: $prs, issues: $issues, deep: ($deep == "true"), collectedAt: now | todate}'
else
  # Fallback: construct JSON manually
  printf '{"prs":%s,"issues":%s,"deep":%s,"collectedAt":"%s"}\n' \
    "$PR_JSON" \
    "$ISSUE_JSON" \
    "$DEEP_FLAG" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
fi

exit 0
