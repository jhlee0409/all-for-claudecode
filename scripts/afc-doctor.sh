#!/bin/bash
set -euo pipefail

# afc-doctor.sh — Automated health check for all-for-claudecode plugin
# Runs ALL categories deterministically. No LLM judgment required.
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

# Project rules file
RULES_FILE="$PROJECT_DIR/.claude/rules/afc-project.md"
if [ -f "$RULES_FILE" ]; then
  if grep -q '<!-- afc:auto-generated' "$RULES_FILE" 2>/dev/null; then
    pass "Project rules file exists (auto-generated)"
  else
    pass "Project rules file exists (user-managed)"
  fi
else
  warn "No .claude/rules/afc-project.md — project rules not auto-loaded" "run /afc:init to generate"
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

# --- Category 8: Learner Health ---
section "Learner Health"

LEARNER_CONFIG="$PROJECT_DIR/.claude/afc/learner.json"
LEARNER_QUEUE="$PROJECT_DIR/.claude/.afc-learner-queue.jsonl"
LEARNER_RULES="$PROJECT_DIR/.claude/rules/afc-learned.md"

if [ -f "$LEARNER_CONFIG" ]; then
  pass "Learner enabled"

  # Queue size
  if [ -f "$LEARNER_QUEUE" ]; then
    LQ_COUNT=$(wc -l < "$LEARNER_QUEUE" | tr -d ' ')
    if [ "$LQ_COUNT" -le 30 ]; then
      pass "Signal queue: $LQ_COUNT entries"
    else
      warn "Signal queue large: $LQ_COUNT entries" "run /afc:learner to review pending patterns"
    fi
  else
    pass "Signal queue: empty"
  fi

  # Rule count
  if [ -f "$LEARNER_RULES" ]; then
    LR_COUNT=$(grep -c '<!-- afc:learned' "$LEARNER_RULES" 2>/dev/null || echo 0)
    if [ "$LR_COUNT" -le 30 ]; then
      pass "Learned rules: $LR_COUNT"
    else
      warn "Many learned rules: $LR_COUNT" "review and consolidate .claude/rules/afc-learned.md"
    fi
  else
    pass "No learned rules yet"
  fi
else
  pass "Learner not enabled (opt-in via /afc:learner enable)"
fi

