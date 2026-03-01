#!/bin/bash
set -euo pipefail

# afc-doctor.sh — Automated health check for all-for-claudecode plugin
# Runs categories 1-8 deterministically. Categories 9-11 require LLM analysis.
# Output: human-readable text (no JSON), directly printable.
# Read-only: never modifies files.

# shellcheck source=afc-state.sh
. "$(dirname "$0")/afc-state.sh"

cleanup() { :; }
trap cleanup EXIT

# --- Globals ---
PASS=0
WARN=0
FAIL=0
VERBOSE=false

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --verbose) VERBOSE=true ;;
  esac
done

# Derive paths
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# --- Helpers ---
pass() {
  PASS=$((PASS + 1))
  printf '  \xe2\x9c\x93 %s\n' "$1"
}

warn() {
  WARN=$((WARN + 1))
  printf '  \xe2\x9a\xa0 %s\n' "$1"
  if [ -n "${2:-}" ]; then
    printf '    Fix: %s\n' "$2"
  fi
}

fail() {
  FAIL=$((FAIL + 1))
  printf '  \xe2\x9c\x97 %s\n' "$1"
  if [ -n "${2:-}" ]; then
    printf '    Fix: %s\n' "$2"
  fi
}

section() {
  printf '\n%s\n' "$1"
}

# --- Category 1: Environment ---
section "Environment"

if command -v git >/dev/null 2>&1; then
  GIT_VER=$(git --version 2>/dev/null | sed 's/git version //')
  pass "git installed ($GIT_VER)"
else
  fail "git not found" "install git"
fi

if command -v jq >/dev/null 2>&1; then
  pass "jq installed"
else
  warn "jq not found — hook scripts will use grep/sed fallback" "brew install jq"
fi

# --- Category 2: Project Config ---
section "Project Config"

CONFIG_FILE="$PROJECT_DIR/.claude/afc.config.md"
if [ -f "$CONFIG_FILE" ]; then
  pass ".claude/afc.config.md exists"

  # Required sections
  MISSING_SECTIONS=""
  for sec in "## CI Commands" "## Architecture" "## Code Style"; do
    if ! grep -q "$sec" "$CONFIG_FILE" 2>/dev/null; then
      MISSING_SECTIONS="${MISSING_SECTIONS:+$MISSING_SECTIONS, }$sec"
    fi
  done
  if [ -z "$MISSING_SECTIONS" ]; then
    pass "Required sections present"
  else
    fail "Missing sections: $MISSING_SECTIONS" "add missing section to .claude/afc.config.md or re-run /afc:init"
  fi

  # Gate command
  if grep -q 'gate:' "$CONFIG_FILE" 2>/dev/null; then
    pass "Gate command defined"
  else
    fail "gate: field not found in CI Commands" "add gate: field to ## CI Commands section"
  fi

  # CI/gate command execution (verbose only)
  if [ "$VERBOSE" = true ]; then
    CI_CMD=$(grep -A1 '```yaml' "$CONFIG_FILE" 2>/dev/null | grep 'ci:' | head -1 | sed 's/ci:[[:space:]]*"//;s/"[[:space:]]*$//' || true)
    if [ -n "$CI_CMD" ]; then
      if (cd "$PROJECT_DIR" && eval "$CI_CMD" >/dev/null 2>&1); then
        pass "CI command runnable ($CI_CMD)"
      else
        warn "CI command failed: $CI_CMD" "check ci: in afc.config.md"
      fi
    fi

    GATE_CMD=$(grep -A5 '```yaml' "$CONFIG_FILE" 2>/dev/null | grep 'gate:' | head -1 | sed 's/gate:[[:space:]]*"//;s/"[[:space:]]*$//' || true)
    if [ -n "$GATE_CMD" ]; then
      if (cd "$PROJECT_DIR" && eval "$GATE_CMD" >/dev/null 2>&1); then
        pass "Gate command runnable ($GATE_CMD)"
      else
        warn "Gate command failed: $GATE_CMD" "check gate: in afc.config.md"
      fi
    fi
  fi
