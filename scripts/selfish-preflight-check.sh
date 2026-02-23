#!/bin/bash
set -euo pipefail

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

CI_COMMAND=""
CI_SOURCE=""

# ── Helpers ──────────────────────────────────────────────

# shellcheck disable=SC2317
_detect_pm() {
  local dir="$1"
  if [[ -f "$dir/pnpm-lock.yaml" ]]; then printf 'pnpm'
  elif [[ -f "$dir/yarn.lock" ]]; then printf 'yarn'
  elif [[ -f "$dir/bun.lock" || -f "$dir/bun.lockb" ]]; then printf 'bun'
  elif [[ -f "$dir/package-lock.json" ]]; then printf 'npm'
  elif [[ -f "$dir/package.json" ]] && command -v jq > /dev/null 2>&1; then
    local pm_field
    pm_field=$(jq -r '.packageManager // empty' "$dir/package.json" 2>/dev/null)
    if [[ -n "$pm_field" ]]; then
      printf '%s' "${pm_field%%@*}"
    else
      printf 'npm'
    fi
  else
    printf 'npm'
  fi
}

# shellcheck disable=SC2317
_has_script() {
  local pkg="$1" script="$2"
  if command -v jq > /dev/null 2>&1; then
    jq -e ".scripts[\"$script\"]" "$pkg" > /dev/null 2>&1
  else
    grep -qE "\"$script\"[[:space:]]*:" "$pkg" 2>/dev/null
  fi
}

# ── PM Detection (lockfile-first, Turborepo pattern) ─────

PM=$(_detect_pm "$PROJECT_DIR")

printf 'Preflight Check:\n'

# ── Check 1: CI command (4-tier cascade) ─────────────────

# 1a. selfish.config.md — most explicit, user-configured
CONFIG_FILE="$PROJECT_DIR/.claude/selfish.config.md"
if [[ -z "$CI_COMMAND" && -f "$CONFIG_FILE" ]]; then
  CI_COMMAND=$(grep -E '^\s*ci:\s*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/.*ci: *"\([^"]*\)".*/\1/' || true)
  if [[ -z "$CI_COMMAND" ]]; then
    CI_COMMAND=$(grep -E '^\s*gate:\s*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/.*gate: *"\([^"]*\)".*/\1/' || true)
  fi
  [[ -n "$CI_COMMAND" ]] && CI_SOURCE="selfish.config.md"
fi

# 1b. Monorepo tools (turbo, nx, pnpm workspaces)
if [[ -z "$CI_COMMAND" ]]; then
  if [[ -f "$PROJECT_DIR/turbo.json" ]]; then
    if [[ "$PM" == "pnpm" || "$PM" == "yarn" || "$PM" == "bun" ]]; then
      CI_COMMAND="$PM turbo test"
    else
      CI_COMMAND="npx turbo test"
    fi
    CI_SOURCE="turbo.json"
  elif [[ -f "$PROJECT_DIR/nx.json" ]]; then
    CI_COMMAND="npx nx run-many --target=test"
    CI_SOURCE="nx.json"
  elif [[ -f "$PROJECT_DIR/pnpm-workspace.yaml" ]] && ! _has_script "$PROJECT_DIR/package.json" "test" 2>/dev/null; then
    CI_COMMAND="pnpm -r test"
    CI_SOURCE="pnpm-workspace.yaml"
  fi
fi

# 1c. package.json scripts (PM-aware)
if [[ -z "$CI_COMMAND" && -f "$PROJECT_DIR/package.json" ]]; then
  for script in "test:all" "test" "ci" "check"; do
    if _has_script "$PROJECT_DIR/package.json" "$script"; then
      if [[ "$script" == "test" ]]; then
        CI_COMMAND="$PM test"
      else
        CI_COMMAND="$PM run $script"
      fi
      CI_SOURCE="package.json"
      break
    fi
  done
fi