# --- Category 9: Version Sync (dev only) ---
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

  # --- Category 10: Command Definitions (dev only) ---
  section "Command Definitions (dev)"

  CMD_DIR="$PROJECT_DIR/commands"
  if [ -d "$CMD_DIR" ]; then
    CMD_COUNT=0
    CMD_FM_MISSING=""
    CMD_FIELD_MISSING=""
    CMD_NAME_MISMATCH=""
    CMD_AGENT_MISSING=""

    for cmd_file in "$CMD_DIR"/*.md; do
      [ -f "$cmd_file" ] || continue
      CMD_COUNT=$((CMD_COUNT + 1))
      BASENAME=$(basename "$cmd_file" .md)

      # Check frontmatter exists (--- ... ---)
      if ! head -1 "$cmd_file" | grep -q '^---' 2>/dev/null; then
        CMD_FM_MISSING="${CMD_FM_MISSING:+$CMD_FM_MISSING, }$BASENAME"
        continue
      fi

      # Extract frontmatter (between first and second ---)
      FM=$(sed -n '2,/^---$/p' "$cmd_file" 2>/dev/null | sed '$d')

      # Check required fields: name and description
      if ! printf '%s\n' "$FM" | grep -q '^name:' 2>/dev/null || ! printf '%s\n' "$FM" | grep -q '^description:' 2>/dev/null; then
        CMD_FIELD_MISSING="${CMD_FIELD_MISSING:+$CMD_FIELD_MISSING, }$BASENAME"
      fi

      # Check name-filename match (afc:{basename})
      FM_NAME=$(printf '%s\n' "$FM" | grep '^name:' | head -1 | sed 's/name:[[:space:]]*//' | tr -d '"' | tr -d "'" | tr -d ' ')
      EXPECTED_NAME="afc:$BASENAME"
      if [ -n "$FM_NAME" ] && [ "$FM_NAME" != "$EXPECTED_NAME" ]; then
        CMD_NAME_MISMATCH="${CMD_NAME_MISMATCH:+$CMD_NAME_MISMATCH, }$BASENAME (got $FM_NAME)"
      fi

      # Check fork-agent reference
      if printf '%s\n' "$FM" | grep -q 'context:.*fork' 2>/dev/null; then
        AGENT_NAME=$(printf '%s\n' "$FM" | grep '^agent:' | head -1 | sed 's/agent:[[:space:]]*//' | tr -d '"' | tr -d "'" | tr -d ' ' || true)
        if [ -n "$AGENT_NAME" ] && [ ! -f "$PROJECT_DIR/agents/$AGENT_NAME.md" ]; then
          CMD_AGENT_MISSING="${CMD_AGENT_MISSING:+$CMD_AGENT_MISSING, }$BASENAME → $AGENT_NAME"
        fi
      fi
    done

    if [ -z "$CMD_FM_MISSING" ]; then
      pass "Frontmatter exists ($CMD_COUNT files)"
    else
      fail "Missing frontmatter: $CMD_FM_MISSING" "add YAML frontmatter block"
    fi

    if [ -z "$CMD_FIELD_MISSING" ]; then
      pass "Required fields present"
    else
      fail "Missing name/description: $CMD_FIELD_MISSING" "add missing fields"
    fi

    if [ -z "$CMD_NAME_MISMATCH" ]; then
      pass "Name-filename match"
    else
      fail "Name mismatch: $CMD_NAME_MISMATCH" "rename name: field to afc:{filename}"
    fi

    if [ -z "$CMD_AGENT_MISSING" ]; then
      pass "Fork-agent references valid"
    else
      fail "Missing agent: $CMD_AGENT_MISSING" "create missing agent file or fix agent: field"
    fi
  fi

  # --- Category 11: Agent Definitions (dev only) ---
  section "Agent Definitions (dev)"

  AGENT_DIR="$PROJECT_DIR/agents"
  if [ -d "$AGENT_DIR" ]; then
    AGENT_COUNT=0
    AGENT_FM_MISSING=""
    AGENT_FIELD_MISSING=""
    AGENT_NAME_MISMATCH=""
    EXPERT_MEMORY_MISSING=""
    WORKER_TURNS_MISSING=""

    EXPERT_AGENTS="afc-backend-expert afc-infra-expert afc-pm-expert afc-design-expert afc-marketing-expert afc-legal-expert afc-appsec-expert afc-tech-advisor"
    WORKER_AGENTS="afc-impl-worker afc-pr-analyst"

    for agent_file in "$AGENT_DIR"/*.md; do
      [ -f "$agent_file" ] || continue
      AGENT_COUNT=$((AGENT_COUNT + 1))
      BASENAME=$(basename "$agent_file" .md)

      # Check frontmatter exists
      if ! head -1 "$agent_file" | grep -q '^---' 2>/dev/null; then
        AGENT_FM_MISSING="${AGENT_FM_MISSING:+$AGENT_FM_MISSING, }$BASENAME"
        continue
      fi

      FM=$(sed -n '2,/^---$/p' "$agent_file" 2>/dev/null | sed '$d')

      # Check required fields: name, description, model
      if ! printf '%s\n' "$FM" | grep -q '^name:' 2>/dev/null || ! printf '%s\n' "$FM" | grep -q '^description:' 2>/dev/null || ! printf '%s\n' "$FM" | grep -q '^model:' 2>/dev/null; then
        AGENT_FIELD_MISSING="${AGENT_FIELD_MISSING:+$AGENT_FIELD_MISSING, }$BASENAME"
      fi

      # Check name-filename match
      FM_NAME=$(printf '%s\n' "$FM" | grep '^name:' | head -1 | sed 's/name:[[:space:]]*//' | tr -d '"' | tr -d "'" | tr -d ' ')
      if [ -n "$FM_NAME" ] && [ "$FM_NAME" != "$BASENAME" ]; then
        AGENT_NAME_MISMATCH="${AGENT_NAME_MISMATCH:+$AGENT_NAME_MISMATCH, }$BASENAME (got $FM_NAME)"
      fi

      # Expert memory check
      for expert in $EXPERT_AGENTS; do
        if [ "$BASENAME" = "$expert" ]; then
          if ! printf '%s\n' "$FM" | grep -q '^memory:' 2>/dev/null; then
            EXPERT_MEMORY_MISSING="${EXPERT_MEMORY_MISSING:+$EXPERT_MEMORY_MISSING, }$BASENAME"
          fi
        fi
      done

      # Worker maxTurns check
      for worker in $WORKER_AGENTS; do
        if [ "$BASENAME" = "$worker" ]; then
          if ! printf '%s\n' "$FM" | grep -q '^maxTurns:' 2>/dev/null; then
            WORKER_TURNS_MISSING="${WORKER_TURNS_MISSING:+$WORKER_TURNS_MISSING, }$BASENAME"
          fi
        fi
      done
    done

    if [ -z "$AGENT_FM_MISSING" ]; then
      pass "Frontmatter exists ($AGENT_COUNT files)"
    else
      fail "Missing frontmatter: $AGENT_FM_MISSING" "add YAML frontmatter block"
    fi

    if [ -z "$AGENT_FIELD_MISSING" ]; then
      pass "Required fields present"
    else
      fail "Missing name/description/model: $AGENT_FIELD_MISSING" "add missing fields"
    fi

    if [ -z "$AGENT_NAME_MISMATCH" ]; then
      pass "Name-filename match"
    else
      fail "Name mismatch: $AGENT_NAME_MISMATCH" "rename name: field to match filename"
    fi

    # Count experts found
    EXPERT_TOTAL=0
    EXPERT_WITH_MEM=0
    for expert in $EXPERT_AGENTS; do
      if [ -f "$AGENT_DIR/$expert.md" ]; then
        EXPERT_TOTAL=$((EXPERT_TOTAL + 1))
        FM=$(sed -n '2,/^---$/p' "$AGENT_DIR/$expert.md" 2>/dev/null | sed '$d')
        if printf '%s\n' "$FM" | grep -q '^memory:' 2>/dev/null; then
          EXPERT_WITH_MEM=$((EXPERT_WITH_MEM + 1))
        fi
      fi
    done
    if [ -z "$EXPERT_MEMORY_MISSING" ]; then
      pass "Expert memory configured ($EXPERT_WITH_MEM/$EXPERT_TOTAL)"
    else
      fail "Missing memory: field: $EXPERT_MEMORY_MISSING" "add memory: project to agent frontmatter"
    fi

    WORKER_TOTAL=0
    WORKER_WITH_TURNS=0
    for worker in $WORKER_AGENTS; do
      if [ -f "$AGENT_DIR/$worker.md" ]; then
        WORKER_TOTAL=$((WORKER_TOTAL + 1))
        FM=$(sed -n '2,/^---$/p' "$AGENT_DIR/$worker.md" 2>/dev/null | sed '$d')
        if printf '%s\n' "$FM" | grep -q '^maxTurns:' 2>/dev/null; then
          WORKER_WITH_TURNS=$((WORKER_WITH_TURNS + 1))
        fi
      fi
    done
    if [ -z "$WORKER_TURNS_MISSING" ]; then
      pass "Worker maxTurns configured ($WORKER_WITH_TURNS/$WORKER_TOTAL)"
    else
      fail "Missing maxTurns: $WORKER_TURNS_MISSING" "add maxTurns: to agent frontmatter"
    fi
  fi

  # --- Category 12: Doc References (dev only) ---
  section "Doc References (dev)"

  # Scan commands and agents for docs/ references
  DOC_REFS_MISSING=""
  for src_file in "$CMD_DIR"/*.md "$AGENT_DIR"/*.md; do
    [ -f "$src_file" ] || continue
    while IFS= read -r ref; do
      [ -z "$ref" ] && continue
      DOC_PATH="$PROJECT_DIR/$ref"
      if [ ! -f "$DOC_PATH" ]; then
        DOC_REFS_MISSING="${DOC_REFS_MISSING:+$DOC_REFS_MISSING, }$ref (in $(basename "$src_file"))"
      fi
    done < <(grep -oE 'docs/[a-zA-Z0-9_/-]+\.md' "$src_file" 2>/dev/null | sort -u)
  done

  if [ -z "$DOC_REFS_MISSING" ]; then
    pass "Referenced docs exist"
  else
    fail "Missing docs: $DOC_REFS_MISSING" "create missing doc files or fix references"
  fi

  # Domain adapters
  ADAPTER_DIR="$PROJECT_DIR/docs/domain-adapters"
  if [ -d "$ADAPTER_DIR" ]; then
    ADAPTER_COUNT=$(find "$ADAPTER_DIR" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$ADAPTER_COUNT" -ge 1 ]; then
      pass "Domain adapters exist ($ADAPTER_COUNT files)"
    else
      fail "No domain adapter files" "add .md files to docs/domain-adapters/"
    fi
  else
    fail "docs/domain-adapters/ directory missing" "create docs/domain-adapters/ with at least one .md file"
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


exit 0
