#!/bin/bash
set -euo pipefail

# afc-consistency-check.sh — Cross-reference validation for project consistency
# Checks: config placeholders, agent names, hook scripts, test coverage
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

# --- Check 1: Config Placeholder Validation ---
# Verify all {config.*} references in commands/ and docs/ map to known config keys

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

  # Extract all {config.*} references from commands and docs
  local refs
  refs=$(grep -rohE '\{config\.[a-z_]+\}' "$PROJECT_DIR/commands/" "$PROJECT_DIR/docs/" 2>/dev/null \
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

  # Extract subagent_type references from commands (afc:agent-name pattern)
  local referenced_agents
  referenced_agents=$(grep -rohE 'subagent_type:[[:space:]]*"afc:[^"]*"' "$PROJECT_DIR/commands/" 2>/dev/null \
    | sed 's/.*"afc://;s/"//' \
    | sort -u || true)

  local count=0
  local invalid=0
  for ref in $referenced_agents; do
    count=$((count + 1))
    if ! printf '%s\n' "$defined_agents" | grep -qxF "$ref"; then
      fail "subagent_type 'afc:$ref' referenced but no agents/$ref.md found"
      invalid=$((invalid + 1))
    fi
  done

  # Check for unprefixed subagent_type that should have afc: prefix
  local unprefixed
  unprefixed=$(grep -rohE 'subagent_type:[[:space:]]*"afc-[^"]*"' "$PROJECT_DIR/commands/" 2>/dev/null \
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
    market_meta=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$market" | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"//;s/"//')
    market_plugin=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$market" | sed -n '2p' | sed 's/.*"version"[[:space:]]*:[[:space:]]*"//;s/"//')
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

  # Sub-check B: Every command name should map to a valid phase or be a known non-phase command
  # Non-phase commands that are not pipeline phases
  # NOTE: Update this list when adding non-phase commands to commands/
  local non_phase_cmds="auto|init|doctor|principles|checkpoint|resume|launch|ideate|research|architect|security|debug|analyze|test"
  local commands_dir="$PROJECT_DIR/commands"
  if [ -d "$commands_dir" ]; then
    for cmd_file in "$commands_dir"/*.md; do
      [ -f "$cmd_file" ] || continue
      local cmd_name
      cmd_name=$(basename "$cmd_file" .md)
      # Skip known non-phase commands
      if printf '%s\n' "$non_phase_cmds" | tr '|' '\n' | grep -qxF "$cmd_name"; then
        continue
      fi
      # Remaining commands should correspond to a valid phase
      if ! afc_is_valid_phase "$cmd_name"; then
        warn "Command '$cmd_name' is not a recognized phase in AFC_VALID_PHASES and not in non-phase list"
        issues=$((issues + 1))
      fi
    done
  fi

  if [ "$issues" -eq 0 ]; then
    ok "Phase SSOT: no hardcoded lists, all commands map to valid phases"
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

printf "\n[afc:consistency] Done: %d errors, %d warnings\n" "$ERRORS" "$WARNINGS"

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi
exit 0