else
  fail ".claude/afc.config.md not found" "run /afc:init"
fi

# --- Category 3: CLAUDE.md Integration ---
section "CLAUDE.md Integration"

GLOBAL_CLAUDE="$HOME/.claude/CLAUDE.md"
if [ -f "$GLOBAL_CLAUDE" ]; then
  pass "Global ~/.claude/CLAUDE.md exists"

  # AFC block
  HAS_START=$(grep -c '<!-- AFC:START -->' "$GLOBAL_CLAUDE" 2>/dev/null || echo 0)
  HAS_END=$(grep -c '<!-- AFC:END -->' "$GLOBAL_CLAUDE" 2>/dev/null || echo 0)
  if [ "$HAS_START" -gt 0 ] && [ "$HAS_END" -gt 0 ]; then
    pass "all-for-claudecode block present"

    # Version check
    BLOCK_VERSION=$(grep -o 'AFC:VERSION:[0-9][0-9.]*' "$GLOBAL_CLAUDE" 2>/dev/null | head -1 | sed 's/AFC:VERSION://' || true)
    if [ -f "$PLUGIN_ROOT/package.json" ]; then
      if command -v jq >/dev/null 2>&1; then
        PLUGIN_VERSION=$(jq -r '.version // empty' "$PLUGIN_ROOT/package.json" 2>/dev/null || true)
      else
        PLUGIN_VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$PLUGIN_ROOT/package.json" 2>/dev/null | head -1 | sed 's/.*: *"//;s/"//') || true
      fi

      if [ -n "${BLOCK_VERSION:-}" ] && [ -n "${PLUGIN_VERSION:-}" ]; then
        if [ "$BLOCK_VERSION" = "$PLUGIN_VERSION" ]; then
          pass "Block version matches plugin ($PLUGIN_VERSION)"
        else
          warn "all-for-claudecode block outdated (block: $BLOCK_VERSION, plugin: $PLUGIN_VERSION)" "run /afc:init to update"
        fi
      fi
    fi
  else
    fail "all-for-claudecode block not found" "run /afc:init to inject all-for-claudecode block"
  fi
else
  warn "No global ~/.claude/CLAUDE.md" "run /afc:init"
fi

# --- Category 4: Legacy Migration ---
section "Legacy Migration"

LEGACY_FOUND=false

# Legacy CLAUDE.md block
if [ -f "$GLOBAL_CLAUDE" ] && grep -q '<!-- SELFISH:START -->' "$GLOBAL_CLAUDE" 2>/dev/null; then
  LEGACY_FOUND=true
  warn "Legacy SELFISH:START block in ~/.claude/CLAUDE.md" "run /afc:init (will replace)"
fi

# Legacy config
if [ -f "$PROJECT_DIR/.claude/selfish.config.md" ]; then
  LEGACY_FOUND=true
  warn "Legacy config .claude/selfish.config.md found" "mv .claude/selfish.config.md .claude/afc.config.md"
fi

# Legacy state files
LEGACY_STATE=$(find "$PROJECT_DIR/.claude" -maxdepth 1 -name '.selfish-*' 2>/dev/null | head -1 || true)
if [ -n "$LEGACY_STATE" ]; then
  LEGACY_FOUND=true
  warn "Legacy state files .claude/.selfish-* found" "cd .claude && for f in .selfish-*; do mv \"\$f\" \"\${f/.selfish-/.afc-}\"; done"
fi

# Legacy artifact dir
if [ -d "$PROJECT_DIR/.claude/selfish" ]; then
  LEGACY_FOUND=true
  warn "Legacy artifact directory .claude/selfish/ found" "mv .claude/selfish .claude/afc"
fi

