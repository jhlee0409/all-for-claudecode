#!/bin/bash
# afc-state.sh — Shared state library for pipeline state management
# Source this file: . "$(dirname "$0")/afc-state.sh"
# Replaces 4 flag files (.afc-active, .afc-phase, .afc-ci-passed, .afc-changes.log)
# with a single .afc-state.json file.

# State file path
_AFC_STATE_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude"
_AFC_STATE_FILE="${_AFC_STATE_DIR}/.afc-state.json"

# --- Phase Constants (SSOT) ---
# All valid pipeline phases. Update HERE when adding a new phase.
AFC_VALID_PHASES="spec|plan|tasks|implement|review|clean|clarify|test-pre-gen|blast-radius|fast-path"
# Phases that do NOT require CI gate to pass (preparatory phases)
AFC_CI_EXEMPT_PHASES="spec|plan|tasks|clarify|test-pre-gen|blast-radius"

# Check if a phase name is valid
# Usage: afc_is_valid_phase <phase>
# Returns: 0 if valid, 1 if not
afc_is_valid_phase() {
  printf '%s\n' "$AFC_VALID_PHASES" | tr '|' '\n' | grep -qxF "$1"
}

# Check if a phase is exempt from CI gate
# Usage: afc_is_ci_exempt <phase>
# Returns: 0 if exempt, 1 if CI required
afc_is_ci_exempt() {
  printf '%s\n' "$AFC_CI_EXEMPT_PHASES" | tr '|' '\n' | grep -qxF "$1"
}

# --- Public API ---

# Check if pipeline is active (state file exists, non-empty, and valid JSON with feature)
# Returns: 0 if active, 1 if not
afc_state_is_active() {
  [ -f "$_AFC_STATE_FILE" ] && [ -s "$_AFC_STATE_FILE" ] || return 1
  # Validate JSON structure — reject corrupt/truncated files
  if command -v jq >/dev/null 2>&1; then
    jq -e '.feature // empty' "$_AFC_STATE_FILE" >/dev/null 2>&1 || return 1
  else
    grep -q '"feature"' "$_AFC_STATE_FILE" 2>/dev/null || return 1
  fi
}

