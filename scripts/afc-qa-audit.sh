#!/bin/bash
set -euo pipefail

# afc-qa-audit.sh — QA audit: detect quality gaps between structure and runtime behavior
# Checks: hook I/O safety, test strength, UX completeness, build/deploy integrity
# Run as part of: npm run qa

# shellcheck disable=SC2329
cleanup() {
  :
}
trap cleanup EXIT

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"
ERRORS=0
WARNINGS=0
PASSES=0

# --- Helpers ---

fail() {
  printf "  ✗ %s\n" "$1" >&2
  ERRORS=$((ERRORS + 1))
}

warn() {
  printf "  ⚠ %s\n" "$1"
  WARNINGS=$((WARNINGS + 1))
}

ok() {
  printf "  ✓ %s\n" "$1"
  PASSES=$((PASSES + 1))
}

# --- Category A: Hook I/O Safety ---

check_a_hook_io_safety() {
  printf "\nCategory A: Hook I/O Safety\n"
  check_a1_stdin_consumption
  check_a2_stdout_json_templates
  check_a3_failure_hint_coverage
}

# A1: stdin must be consumed before any early exit in command hooks
check_a1_stdin_consumption() {
  local hooks_file="$PROJECT_DIR/hooks/hooks.json"
  if [ ! -f "$hooks_file" ]; then
    warn "hooks.json not found, skipping A1"
    return
  fi

  # Extract command hook scripts from hooks.json
  local scripts
  scripts=$(grep -oE 'scripts/[^"]+\.sh' "$hooks_file" 2>/dev/null | sort -u || true)

  local count=0
  local issues=0
  for script_path in $scripts; do
    local full_path="$PROJECT_DIR/$script_path"
    [ -f "$full_path" ] || continue
    count=$((count + 1))

    # Check: does the script consume stdin (cat, INPUT=$(cat), cat > /dev/null, read)?
    if ! grep -qE '^\s*(INPUT=\$\(cat|cat\b|cat >|read )' "$full_path" 2>/dev/null; then
      fail "stdin not consumed: $script_path (SIGPIPE risk)"
      issues=$((issues + 1))
      continue
    fi

    # Check: is there an exit/return before stdin consumption?
    local stdin_line exit_line
    stdin_line=$(grep -nE '^\s*(INPUT=\$\(cat|cat\b|cat >)' "$full_path" 2>/dev/null | head -1 | cut -d: -f1 || echo 999)
    exit_line=$(grep -nE '^\s*(exit [0-9]|return [0-9])' "$full_path" 2>/dev/null | head -1 | cut -d: -f1 || echo 999)

    # Skip if exit is in cleanup() function (lines before trap)
    local trap_line
    trap_line=$(grep -nE '^\s*trap ' "$full_path" 2>/dev/null | head -1 | cut -d: -f1 || echo 0)
    if [ "$exit_line" -lt "$trap_line" ] 2>/dev/null; then
      # exit is inside cleanup function, not a real early exit
      exit_line=999
    fi

    if [ "$exit_line" -lt "$stdin_line" ] 2>/dev/null; then
      fail "exit before stdin consumption: $script_path (line $exit_line exits before stdin at line $stdin_line)"
      issues=$((issues + 1))
    fi
  done

  if [ "$issues" -eq 0 ]; then
    ok "stdin consumption: $count hook scripts, all consume before exit"
  fi
}