# Legacy git tags
LEGACY_TAGS=$(cd "$PROJECT_DIR" 2>/dev/null && git tag -l 'selfish/*' 2>/dev/null | head -1 || true)
if [ -n "$LEGACY_TAGS" ]; then
  LEGACY_FOUND=true
  warn "Legacy git tags selfish/* found" "git tag -l 'selfish/*' | xargs git tag -d"
fi

# Legacy plugin
SETTINGS_FILE="$HOME/.claude/settings.json"
if [ -f "$SETTINGS_FILE" ] && grep -q 'selfish-pipeline' "$SETTINGS_FILE" 2>/dev/null; then
  LEGACY_FOUND=true
  warn "Old selfish-pipeline plugin still installed" "claude plugin uninstall selfish@selfish-pipeline"
fi

if [ "$LEGACY_FOUND" = false ]; then
  pass "No legacy artifacts"
fi

# --- Category 5: Pipeline State ---
section "Pipeline State"

if [ -f "$PROJECT_DIR/.claude/.afc-state.json" ]; then
  if afc_state_is_active; then
    FEAT=$(afc_state_read feature 2>/dev/null || echo "unknown")
    PH=$(afc_state_read phase 2>/dev/null || echo "unknown")
    warn "Active pipeline state (feature: $FEAT, phase: $PH)" "\"${PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh\" end --force or /afc:resume"
  else
    warn "Zombie state file found (.afc-state.json exists but invalid)" "rm -f .claude/.afc-state.json"
  fi
else
  pass "No stale pipeline state"
fi

# Orphaned artifacts
ORPHAN_DIRS=$(find "$PROJECT_DIR/.claude/afc/specs" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true)
if [ -n "$ORPHAN_DIRS" ]; then
  # Check if any are from the active pipeline
  ACTIVE_FEAT=""
  if afc_state_is_active; then
    ACTIVE_FEAT=$(afc_state_read feature 2>/dev/null || true)
  fi
  ORPHAN_FOUND=false
  while IFS= read -r dir; do
    [ -z "$dir" ] && continue
    DIR_NAME=$(basename "$dir")
    if [ "$DIR_NAME" != "$ACTIVE_FEAT" ]; then
      ORPHAN_FOUND=true
      warn "Orphaned spec directory: .claude/afc/specs/$DIR_NAME/" "rm -rf .claude/afc/specs/$DIR_NAME/"
    fi
  done <<< "$ORPHAN_DIRS"
  if [ "$ORPHAN_FOUND" = false ]; then
    pass "No orphaned artifacts"
  fi
else
  pass "No orphaned artifacts"
fi

# Safety tags
SAFETY_TAG=$(cd "$PROJECT_DIR" 2>/dev/null && git tag -l 'afc/pre-*' 2>/dev/null | head -1 || true)
if [ -n "$SAFETY_TAG" ]; then
  if ! afc_state_is_active; then
    warn "Lingering safety tag: $SAFETY_TAG" "git tag -d $SAFETY_TAG"
  else
    pass "Safety tag matches active pipeline"
  fi
else
  pass "No lingering safety tags"
fi

# Checkpoint
LOCAL_CP="$PROJECT_DIR/.claude/afc/memory/checkpoint.md"
if [ -f "$LOCAL_CP" ]; then
  CP_DATE=$(grep 'Auto-generated:' "$LOCAL_CP" 2>/dev/null | head -1 | sed 's/.*Auto-generated: //' || true)
  warn "Checkpoint from $CP_DATE" "run /afc:resume or delete .claude/afc/memory/checkpoint.md"
else
  pass "No stale checkpoint"
fi

# --- Category 6: Memory Health ---
section "Memory Health"