# Read a field from state file
# Usage: afc_state_read <field>
# Fields: feature, phase, ciPassedAt, startedAt
# Returns: field value on stdout, exit 1 if not found
afc_state_read() {
  local field="$1"
  if [ ! -f "$_AFC_STATE_FILE" ]; then
    return 1
  fi
  if command -v jq >/dev/null 2>&1; then
    local val
    val=$(jq -r --arg f "$field" '.[$f] // empty' "$_AFC_STATE_FILE" 2>/dev/null) || return 1
    [ -n "$val" ] && printf '%s\n' "$val" && return 0
    return 1
  else
    # grep/sed fallback for simple string/number fields
    local val
    val=$(grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$_AFC_STATE_FILE" 2>/dev/null \
      | head -1 | sed 's/.*:[[:space:]]*"\(.*\)"/\1/')
    if [ -z "$val" ]; then
      # Try numeric value
      val=$(grep -o "\"${field}\"[[:space:]]*:[[:space:]]*[0-9]*" "$_AFC_STATE_FILE" 2>/dev/null \
        | head -1 | sed 's/.*:[[:space:]]*//')
    fi
    [ -n "$val" ] && printf '%s\n' "$val" && return 0
    return 1
  fi
}

# Write/update a field in state file
# Usage: afc_state_write <field> <value>
afc_state_write() {
  local field="$1" value="$2"
  mkdir -p "$_AFC_STATE_DIR"
  if [ ! -f "$_AFC_STATE_FILE" ]; then
    printf '{}' > "$_AFC_STATE_FILE"
  fi
  if command -v jq >/dev/null 2>&1; then
    local tmp
    tmp=$(mktemp)
    local jq_ok=0
    if printf '%s' "$value" | grep -qE '^[0-9]+$'; then
      jq --arg f "$field" --argjson v "$value" '.[$f] = $v' "$_AFC_STATE_FILE" > "$tmp" 2>/dev/null && jq_ok=1
    else
      jq --arg f "$field" --arg v "$value" '.[$f] = $v' "$_AFC_STATE_FILE" > "$tmp" 2>/dev/null && jq_ok=1
    fi
    if [ "$jq_ok" -eq 1 ]; then
      mv "$tmp" "$_AFC_STATE_FILE"
    else
      rm -f "$tmp"
    fi
  else
    # sed fallback: replace or append field
    # Escape sed-special chars in value: \ first, then & and /
    local safe_val="$value"
    safe_val="${safe_val//\\/\\\\}"
    safe_val="${safe_val//&/\\&}"
    safe_val="${safe_val//\//\\/}"
    if grep -q "\"${field}\"" "$_AFC_STATE_FILE" 2>/dev/null; then
      local tmp
      tmp=$(mktemp)
      if printf '%s' "$value" | grep -qE '^[0-9]+$'; then
        sed "s/\"${field}\"[[:space:]]*:[[:space:]]*[^,}]*/\"${field}\": ${value}/" "$_AFC_STATE_FILE" > "$tmp"
      else
        sed "s/\"${field}\"[[:space:]]*:[[:space:]]*[^,}]*/\"${field}\": \"${safe_val}\"/" "$_AFC_STATE_FILE" > "$tmp"
      fi
      mv "$tmp" "$_AFC_STATE_FILE"
    else
      # Append before closing brace
      local tmp
      tmp=$(mktemp)
      if printf '%s' "$value" | grep -qE '^[0-9]+$'; then
        sed "s/}$/,\"${field}\": ${value}}/" "$_AFC_STATE_FILE" > "$tmp"
      else
        sed "s/}$/,\"${field}\": \"${safe_val}\"}/" "$_AFC_STATE_FILE" > "$tmp"
      fi
      # Fix leading comma on empty object
      sed 's/{,/{/' "$tmp" > "$_AFC_STATE_FILE"
      rm -f "$tmp"
    fi
  fi
}

# Remove a field from state file
# Usage: afc_state_remove <field>
afc_state_remove() {
  local field="$1"
  if [ ! -f "$_AFC_STATE_FILE" ]; then
    return 0
  fi
  if command -v jq >/dev/null 2>&1; then
    local tmp
    tmp=$(mktemp)
    if jq --arg f "$field" 'del(.[$f])' "$_AFC_STATE_FILE" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$_AFC_STATE_FILE"
    else
      rm -f "$tmp"
    fi
  else
    # sed fallback: remove the field line from JSON
    if grep -q "\"${field}\"" "$_AFC_STATE_FILE" 2>/dev/null; then
      local tmp
      tmp=$(mktemp)
      # Remove line containing the field, then fix trailing commas
      grep -v "\"${field}\"" "$_AFC_STATE_FILE" > "$tmp" 2>/dev/null || true
      # Fix ",}" or ",]" left by removal
      sed 's/,[[:space:]]*}/}/g; s/,[[:space:]]*\]/]/g' "$tmp" > "$_AFC_STATE_FILE"
      rm -f "$tmp"
    fi
  fi
}

# Initialize state for a new pipeline
# Usage: afc_state_init <feature>
afc_state_init() {
  local feature="$1"
  local now
  now=$(date +%s)
  mkdir -p "$_AFC_STATE_DIR"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg f "$feature" --argjson t "$now" \
      '{feature: $f, phase: "spec", startedAt: $t}' > "$_AFC_STATE_FILE"
  else
    local safe_feature="${feature//\\/\\\\}"
    safe_feature="${safe_feature//\"/\\\"}"
    printf '{"feature": "%s", "phase": "spec", "startedAt": %s}\n' "$safe_feature" "$now" > "$_AFC_STATE_FILE"
  fi
}

# Delete the state file (pipeline ended)
afc_state_delete() {
  rm -f "$_AFC_STATE_FILE"
}

# Append a file path to the changes array
# Usage: afc_state_append_change <file_path>
afc_state_append_change() {
  local file_path="$1"
  if [ ! -f "$_AFC_STATE_FILE" ]; then
    return 1
  fi
  if command -v jq >/dev/null 2>&1; then
    local tmp
    tmp=$(mktemp)
    if jq --arg p "$file_path" '.changes = ((.changes // []) + [$p] | unique)' "$_AFC_STATE_FILE" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$_AFC_STATE_FILE"
    else
      rm -f "$tmp"
    fi
  else
    # Fallback: use a sidecar changes file
    printf '%s\n' "$file_path" >> "${_AFC_STATE_FILE%.json}.changes.log"
    sort -u -o "${_AFC_STATE_FILE%.json}.changes.log" "${_AFC_STATE_FILE%.json}.changes.log"
  fi
}

# Read all changes as newline-separated list
# Usage: afc_state_read_changes
afc_state_read_changes() {
  if [ ! -f "$_AFC_STATE_FILE" ]; then
    return 1
  fi
  if command -v jq >/dev/null 2>&1; then
    jq -r '.changes[]? // empty' "$_AFC_STATE_FILE" 2>/dev/null
  else
    # Fallback: read sidecar file
    if [ -f "${_AFC_STATE_FILE%.json}.changes.log" ]; then
      cat "${_AFC_STATE_FILE%.json}.changes.log"
    fi
  fi
}

# Invalidate CI (remove ciPassedAt)
afc_state_invalidate_ci() {
  afc_state_remove "ciPassedAt"
}

# Record CI pass timestamp
afc_state_ci_pass() {
  local now
  now=$(date +%s)
  afc_state_write "ciPassedAt" "$now"
}

# Record a phase checkpoint with git SHA
# Usage: afc_state_checkpoint <phase>
afc_state_checkpoint() {
  local phase="$1"
  if [ ! -f "$_AFC_STATE_FILE" ]; then
    return 1
  fi
  local git_sha=""
  git_sha=$(cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null && git rev-parse --short HEAD 2>/dev/null || echo "")
  local now
  now=$(date +%s)
  if command -v jq >/dev/null 2>&1; then
    local tmp
    tmp=$(mktemp)
    if jq --arg p "$phase" --arg s "$git_sha" --argjson t "$now" \
      '.phaseCheckpoints = ((.phaseCheckpoints // []) + [{"phase": $p, "gitSha": $s, "timestamp": $t}])' \
      "$_AFC_STATE_FILE" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$_AFC_STATE_FILE"
    else
      rm -f "$tmp"
    fi
  fi
  # No sed fallback — phaseCheckpoints is array-typed, too complex for sed
}
