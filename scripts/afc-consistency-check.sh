#!/bin/bash
set -euo pipefail

# afc-consistency-check.sh — Cross-reference validation for project consistency
# Checks: config placeholders, agent names, hook scripts, test coverage, command docs
# Run as part of: npm run lint

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ERRORS=0
WARNINGS=0

# --- Helpers ---

fail() {
  printf "[afc:consistency] FAIL: %s\n" "$1" >&2
  ERRORS=$((ERRORS + 1))
}

warn() {
  printf "[afc:consistency] WARN: %s\n" "$1" >&2
  WARNINGS=$((WARNINGS + 1))
}

ok() {
  printf "[afc:consistency] ✓ %s\n" "$1"
}

# Extract a field value from command file YAML frontmatter
get_cmd_field() {
  local file="$1" field="$2"
  awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$file" \
    | grep "^${field}:" \
    | sed "s/^${field}:[[:space:]]*//" \
    | tr -d '"' | head -1 || true
}

# --- Check 1: Config Placeholder Validation ---
# Verify all {config.*} references in skills/ and docs/ map to known config keys

check_config_placeholders() {
  local template="$PROJECT_DIR/templates/afc.config.template.md"
  if [ ! -f "$template" ]; then
    warn "Config template not found: $template"
    return
  fi

  # Extract valid config keys from template
  # YAML keys: ci, gate, test
  local yaml_keys
  yaml_keys=$(grep -oE '^\s*[a-z_]+:' "$template" 2>/dev/null | sed 's/[[:space:]]*//;s/://' | sort -u || true)
  # Section headers → lowercase with underscores: Architecture → architecture, Code Style → code_style, Project Context → project_context
  local section_keys
  section_keys=$(grep -oE '^## [A-Za-z ]+' "$template" 2>/dev/null \
    | sed 's/^## //' \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/ /_/g' \
    | sort -u || true)

  local valid_keys
  valid_keys=$(printf '%s\n%s\n' "$yaml_keys" "$section_keys" | sort -u)

  # Extract all {config.*} references from skills and docs
  local refs
  refs=$(grep -rohE '\{config\.[a-z_]+\}' "$PROJECT_DIR/skills/" "$PROJECT_DIR/docs/" 2>/dev/null \
    | sed 's/{config\.//;s/}//' \
    | sort -u || true)

  local count=0
  local invalid=0
  for ref in $refs; do
    count=$((count + 1))
    if ! printf '%s\n' "$valid_keys" | grep -qxF "$ref"; then
      fail "{config.$ref} referenced but not defined in config template"
      invalid=$((invalid + 1))
    fi
  done

  if [ "$invalid" -eq 0 ]; then
    ok "Config placeholders: $count references, all valid"
  fi
}

# --- Check 2: Agent Name Consistency ---
# Verify subagent_type references in commands match agent definitions

check_agent_names() {
  local agents_dir="$PROJECT_DIR/agents"
  if [ ! -d "$agents_dir" ]; then
    warn "Agents directory not found"
    return
  fi

  # Extract agent names from agent files (name: field in frontmatter)
  local defined_agents
  defined_agents=$(grep -h '^name:' "$agents_dir"/*.md 2>/dev/null \
    | sed 's/^name:[[:space:]]*//' \
    | tr -d '"' \
    | sort -u || true)

  # Extract subagent_type references from skills (afc:agent-name pattern)
  local referenced_agents
  referenced_agents=$(grep -rohE 'subagent_type:[[:space:]]*"afc:[^"]*"' "$PROJECT_DIR/skills/" 2>/dev/null \
    | sed 's/.*"afc://;s/"//' \
    | sort -u || true)

  local count=0
  local invalid=0
  for ref in $referenced_agents; do
    # Skip dynamic template patterns (e.g., afc-{domain}-expert)
    case "$ref" in *"{"*) continue ;; esac
    count=$((count + 1))
    if ! printf '%s\n' "$defined_agents" | grep -qxF "$ref"; then
      fail "subagent_type 'afc:$ref' referenced but no agents/$ref.md found"
      invalid=$((invalid + 1))
    fi
  done

  # Check for unprefixed subagent_type that should have afc: prefix
  local unprefixed
  unprefixed=$(grep -rohE 'subagent_type:[[:space:]]*"afc-[^"]*"' "$PROJECT_DIR/skills/" 2>/dev/null \
    | sed 's/.*subagent_type:[[:space:]]*"//;s/".*//' \
    | sort -u || true)
  for ref in $unprefixed; do
    if printf '%s\n' "$defined_agents" | grep -qxF "$ref"; then
      fail "subagent_type '$ref' should use 'afc:$ref' prefix (found in agents/)"
      invalid=$((invalid + 1))
    fi
  done

  if [ "$invalid" -eq 0 ]; then
    ok "Agent names: $count references, all consistent"
  fi
}

# --- Check 3: Hook Script Existence ---
# Verify all scripts referenced in hooks.json actually exist

check_hook_scripts() {
  local hooks_file="$PROJECT_DIR/hooks/hooks.json"
  if [ ! -f "$hooks_file" ]; then
    warn "hooks.json not found"
    return
  fi

  local scripts
  scripts=$(grep -oE 'scripts/[^"]+\.sh' "$hooks_file" 2>/dev/null | sort -u || true)

  local count=0
  local missing=0
  for script in $scripts; do
    count=$((count + 1))
    if [ ! -f "$PROJECT_DIR/$script" ]; then
      fail "hooks.json references '$script' but file not found"
      missing=$((missing + 1))
    fi
  done

  if [ "$missing" -eq 0 ]; then
    ok "Hook scripts: $count references, all exist"
  fi
}

# --- Check 4: Test Coverage ---
# Verify each afc-*.sh script (except afc-state.sh library) has a spec file

check_test_coverage() {
  local count=0
  local missing=0
  for script in "$PROJECT_DIR"/scripts/afc-*.sh; do
    local scriptname
    scriptname=$(basename "$script" .sh)
    # Skip shared library and self (validation script)
    if [ "$scriptname" = "afc-state" ] || [ "$scriptname" = "afc-consistency-check" ]; then
      continue
    fi
    count=$((count + 1))
    if [ ! -f "$PROJECT_DIR/spec/${scriptname}_spec.sh" ]; then
      fail "scripts/$scriptname.sh has no spec/${scriptname}_spec.sh"
      missing=$((missing + 1))
    fi
  done

  if [ "$missing" -eq 0 ]; then
    ok "Test coverage: $count scripts, all have specs"
  fi
}

# --- Check 5: Version Sync ---
# Verify version numbers match across package.json, plugin.json, marketplace.json

check_version_sync() {
  local pkg="$PROJECT_DIR/package.json"
  local plugin="$PROJECT_DIR/.claude-plugin/plugin.json"
  local market="$PROJECT_DIR/.claude-plugin/marketplace.json"

  if [ ! -f "$pkg" ] || [ ! -f "$plugin" ] || [ ! -f "$market" ]; then
    warn "One or more version files missing"
    return
  fi

  local pkg_ver plugin_ver market_meta market_plugin
  if command -v jq >/dev/null 2>&1; then
    pkg_ver=$(jq -r '.version' "$pkg")
    plugin_ver=$(jq -r '.version' "$plugin")
    market_meta=$(jq -r '.metadata.version' "$market")
    market_plugin=$(jq -r '.plugins[0].version' "$market")
  else
    pkg_ver=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$pkg" | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"//;s/"//')
    plugin_ver=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$plugin" | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"//;s/"//')
    # Extract metadata.version (appears after "metadata" key) and plugins[].version (appears after "plugins" key)
    # Use awk to track context instead of relying on field ordering
    market_meta=$(awk '/"metadata"/{found=1} found && /"version"/{gsub(/.*"version"[[:space:]]*:[[:space:]]*"/,""); gsub(/".*/,""); print; exit}' "$market" 2>/dev/null || true)
    market_plugin=$(awk '/"plugins"/{found=1} found && /"version"/{gsub(/.*"version"[[:space:]]*:[[:space:]]*"/,""); gsub(/".*/,""); print; exit}' "$market" 2>/dev/null || true)
  fi

  if [ "$pkg_ver" = "$plugin_ver" ] && [ "$plugin_ver" = "$market_meta" ] && [ "$market_meta" = "$market_plugin" ]; then
    ok "Version sync: $pkg_ver (all 4 match)"
  else
    fail "Version mismatch: package.json=$pkg_ver plugin.json=$plugin_ver marketplace.meta=$market_meta marketplace.plugin=$market_plugin"
  fi
}

# --- Check 6: SSOT Phase Constants ---
# Verify SSOT phase list in afc-state.sh is not duplicated in other scripts

check_phase_ssot() {
  # shellcheck source=afc-state.sh
  . "$SCRIPT_DIR/afc-state.sh"

  local issues=0

  # Sub-check A: No hardcoded phase lists in other scripts
  for script in "$PROJECT_DIR"/scripts/afc-*.sh; do
    local scriptname
    scriptname=$(basename "$script")
    # Skip the SSOT source itself and this validation script
    if [ "$scriptname" = "afc-state.sh" ] || [ "$scriptname" = "afc-consistency-check.sh" ]; then
      continue
    fi
    # Check for hardcoded phase case patterns (spec|plan|...|clean style)
    if grep -qE 'spec\|plan\|.*\|clean' "$script" 2>/dev/null; then
      fail "$scriptname contains hardcoded phase list — use SSOT helpers from afc-state.sh"
      issues=$((issues + 1))
    fi
  done

  if [ "$issues" -eq 0 ]; then
    ok "Phase SSOT: no hardcoded phase lists in scripts"
  fi
}

# --- Check 7: Skill Documentation Cross-Reference ---
# Verify skills are documented in README.md, init/SKILL.md, and CLAUDE.md

check_command_docs() {
  local skills_dir="$PROJECT_DIR/skills"
  [ -d "$skills_dir" ] || return

  local readme="$PROJECT_DIR/README.md"
  local init_skill="$skills_dir/init/SKILL.md"
  local claude_md="$PROJECT_DIR/CLAUDE.md"
  local issues=0

  for skill_file in "$skills_dir"/*/SKILL.md; do
    [ -f "$skill_file" ] || continue
    local cmd_name
    cmd_name=$(basename "$(dirname "$skill_file")")

    # Sub-check A: README.md should mention /afc:{name}
    if [ -f "$readme" ]; then
      if ! grep -qE "/afc:${cmd_name}([^a-z0-9-]|$)" "$readme" 2>/dev/null; then
        warn "Command '$cmd_name' missing from README.md command table"
        issues=$((issues + 1))
      fi
    fi

    # Sub-check B: init/SKILL.md should mention afc:{name} for user-invocable skills
    local invocable
    invocable=$(get_cmd_field "$skill_file" "user-invocable")
    if [ "$invocable" != "false" ] && [ -f "$init_skill" ]; then
      if ! grep -qE "afc:${cmd_name}([^a-z0-9-]|$)" "$init_skill" 2>/dev/null; then
        warn "Skill '$cmd_name' missing from init/SKILL.md skill routing"
        issues=$((issues + 1))
      fi
    fi

    # Sub-check C: CLAUDE.md fork list for context:fork skills
    local ctx
    ctx=$(get_cmd_field "$skill_file" "context")
    if [ "$ctx" = "fork" ] && [ -f "$claude_md" ]; then
      if ! grep "context: fork" "$claude_md" 2>/dev/null | grep -qE "([(, ])${cmd_name}([,) ]|$)"; then
        warn "Skill '$cmd_name' (context:fork) missing from CLAUDE.md fork list"
        issues=$((issues + 1))
      fi
    fi
  done

  if [ "$issues" -eq 0 ]; then
    ok "Skill docs: all skills referenced in README.md, init/SKILL.md, CLAUDE.md"
  fi
}

# --- Run All Checks ---

printf "[afc:consistency] Running cross-reference validation...\n"

check_config_placeholders
check_agent_names
check_hook_scripts
check_test_coverage
check_version_sync
check_phase_ssot
check_command_docs

printf "\n[afc:consistency] Done: %d errors, %d warnings\n" "$ERRORS" "$WARNINGS"

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi
exit 0