MEMORY_DIR="$PROJECT_DIR/.claude/afc/memory"
if [ -d "$MEMORY_DIR" ]; then
  check_dir_count() {
    local dir="$1" name="$2" threshold="$3"
    if [ -d "$dir" ]; then
      local count
      count=$(find "$dir" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
      if [ "$count" -le "$threshold" ]; then
        pass "$name: $count files"
      else
        warn "$name: $count files (threshold: $threshold)" "prune oldest files in $name/"
      fi
    fi
  }

  check_dir_count "$MEMORY_DIR/quality-history" "quality-history" 30
  check_dir_count "$MEMORY_DIR/reviews" "reviews" 40
  check_dir_count "$MEMORY_DIR/retrospectives" "retrospectives" 30
  check_dir_count "$MEMORY_DIR/research" "research" 50
  check_dir_count "$MEMORY_DIR/decisions" "decisions" 60

  # Agent memory sizes
  check_agent_memory() {
    local agent="$1" limit="$2"
    local mem_file="$PROJECT_DIR/.claude/agent-memory/$agent/MEMORY.md"
    if [ -f "$mem_file" ]; then
      local lines
      lines=$(wc -l < "$mem_file" | tr -d ' ')
      if [ "$lines" -le "$limit" ]; then
        pass "$agent MEMORY.md: $lines lines"
      else
        warn "$agent MEMORY.md: $lines lines (limit: $limit)" "invoke /afc:${agent#afc-} to trigger self-pruning"
      fi
    fi
  }

  check_agent_memory "afc-architect" 100
  check_agent_memory "afc-security" 100
else
  pass "No memory directory"
fi

# --- Category 7: Hook Health ---
section "Hook Health"

HOOKS_FILE="$PLUGIN_ROOT/hooks/hooks.json"
if [ -f "$HOOKS_FILE" ]; then
  HOOKS_VALID=false
  if command -v jq >/dev/null 2>&1; then
    if jq -e '.hooks' "$HOOKS_FILE" >/dev/null 2>&1; then
      HOOKS_VALID=true
    fi
  else
    if grep -q '"hooks"' "$HOOKS_FILE" 2>/dev/null; then
      HOOKS_VALID=true
    fi
  fi

  if [ "$HOOKS_VALID" = true ]; then
    pass "hooks.json valid"
  else
    fail "hooks.json invalid" "reinstall plugin: claude plugin install afc@all-for-claudecode"
  fi

  # Check all referenced scripts exist
  MISSING_SCRIPTS=""
  if command -v jq >/dev/null 2>&1; then
    while IFS= read -r cmd; do
      [ -z "$cmd" ] && continue
      # Extract script path from command string (strip quotes and CLAUDE_PLUGIN_ROOT)
      SCRIPT_PATH=$(printf '%s\n' "$cmd" | sed 's|"||g; s|\${CLAUDE_PLUGIN_ROOT}|'"$PLUGIN_ROOT"'|g' | awk '{print $1}')
      if [ ! -f "$SCRIPT_PATH" ]; then
        MISSING_SCRIPTS="${MISSING_SCRIPTS:+$MISSING_SCRIPTS, }$(basename "$SCRIPT_PATH")"
      fi
    done < <(jq -r '.. | objects | select(.command?) | .command' "$HOOKS_FILE" 2>/dev/null)
  fi

  if [ -z "$MISSING_SCRIPTS" ]; then
    pass "All hook scripts exist"
  else
    fail "Missing scripts: $MISSING_SCRIPTS" "reinstall plugin"
  fi

  # Check scripts executable
  NON_EXEC=""
  for script in "$PLUGIN_ROOT"/scripts/*.sh; do
    [ -f "$script" ] || continue
    if [ ! -x "$script" ]; then
      NON_EXEC="${NON_EXEC:+$NON_EXEC, }$(basename "$script")"
    fi
  done
  if [ -z "$NON_EXEC" ]; then
    pass "All scripts executable"
  else
    warn "Non-executable scripts: $NON_EXEC" "chmod +x on the listed scripts"
  fi
else
  fail "hooks.json not found" "reinstall plugin: claude plugin install afc@all-for-claudecode"
fi

# --- Category 8: Version Sync (dev only) ---
IS_DEV=false
if [ -f "$PROJECT_DIR/package.json" ]; then
  if command -v jq >/dev/null 2>&1; then
    PKG_NAME=$(jq -r '.name // empty' "$PROJECT_DIR/package.json" 2>/dev/null || true)
  else
    PKG_NAME=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROJECT_DIR/package.json" 2>/dev/null | head -1 | sed 's/.*: *"//;s/"//') || true
  fi
  if [ "$PKG_NAME" = "all-for-claudecode" ]; then
    IS_DEV=true
  fi
fi

if [ "$IS_DEV" = true ]; then
  section "Version Sync (dev)"

  # Read versions from all 3 files
  if command -v jq >/dev/null 2>&1; then
    V_PKG=$(jq -r '.version // empty' "$PROJECT_DIR/package.json" 2>/dev/null || true)
    V_PLUGIN=$(jq -r '.version // empty' "$PROJECT_DIR/.claude-plugin/plugin.json" 2>/dev/null || true)
    V_MKT_META=$(jq -r '.metadata.version // empty' "$PROJECT_DIR/.claude-plugin/marketplace.json" 2>/dev/null || true)
    V_MKT_PLUG=$(jq -r '.plugins[0].version // empty' "$PROJECT_DIR/.claude-plugin/marketplace.json" 2>/dev/null || true)
  else
    V_PKG=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROJECT_DIR/package.json" 2>/dev/null | head -1 | sed 's/.*: *"//;s/"//') || true
    V_PLUGIN=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROJECT_DIR/.claude-plugin/plugin.json" 2>/dev/null | head -1 | sed 's/.*: *"//;s/"//') || true
    V_MKT_META=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROJECT_DIR/.claude-plugin/marketplace.json" 2>/dev/null | head -1 | sed 's/.*: *"//;s/"//') || true
    V_MKT_PLUG=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROJECT_DIR/.claude-plugin/marketplace.json" 2>/dev/null | sed -n '2p' | sed 's/.*: *"//;s/"//') || true
  fi

  if [ "$V_PKG" = "$V_PLUGIN" ] && [ "$V_PKG" = "$V_MKT_META" ] && [ "$V_PKG" = "$V_MKT_PLUG" ]; then
    pass "Version triple match ($V_PKG)"
  else
    fail "Version mismatch — package.json: $V_PKG, plugin.json: $V_PLUGIN, marketplace meta: $V_MKT_META, marketplace plugin: $V_MKT_PLUG" "update mismatched files to the same version"
  fi

  # Cache sync check
  CACHE_DIR="$HOME/.claude/plugins/cache/all-for-claudecode/afc/$V_PKG"
  if [ -d "$CACHE_DIR" ]; then
    CACHE_AUTO="$CACHE_DIR/commands/auto.md"
    SOURCE_AUTO="$PROJECT_DIR/commands/auto.md"
    if [ -f "$CACHE_AUTO" ] && [ -f "$SOURCE_AUTO" ]; then
      if diff -q "$SOURCE_AUTO" "$CACHE_AUTO" >/dev/null 2>&1; then
        pass "Cache in sync"
      else
        warn "Plugin cache is stale" "npm run sync:cache"
      fi
    else
      warn "Cannot check cache sync (files missing)" "npm run sync:cache"
    fi
  else
    warn "Plugin cache directory not found" "install plugin first, then npm run sync:cache"
  fi
fi

# --- Summary ---
printf '\n'
printf '%s\n' "$(printf '\xe2\x94\x80%.0s' {1..25})"
printf 'Results: %d passed, %d warnings, %d failures\n' "$PASS" "$WARN" "$FAIL"

if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
  printf 'No issues found!\n'
elif [ "$FAIL" -eq 0 ]; then
  printf '%d warnings found. Non-blocking but review recommended.\n' "$WARN"
else
  printf '%d issues need attention. Run the Fix commands above.\n' "$FAIL"
fi

# Signal dev-only categories to caller
if [ "$IS_DEV" = true ]; then
  printf '\nNote: Categories 9-11 (Command/Agent/Doc validation) require LLM analysis.\n'
fi

exit 0