# A2: stdout JSON templates with hookSpecificOutput must be valid JSON
check_a2_stdout_json_templates() {
  local scripts_dir="$PROJECT_DIR/scripts"
  [ -d "$scripts_dir" ] || return

  local count=0
  local issues=0

  for script in "$scripts_dir"/*.sh; do
    [ -f "$script" ] || continue
    local scriptname
    scriptname=$(basename "$script")

    # Extract printf patterns with hookSpecificOutput
    local templates
    templates=$(grep -oE "printf '[^']*hookSpecificOutput[^']*'" "$script" 2>/dev/null || true)
    [ -z "$templates" ] && continue

    while IFS= read -r tmpl; do
      count=$((count + 1))
      # Extract the format string (between single quotes)
      local fmt
      fmt=$(printf '%s' "$tmpl" | sed "s/^printf '//;s/'$//" || true)
      # Replace %s with dummy string
      local json
      json=$(printf '%s' "$fmt" | sed 's/%s/dummy/g; s/\\n//g' || true)
      # Validate JSON
      if command -v jq >/dev/null 2>&1; then
        if ! printf '%s' "$json" | jq . >/dev/null 2>&1; then
          fail "invalid JSON template in $scriptname: $fmt"
          issues=$((issues + 1))
        fi
      fi
    done <<< "$templates"
  done

  if [ "$issues" -eq 0 ]; then
    ok "stdout JSON templates: $count valid"
  fi
}

# A3: failure-hint case patterns vs spec test coverage
check_a3_failure_hint_coverage() {
  local hint_script="$PROJECT_DIR/scripts/afc-failure-hint.sh"
  local hint_spec="$PROJECT_DIR/spec/afc-failure-hint_spec.sh"

  if [ ! -f "$hint_script" ] || [ ! -f "$hint_spec" ]; then
    warn "failure-hint script or spec not found, skipping A3"
    return
  fi

  # Count case patterns (excluding *) and wildcard)
  local pattern_count
  pattern_count=$(grep -cE '^\s+\*.*\*\)' "$hint_script" 2>/dev/null || echo 0)
  # Subtract the catch-all *)
  local catchall
  catchall=$(grep -cE '^\s+\*\)' "$hint_script" 2>/dev/null || echo 0)
  pattern_count=$((pattern_count - catchall))

  # Count test contexts in spec
  local test_count
  test_count=$(grep -cE '^\s+Context ' "$hint_spec" 2>/dev/null || echo 0)

  if [ "$test_count" -ge "$pattern_count" ]; then
    ok "failure-hint patterns: $pattern_count patterns, $test_count tests"
  else
    warn "failure-hint coverage gap: $pattern_count patterns but only $test_count tests"
  fi
}

# --- Category B: Test Strength ---

check_b_test_strength() {
  printf "\nCategory B: Test Strength\n"
  check_b1_assertion_density
  check_b2_state_mutation_tests
  check_b3_case_pattern_coverage
  check_b4_empty_stdin_edge
}

# B1: assertion density (The lines per It block)
check_b1_assertion_density() {
  local spec_dir="$PROJECT_DIR/spec"
  [ -d "$spec_dir" ] || return

  local low_density=""
  local checked=0

  for spec in "$spec_dir"/*_spec.sh; do
    [ -f "$spec" ] || continue
    local specname
    specname=$(basename "$spec")
    checked=$((checked + 1))

    local it_count assertion_count
    it_count=$(grep -cE '^\s+It ' "$spec" 2>/dev/null || echo 0)
    assertion_count=$(grep -cE '^\s+The ' "$spec" 2>/dev/null || echo 0)

    [ "$it_count" -eq 0 ] && continue

    # Calculate ratio (integer arithmetic: multiply by 10 for one decimal)
    local ratio_x10
    ratio_x10=$(( (assertion_count * 10) / it_count ))

    if [ "$ratio_x10" -lt 10 ]; then
      fail "low assertion density: $specname (${assertion_count}/${it_count} = $(( ratio_x10 / 10 )).$(( ratio_x10 % 10 )))"
    elif [ "$ratio_x10" -lt 15 ]; then
      low_density="${low_density:+$low_density, }$specname ($(( ratio_x10 / 10 )).$(( ratio_x10 % 10 )))"
    fi
  done

  if [ -n "$low_density" ]; then
    warn "low assertion density: $low_density"
  elif [ "$checked" -gt 0 ]; then
    ok "assertion density: $checked specs checked, all >= 1.5"
  fi
}

# B2: state mutation tests must assert file contents
check_b2_state_mutation_tests() {
  local spec_dir="$PROJECT_DIR/spec"
  [ -d "$spec_dir" ] || return

  local issues=0
  local checked=0

  for spec in "$spec_dir"/*_spec.sh; do
    [ -f "$spec" ] || continue

    # Find specs that call state-changing functions
    if grep -qE 'afc_state_write|setup_state_fixture|afc-state\.json' "$spec" 2>/dev/null; then
      checked=$((checked + 1))
      # Check if they assert file contents
      if ! grep -qE 'contents of file|should include|should eq' "$spec" 2>/dev/null; then
        fail "state mutation without content assertion: $(basename "$spec")"
        issues=$((issues + 1))
      fi
    fi
  done

  if [ "$issues" -eq 0 ] && [ "$checked" -gt 0 ]; then
    ok "state mutation tests: $checked specs, all have content assertions"
  fi
}

# B3: case pattern test coverage in scripts
check_b3_case_pattern_coverage() {
  local scripts_dir="$PROJECT_DIR/scripts"
  local spec_dir="$PROJECT_DIR/spec"
  [ -d "$scripts_dir" ] && [ -d "$spec_dir" ] || return

  local issues=0
  local checked=0

  for script in "$scripts_dir"/afc-*.sh; do
    [ -f "$script" ] || continue
    local scriptname
    scriptname=$(basename "$script" .sh)

    # Only check scripts with case "$ERROR" or case "$INPUT" patterns (hook error dispatch)
    if ! grep -qE 'case "\$ERROR|\$TOOL_NAME|\$NOTIFICATION_TYPE"' "$script" 2>/dev/null; then
      continue
    fi

    # Count case branch patterns (exclude catch-all *)
    local case_count
    case_count=$(grep -cE '^\s+\*[^)]+\)' "$script" 2>/dev/null | tr -d '[:space:]' || true)
    case_count="${case_count:-0}"
    [ "$case_count" -lt 2 ] && continue  # Skip trivial case blocks

    local spec_file="$spec_dir/${scriptname}_spec.sh"
    [ -f "$spec_file" ] || continue
    checked=$((checked + 1))

    # Count Data lines in spec (each represents a test case)
    local data_count
    data_count=$(grep -cE "^\s+Data " "$spec_file" 2>/dev/null | tr -d '[:space:]' || true)
    data_count="${data_count:-0}"

    if [ "$data_count" -lt "$case_count" ]; then
      warn "case coverage gap: $scriptname ($case_count branches, $data_count test inputs)"
    fi
  done

  if [ "$issues" -eq 0 ] && [ "$checked" -gt 0 ]; then
    ok "case pattern coverage: $checked scripts checked"
  fi
}

# B4: empty stdin edge case in hook specs
check_b4_empty_stdin_edge() {
  local hooks_file="$PROJECT_DIR/hooks/hooks.json"
  local spec_dir="$PROJECT_DIR/spec"
  [ -f "$hooks_file" ] && [ -d "$spec_dir" ] || return

  # Get hook scripts that receive stdin (command hooks)
  local scripts
  scripts=$(grep -oE 'scripts/[^"]+\.sh' "$hooks_file" 2>/dev/null | sort -u || true)

  local count=0
  local missing=""

  for script_path in $scripts; do
    local scriptname
    scriptname=$(basename "$script_path" .sh)
    local spec_file="$spec_dir/${scriptname}_spec.sh"
    [ -f "$spec_file" ] || continue
    count=$((count + 1))

    if ! grep -qE "Data ['\"]'" "$spec_file" 2>/dev/null && \
       ! grep -qE "Data ''" "$spec_file" 2>/dev/null && \
       ! grep -qE 'empty stdin' "$spec_file" 2>/dev/null; then
      missing="${missing:+$missing, }$scriptname"
    fi
  done

  if [ -n "$missing" ]; then
    warn "missing empty stdin test: $missing"
  elif [ "$count" -gt 0 ]; then
    ok "empty stdin edge cases: $count hook specs covered"
  fi
}

# --- Category C: UX Completeness ---

check_c_ux_completeness() {
  printf "\nCategory C: UX Completeness\n"
  check_c1_error_pattern_coverage
  check_c2_hook_response_consistency
}

# C1: failure-hint covers common error classes
check_c1_error_pattern_coverage() {
  local hint_script="$PROJECT_DIR/scripts/afc-failure-hint.sh"
  [ -f "$hint_script" ] || return

  # Essential error classes that should be handled
  local -a required_patterns=("EACCES" "ENOENT" "ECONNREFUSED" "command not found" "ENOMEM" "ETIMEDOUT" "ENOSPC" "syntax error" "FAILED")
  local missing=""
  local covered=0

  for pattern in "${required_patterns[@]}"; do
    if grep -qF "$pattern" "$hint_script" 2>/dev/null; then
      covered=$((covered + 1))
    else
      missing="${missing:+$missing, }$pattern"
    fi
  done

  if [ -n "$missing" ]; then
    warn "missing error patterns in failure-hint: $missing"
  else
    ok "error pattern coverage: ${#required_patterns[@]} common patterns covered"
  fi
}

# C2: same hook event type scripts use consistent JSON output format
check_c2_hook_response_consistency() {
  local hooks_file="$PROJECT_DIR/hooks/hooks.json"
  [ -f "$hooks_file" ] || return

  local issues=0

  # Helper: extract script paths for a given hook event using jq or grep fallback
  _scripts_for_event() {
    local event="$1"
    if command -v jq >/dev/null 2>&1; then
      jq -r ".hooks.\"$event\"[]?.hooks[]? | select(.type==\"command\") | .command" "$hooks_file" 2>/dev/null \
        | grep -oE 'scripts/[^"]+\.sh' || true
    else
      # Fallback: look for script paths near the event key
      # This is best-effort for jq-less environments
      grep -oE 'scripts/[^"]+\.sh' "$hooks_file" 2>/dev/null || true
    fi
  }

  # Check PreToolUse hooks all use permissionDecision format
  local pretool_scripts
  pretool_scripts=$(_scripts_for_event "PreToolUse")

  for script_path in $pretool_scripts; do
    local full_path="$PROJECT_DIR/$script_path"
    [ -f "$full_path" ] || continue
    if grep -q 'hookSpecificOutput' "$full_path" 2>/dev/null; then
      if ! grep -q 'permissionDecision' "$full_path" 2>/dev/null; then
        fail "PreToolUse hook $(basename "$script_path") uses wrong response format (expected permissionDecision)"
        issues=$((issues + 1))
      fi
    fi
  done

  # Check PostToolUse/PostToolUseFailure hooks all use additionalContext format
  local posttool_scripts
  posttool_scripts=$(_scripts_for_event "PostToolUse")
  posttool_scripts="$posttool_scripts
$(_scripts_for_event "PostToolUseFailure")"

  for script_path in $posttool_scripts; do
    [ -z "$script_path" ] && continue
    local full_path="$PROJECT_DIR/$script_path"
    [ -f "$full_path" ] || continue
    if grep -q 'hookSpecificOutput' "$full_path" 2>/dev/null; then
      if ! grep -q 'additionalContext' "$full_path" 2>/dev/null; then
        fail "PostToolUse hook $(basename "$script_path") uses wrong response format (expected additionalContext)"
        issues=$((issues + 1))
      fi
    fi
  done

  if [ "$issues" -eq 0 ]; then
    ok "hook response consistency: PreToolUse/PostToolUse formats correct"
  fi
}

# --- Category D: Build/Deploy Integrity ---

check_d_build_deploy() {
  printf "\nCategory D: Build/Deploy Integrity\n"
  check_d1_cache_divergence
  check_d2_script_permissions
  check_d3_zombie_state
}

# D1: source/cache file divergence (dev mode only)
check_d1_cache_divergence() {
  # Only check in dev mode (when package.json name is "all-for-claudecode")
  local pkg="$PROJECT_DIR/package.json"
  [ -f "$pkg" ] || return

  local pkg_name
  if command -v jq >/dev/null 2>&1; then
    pkg_name=$(jq -r '.name // empty' "$pkg" 2>/dev/null || true)
  else
    pkg_name=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$pkg" | sed 's/.*"name"[[:space:]]*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
  fi

  if [ "$pkg_name" != "all-for-claudecode" ]; then
    ok "cache check: skipped (not in dev mode)"
    return
  fi

  local cache_dir
  cache_dir="$HOME/.claude/plugins/cache/all-for-claudecode/afc"
  if [ ! -d "$cache_dir" ]; then
    ok "cache check: no cache directory found"
    return
  fi

  # Find the versioned cache directory
  local cache_version_dir
  cache_version_dir=$(find "$cache_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -1 || true)
  if [ -z "$cache_version_dir" ]; then
    ok "cache check: no versioned cache found"
    return
  fi

  local diverged=0
  local checked=0

  for subdir in commands scripts hooks; do
    local src_dir="$PROJECT_DIR/$subdir"
    local cache_subdir="$cache_version_dir/$subdir"
    [ -d "$src_dir" ] && [ -d "$cache_subdir" ] || continue

    local diff_output
    diff_output=$(diff -rq "$src_dir" "$cache_subdir" 2>/dev/null || true)
    if [ -n "$diff_output" ]; then
      local diff_count
      diff_count=$(printf '%s\n' "$diff_output" | wc -l | tr -d ' ')
      diverged=$((diverged + diff_count))
      checked=$((checked + 1))
    fi
  done

  if [ "$diverged" -gt 0 ]; then
    warn "cache divergence: $diverged files differ (run npm run sync:cache)"
  else
    ok "cache sync: source and cache match"
  fi
}

# D2: script execution permissions
check_d2_script_permissions() {
  local scripts_dir="$PROJECT_DIR/scripts"
  [ -d "$scripts_dir" ] || return

  local missing=""
  local count=0

  for script in "$scripts_dir"/*.sh; do
    [ -f "$script" ] || continue
    count=$((count + 1))
    if [ ! -x "$script" ]; then
      missing="${missing:+$missing, }$(basename "$script")"
    fi
  done

  if [ -n "$missing" ]; then
    warn "missing execute permission: $missing"
  elif [ "$count" -gt 0 ]; then
    ok "script permissions: $count scripts, all executable"
  fi
}

# D3: zombie state file detection
check_d3_zombie_state() {
  local state_file="$PROJECT_DIR/.claude/.afc-state.json"
  if [ ! -f "$state_file" ]; then
    ok "no zombie state: state file absent (pipeline inactive)"
    return
  fi

  local feature
  if command -v jq >/dev/null 2>&1; then
    feature=$(jq -r '.feature // empty' "$state_file" 2>/dev/null || true)
  else
    feature=$(grep -o '"feature"[[:space:]]*:[[:space:]]*"[^"]*"' "$state_file" | sed 's/.*"feature"[[:space:]]*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
  fi

  if [ -z "$feature" ] || [ "$feature" = "null" ]; then
    fail "zombie state: .afc-state.json exists but feature is empty/null"
  else
    ok "active state: feature=$feature"
  fi
}

# --- Main ---

printf "[afc:qa] Running QA audit...\n"

check_a_hook_io_safety
check_b_test_strength
check_c_ux_completeness
check_d_build_deploy

printf "\n[afc:qa] Done: %d passed, %d warnings, %d errors\n" "$PASSES" "$WARNINGS" "$ERRORS"

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi
exit 0