# 1d. Makefile
if [[ -z "$CI_COMMAND" && -f "$PROJECT_DIR/Makefile" ]]; then
  MAKE_TARGET=$(grep -E '^(test|check|ci):' "$PROJECT_DIR/Makefile" 2>/dev/null | head -1 | cut -d: -f1 || true)
  if [[ -n "$MAKE_TARGET" ]]; then
    CI_COMMAND="make $MAKE_TARGET"
    CI_SOURCE="Makefile"
  fi
fi

# Report CI command result
if [[ -n "$CI_COMMAND" ]]; then
  printf '  \xe2\x9c\x93 CI command: %s  [%s]\n' "$CI_COMMAND" "$CI_SOURCE"
  PASS_COUNT=$((PASS_COUNT + 1))
elif [[ -f "$PROJECT_DIR/package.json" ]]; then
  # package.json exists but no CI script — configuration error
  printf '  \xe2\x9c\x97 CI command: no test script found in package.json\n'
  FAIL_COUNT=$((FAIL_COUNT + 1))
else
  # No recognizable ecosystem — warn instead of fail
  printf '  \xe2\x9a\xa0 CI command: not detected (configure ci: in selfish.config.md)\n'
  WARN_COUNT=$((WARN_COUNT + 1))
fi

# ── Check 2: Dependencies installed ──────────────────────

if [[ -f "$PROJECT_DIR/package.json" ]]; then
  if [[ -d "$PROJECT_DIR/node_modules" ]]; then
    printf '  \xe2\x9c\x93 Dependencies: node_modules present\n'
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    printf '  \xe2\x9a\xa0 Dependencies: node_modules not found (run %s install)\n' "$PM"
    WARN_COUNT=$((WARN_COUNT + 1))
  fi
else
  printf '  \xe2\x9c\x93 Dependencies: no package.json (non-npm project, skipping)\n'
  PASS_COUNT=$((PASS_COUNT + 1))
fi

# ── Check 3: Shellcheck available ────────────────────────

if command -v shellcheck > /dev/null 2>&1; then
  printf '  \xe2\x9c\x93 Shellcheck: installed\n'
  PASS_COUNT=$((PASS_COUNT + 1))
else
  printf '  \xe2\x9a\xa0 Shellcheck: not installed (lint may fail)\n'
  WARN_COUNT=$((WARN_COUNT + 1))
fi

# ── Check 4: Git state ───────────────────────────────────

if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  DIRTY_COUNT=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$DIRTY_COUNT" -eq 0 ]]; then
    printf '  \xe2\x9c\x93 Git state: clean\n'
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    printf '  \xe2\x9a\xa0 Git state: %s uncommitted change(s)\n' "$DIRTY_COUNT"
    WARN_COUNT=$((WARN_COUNT + 1))
  fi
else
  printf '  \xe2\x9a\xa0 Git state: not a git repository\n'
  WARN_COUNT=$((WARN_COUNT + 1))
fi

# ── Check 5: No active pipeline ──────────────────────────

ACTIVE_FILE="$PROJECT_DIR/.claude/.selfish-active"
if [[ -f "$ACTIVE_FILE" ]]; then
  ACTIVE_NAME=$(head -1 "$ACTIVE_FILE" 2>/dev/null | tr -d '\n\r' | cut -c1-100 || printf 'unknown')
  printf '  \xe2\x9c\x97 No active pipeline: pipeline already running (%s)\n' "$ACTIVE_NAME"
  FAIL_COUNT=$((FAIL_COUNT + 1))
else
  printf '  \xe2\x9c\x93 No active pipeline\n'
  PASS_COUNT=$((PASS_COUNT + 1))
fi

# ── Result ────────────────────────────────────────────────

printf '\n'
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  if [[ "$WARN_COUNT" -gt 0 ]]; then
    printf 'Result: FAIL (%d error(s), %d warning(s))\n' "$FAIL_COUNT" "$WARN_COUNT"
  else
    printf 'Result: FAIL (%d error(s))\n' "$FAIL_COUNT"
  fi
  exit 1
else
  if [[ "$WARN_COUNT" -gt 0 ]]; then
    printf 'Result: PASS (%d warning(s))\n' "$WARN_COUNT"
  else
    printf 'Result: PASS\n'
  fi
  exit 0
fi
