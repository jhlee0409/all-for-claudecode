#!/bin/bash
# all-for-claudecode Hook script tests
# Run: bash tests/test-hooks.sh (or npm test)

set -uo pipefail

# --- Test framework ---
PASS=0; FAIL=0; TOTAL=0
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

assert_exit() {
  local name="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [ "$expected" = "$actual" ]; then
    echo "  ✓ $name"; PASS=$((PASS + 1))
  else
    echo "  ✗ $name (expected exit $expected, got $actual)"; FAIL=$((FAIL + 1))
  fi
}

assert_stdout_contains() {
  local name="$1" pattern="$2" output="$3"
  TOTAL=$((TOTAL + 1))
  if echo "$output" | grep -qF "$pattern"; then
    echo "  ✓ $name"; PASS=$((PASS + 1))
  else
    echo "  ✗ $name (pattern '$pattern' not found)"; FAIL=$((FAIL + 1))
  fi
}

assert_stdout_empty() {
  local name="$1" output="$2"
  TOTAL=$((TOTAL + 1))
  if [ -z "$output" ]; then
    echo "  ✓ $name"; PASS=$((PASS + 1))
  else
    echo "  ✗ $name (expected empty, got '$output')"; FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local name="$1" path="$2"
  TOTAL=$((TOTAL + 1))
  if [ -f "$path" ]; then
    echo "  ✓ $name"; PASS=$((PASS + 1))
  else
    echo "  ✗ $name (file not found: $path)"; FAIL=$((FAIL + 1))
  fi
}

assert_file_contains() {
  local name="$1" path="$2" pattern="$3"
  TOTAL=$((TOTAL + 1))
  if [ -f "$path" ] && grep -q "$pattern" "$path"; then
    echo "  ✓ $name"; PASS=$((PASS + 1))
  else
    echo "  ✗ $name (pattern '$pattern' not in $path)"; FAIL=$((FAIL + 1))
  fi
}

# --- tmpdir setup ---
setup_tmpdir() {
  local tmpdir
  tmpdir=$(mktemp -d)
  mkdir -p "$tmpdir/.claude"
  echo "$tmpdir"
}

setup_tmpdir_with_git() {
  local tmpdir
  tmpdir=$(setup_tmpdir)
  (cd "$tmpdir" && git init -q && git config user.email "test@test.com" && git config user.name "Test" && git commit --allow-empty -m "init" -q 2>/dev/null)
  echo "$tmpdir"
}

cleanup_tmpdir() {
  [ -n "${1:-}" ] && rm -rf "$1"
}

# ============================================================
echo "=== afc-bash-guard.sh ==="
# ============================================================

# 1. Inactive pipeline → allow
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(echo '{}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-bash-guard.sh" 2>/dev/null); CODE=$?
assert_exit "inactive pipeline → exit 0" "0" "$CODE"
assert_stdout_contains "inactive → allow" '"permissionDecision":"allow"' "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 2. push --force → deny
TEST_DIR=$(setup_tmpdir)
echo "bash-guard-test" > "$TEST_DIR/.claude/.afc-active"
OUTPUT=$(echo '{"tool_input":{"command":"git push --force origin main"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-bash-guard.sh" 2>/dev/null); CODE=$?
assert_exit "push --force → exit 0 (deny in output)" "0" "$CODE"
assert_stdout_contains "push --force → deny" '"permissionDecision":"deny"' "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 3. safe command → allow
TEST_DIR=$(setup_tmpdir)
echo "bash-guard-test" > "$TEST_DIR/.claude/.afc-active"
OUTPUT=$(echo '{"tool_input":{"command":"ls -la"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-bash-guard.sh" 2>/dev/null); CODE=$?
assert_exit "safe command → exit 0" "0" "$CODE"
assert_stdout_contains "safe command → allow" '"permissionDecision":"allow"' "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 4. reset --hard afc/pre- → allow (rollback permitted)
TEST_DIR=$(setup_tmpdir)
echo "bash-guard-test" > "$TEST_DIR/.claude/.afc-active"
OUTPUT=$(echo '{"tool_input":{"command":"git reset --hard afc/pre-auto"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-bash-guard.sh" 2>/dev/null); CODE=$?
assert_stdout_contains "reset --hard afc/pre- → allow" '"permissionDecision":"allow"' "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 5. empty stdin → allow
TEST_DIR=$(setup_tmpdir)
echo "bash-guard-test" > "$TEST_DIR/.claude/.afc-active"
OUTPUT=$(echo '' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-bash-guard.sh" 2>/dev/null); CODE=$?
assert_exit "empty stdin → exit 0" "0" "$CODE"
assert_stdout_contains "empty stdin → allow" '"permissionDecision":"allow"' "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 6. push --force → updatedInput contains safe alternative
TEST_DIR=$(setup_tmpdir)
echo "bash-guard-test" > "$TEST_DIR/.claude/.afc-active"
OUTPUT=$(echo '{"tool_input":{"command":"git push --force"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-bash-guard.sh" 2>/dev/null); CODE=$?
assert_stdout_contains "push --force → updatedInput" '"updatedInput"' "$OUTPUT"
assert_stdout_contains "push --force → safe alternative" '"command":"git push"' "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 7. reset --hard → updatedInput contains git stash
TEST_DIR=$(setup_tmpdir)
echo "bash-guard-test" > "$TEST_DIR/.claude/.afc-active"
OUTPUT=$(echo '{"tool_input":{"command":"git reset --hard HEAD"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-bash-guard.sh" 2>/dev/null); CODE=$?
assert_stdout_contains "reset --hard → updatedInput" '"updatedInput"' "$OUTPUT"
assert_stdout_contains "reset --hard → safe alternative" '"command":"git stash"' "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 8. clean -f → updatedInput contains git clean -n
TEST_DIR=$(setup_tmpdir)
echo "bash-guard-test" > "$TEST_DIR/.claude/.afc-active"
OUTPUT=$(echo '{"tool_input":{"command":"git clean -f"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-bash-guard.sh" 2>/dev/null); CODE=$?
assert_stdout_contains "clean -f → updatedInput" '"updatedInput"' "$OUTPUT"
assert_stdout_contains "clean -f → safe alternative" '"command":"git clean -n"' "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== afc-stop-gate.sh ==="
# ============================================================

# 1. Inactive pipeline → pass
TEST_DIR=$(setup_tmpdir)
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-stop-gate.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "inactive pipeline → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 2. spec phase → pass (CI not required)
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
echo "spec" > "$TEST_DIR/.claude/.afc-phase"
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-stop-gate.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "spec phase → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 3. implement phase, no CI → block (exit 2)
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-stop-gate.sh" 2>&1); CODE=$?
set -e
assert_exit "implement no-ci → exit 2" "2" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 4. implement phase, CI passed → pass
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
date +%s > "$TEST_DIR/.claude/.afc-ci-passed"
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-stop-gate.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "implement ci-passed → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== track-afc-changes.sh ==="
# ============================================================

# 1. Inactive → skip
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(echo '{"tool_input":{"file_path":"/tmp/test.ts"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/track-afc-changes.sh" 2>/dev/null); CODE=$?
assert_exit "inactive → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 2. Active → file logged
TEST_DIR=$(setup_tmpdir)
echo "track-test" > "$TEST_DIR/.claude/.afc-active"
OUTPUT=$(echo '{"tool_input":{"file_path":"/tmp/test.ts"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/track-afc-changes.sh" 2>/dev/null); CODE=$?
assert_exit "active → exit 0" "0" "$CODE"
assert_file_contains "file logged" "$TEST_DIR/.claude/.afc-changes.log" "/tmp/test.ts"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== afc-auto-format.sh ==="
# ============================================================

# 1. empty stdin → exit 0
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(echo '' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-auto-format.sh" 2>/dev/null); CODE=$?
assert_exit "empty stdin → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 2. valid input, nonexistent file → exit 0 (graceful)
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(echo '{"tool_input":{"file_path":"/tmp/nonexistent-file.ts"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-auto-format.sh" 2>/dev/null); CODE=$?
assert_exit "nonexistent file → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== session-start-context.sh ==="
# ============================================================

# 1. Inactive pipeline → silent (stdout empty or checkpoint-related only)
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/session-start-context.sh" 2>/dev/null); CODE=$?
assert_exit "no pipeline → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 2. Active pipeline → stdout contains AFC
TEST_DIR=$(setup_tmpdir)
echo "context-test" > "$TEST_DIR/.claude/.afc-active"
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/session-start-context.sh" 2>/dev/null); CODE=$?
assert_exit "active pipeline → exit 0" "0" "$CODE"
assert_stdout_contains "active → AFC PIPELINE" "AFC PIPELINE" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== pre-compact-checkpoint.sh ==="
# ============================================================

# 1. Run → verify checkpoint file creation
TEST_DIR=$(setup_tmpdir_with_git)
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/pre-compact-checkpoint.sh" 2>/dev/null); CODE=$?
assert_exit "run → exit 0" "0" "$CODE"
# checkpoint is created at HOME/.claude/projects/{encoded}/ so verify via stdout
assert_stdout_contains "checkpoint saved" "Auto-checkpoint saved" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== afc-subagent-context.sh ==="
# ============================================================

# 1. Inactive → silent
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-subagent-context.sh" 2>/dev/null); CODE=$?
assert_exit "inactive → exit 0" "0" "$CODE"
assert_stdout_empty "inactive → no output" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 2. Active → stdout contains Feature
TEST_DIR=$(setup_tmpdir)
echo "subagent-test" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-subagent-context.sh" 2>/dev/null); CODE=$?
assert_exit "active → exit 0" "0" "$CODE"
assert_stdout_contains "active → Feature" "Feature: subagent-test" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== afc-pipeline-manage.sh ==="
# ============================================================

# 1. start → flag created
TEST_DIR=$(setup_tmpdir_with_git)
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-pipeline-manage.sh" start test-feature 2>/dev/null); CODE=$?
assert_exit "start → exit 0" "0" "$CODE"
assert_file_exists "flag created" "$TEST_DIR/.claude/.afc-active"
assert_file_contains "flag contains feature" "$TEST_DIR/.claude/.afc-active" "test-feature"
cleanup_tmpdir "$TEST_DIR"

# 2. phase → flag updated
TEST_DIR=$(setup_tmpdir_with_git)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-pipeline-manage.sh" phase plan 2>/dev/null); CODE=$?
assert_exit "phase → exit 0" "0" "$CODE"
assert_file_contains "phase updated" "$TEST_DIR/.claude/.afc-phase" "plan"
cleanup_tmpdir "$TEST_DIR"

# 3. end → flags deleted
TEST_DIR=$(setup_tmpdir_with_git)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-pipeline-manage.sh" end 2>/dev/null); CODE=$?
assert_exit "end → exit 0" "0" "$CODE"
TOTAL=$((TOTAL + 1))
if [ ! -f "$TEST_DIR/.claude/.afc-active" ]; then
  echo "  ✓ flags deleted"; PASS=$((PASS + 1))
else
  echo "  ✗ flags deleted (.afc-active still exists)"; FAIL=$((FAIL + 1))
fi
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== afc-session-end.sh ==="
# ============================================================

# 1. Inactive → exit 0, no stderr
TEST_DIR=$(setup_tmpdir)
STDERR_OUT=$(echo '{"reason":"other"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-session-end.sh" 2>&1 1>/dev/null); CODE=$?
assert_exit "inactive → exit 0" "0" "$CODE"
assert_stdout_empty "inactive → no stderr" "$STDERR_OUT"
cleanup_tmpdir "$TEST_DIR"

# 2. Active → stderr contains feature name
TEST_DIR=$(setup_tmpdir)
echo "session-end-test" > "$TEST_DIR/.claude/.afc-active"
STDERR_OUT=$(echo '{"reason":"other"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-session-end.sh" 2>&1 1>/dev/null); CODE=$?
assert_exit "active → exit 0" "0" "$CODE"
assert_stdout_contains "active → feature in stderr" "session-end-test" "$STDERR_OUT"
cleanup_tmpdir "$TEST_DIR"

# 3. Active + reason → stderr contains reason
TEST_DIR=$(setup_tmpdir)
echo "session-end-test" > "$TEST_DIR/.claude/.afc-active"
STDERR_OUT=$(echo '{"reason":"logout"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-session-end.sh" 2>&1 1>/dev/null); CODE=$?
assert_stdout_contains "active → reason in stderr" "logout" "$STDERR_OUT"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== afc-failure-hint.sh ==="
# ============================================================

# 1. EACCES error → JSON contains hint
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(echo '{"tool_name":"Bash","error":"EACCES: permission denied"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-failure-hint.sh" 2>/dev/null); CODE=$?
assert_exit "EACCES → exit 0" "0" "$CODE"
assert_stdout_contains "EACCES → hint" "AFC HINT" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 2. Unknown error → no stdout
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(echo '{"tool_name":"Bash","error":"some random error"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-failure-hint.sh" 2>/dev/null); CODE=$?
assert_exit "unknown error → exit 0" "0" "$CODE"
assert_stdout_empty "unknown error → no output" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 3. Active pipeline + error → failures.log written
TEST_DIR=$(setup_tmpdir)
echo "hint-test" > "$TEST_DIR/.claude/.afc-active"
OUTPUT=$(echo '{"tool_name":"Edit","error":"ENOENT: no such file"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-failure-hint.sh" 2>/dev/null); CODE=$?
assert_file_exists "failures.log created" "$TEST_DIR/.claude/.afc-failures.log"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== afc-notify.sh ==="
# ============================================================

# 1. Unknown notification_type → exit 0
TEST_DIR=$(setup_tmpdir)
set +e
OUTPUT=$(echo '{"notification_type":"auth_success","message":"done"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-notify.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "unknown type → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 2. idle_prompt → exit 0 (attempts notification, exit 0 even on failure)
TEST_DIR=$(setup_tmpdir)
set +e
OUTPUT=$(echo '{"notification_type":"idle_prompt","message":"Task completed"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-notify.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "idle_prompt → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== afc-task-completed-gate.sh ==="
# ============================================================

# 1. Inactive pipeline → exit 0
TEST_DIR=$(setup_tmpdir)
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-task-completed-gate.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "inactive pipeline → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 2. spec phase → exit 0 (CI not required)
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
echo "spec" > "$TEST_DIR/.claude/.afc-phase"
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-task-completed-gate.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "spec phase → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 3. implement phase, no CI → block (exit 2)
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-task-completed-gate.sh" 2>&1); CODE=$?
set -e
assert_exit "implement no-ci → exit 2" "2" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 4. implement phase, CI passed → exit 0
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
date +%s > "$TEST_DIR/.claude/.afc-ci-passed"
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-task-completed-gate.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "implement ci-passed → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== afc-subagent-stop.sh ==="
# ============================================================

# 1. Inactive → exit 0, no stdout
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(echo '{"stop_hook_active":false,"agent_id":"a1","agent_type":"Explore"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-subagent-stop.sh" 2>/dev/null); CODE=$?
assert_exit "inactive → exit 0" "0" "$CODE"
TOTAL=$((TOTAL + 1))
if [ ! -f "$TEST_DIR/.claude/.afc-task-results.log" ]; then
  echo "  ✓ inactive → no log file"; PASS=$((PASS + 1))
else
  echo "  ✗ inactive → no log file (file exists)"; FAIL=$((FAIL + 1))
fi
cleanup_tmpdir "$TEST_DIR"

# 2. stop_hook_active: true → exit 0, no log
TEST_DIR=$(setup_tmpdir)
echo "stop-test" > "$TEST_DIR/.claude/.afc-active"
OUTPUT=$(echo '{"stop_hook_active":true,"agent_id":"a2","agent_type":"Task"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-subagent-stop.sh" 2>/dev/null); CODE=$?
assert_exit "stop_hook_active → exit 0" "0" "$CODE"
TOTAL=$((TOTAL + 1))
if [ ! -f "$TEST_DIR/.claude/.afc-task-results.log" ]; then
  echo "  ✓ stop_hook_active → no log"; PASS=$((PASS + 1))
else
  echo "  ✗ stop_hook_active → no log (file exists)"; FAIL=$((FAIL + 1))
fi
cleanup_tmpdir "$TEST_DIR"

# 3. Active + normal → written to log
TEST_DIR=$(setup_tmpdir)
echo "subagent-stop-test" > "$TEST_DIR/.claude/.afc-active"
OUTPUT=$(echo '{"stop_hook_active":false,"agent_id":"abc123","agent_type":"Explore","last_assistant_message":"Analysis complete"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-subagent-stop.sh" 2>/dev/null); CODE=$?
assert_exit "active normal → exit 0" "0" "$CODE"
assert_file_exists "task-results.log created" "$TEST_DIR/.claude/.afc-task-results.log"
assert_file_contains "log has agent_id" "$TEST_DIR/.claude/.afc-task-results.log" "abc123"
assert_file_contains "log has agent_type" "$TEST_DIR/.claude/.afc-task-results.log" "Explore"
cleanup_tmpdir "$TEST_DIR"

# 4. Active + empty message → "no message" default
TEST_DIR=$(setup_tmpdir)
echo "subagent-stop-test" > "$TEST_DIR/.claude/.afc-active"
OUTPUT=$(echo '{"stop_hook_active":false,"agent_id":"def456","agent_type":"Task"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-subagent-stop.sh" 2>/dev/null); CODE=$?
assert_exit "empty message → exit 0" "0" "$CODE"
assert_file_contains "log has no message" "$TEST_DIR/.claude/.afc-task-results.log" "no message"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== afc-user-prompt-submit.sh ==="
# ============================================================

# 1. Inactive pipeline → exit 0, no stdout
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(echo '' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-user-prompt-submit.sh" 2>/dev/null); CODE=$?
assert_exit "inactive pipeline → exit 0" "0" "$CODE"
assert_stdout_empty "inactive → no output" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 2. Active pipeline + phase → outputs Phase/Feature
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
OUTPUT=$(echo '' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-user-prompt-submit.sh" 2>/dev/null); CODE=$?
assert_exit "active + phase → exit 0" "0" "$CODE"
assert_stdout_contains "active → Pipeline: test-feature" "Pipeline: test-feature" "$OUTPUT"
assert_stdout_contains "active → Phase: implement" "Phase: implement" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 3. Active pipeline + no phase file → Phase: unknown
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
OUTPUT=$(echo '' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-user-prompt-submit.sh" 2>/dev/null); CODE=$?
assert_exit "active no phase file → exit 0" "0" "$CODE"
assert_stdout_contains "no phase → Phase: unknown" "Phase: unknown" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== afc-permission-request.sh ==="
# ============================================================

# 1. Inactive pipeline → exit 0, no allow
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(echo '{"tool_input":{"command":"npm test"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-permission-request.sh" 2>/dev/null); CODE=$?
assert_exit "inactive pipeline → exit 0" "0" "$CODE"
assert_stdout_empty "inactive → no allow decision" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 2. implement phase + npm test → allow
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
OUTPUT=$(echo '{"tool_input":{"command":"npm test"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-permission-request.sh" 2>/dev/null); CODE=$?
assert_exit "implement + npm test → exit 0" "0" "$CODE"
assert_stdout_contains "implement + npm test → allow" "allow" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 3. implement phase + shellcheck → allow
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
OUTPUT=$(echo '{"tool_input":{"command":"shellcheck scripts/foo.sh"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-permission-request.sh" 2>/dev/null); CODE=$?
assert_exit "implement + shellcheck → exit 0" "0" "$CODE"
assert_stdout_contains "implement + shellcheck → allow" "allow" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 4. implement phase + dangerous command → no allow
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
OUTPUT=$(echo '{"tool_input":{"command":"rm -rf /"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-permission-request.sh" 2>/dev/null); CODE=$?
assert_exit "implement + dangerous → exit 0" "0" "$CODE"
assert_stdout_empty "implement + dangerous → no allow" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 5. spec phase → no allow (only implement/review phases apply)
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
echo "spec" > "$TEST_DIR/.claude/.afc-phase"
OUTPUT=$(echo '{"tool_input":{"command":"npm test"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-permission-request.sh" 2>/dev/null); CODE=$?
assert_exit "spec phase → exit 0" "0" "$CODE"
assert_stdout_empty "spec phase → no allow" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== afc-config-change.sh ==="
# ============================================================

# 1. Inactive pipeline → exit 0
TEST_DIR=$(setup_tmpdir)
set +e
OUTPUT=$(echo '{"source":"user_settings","file_path":"/tmp/settings.json"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-config-change.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "inactive pipeline → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 2. Active + policy_settings → exit 0 (log only)
TEST_DIR=$(setup_tmpdir)
echo "config-test" > "$TEST_DIR/.claude/.afc-active"
set +e
OUTPUT=$(echo '{"source":"policy_settings","file_path":"/tmp/policy.json"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-config-change.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "policy_settings → exit 0" "0" "$CODE"
assert_file_exists "audit log created (policy)" "$TEST_DIR/.claude/.afc-config-audit.log"
assert_file_contains "audit log has policy_settings" "$TEST_DIR/.claude/.afc-config-audit.log" "policy_settings"
cleanup_tmpdir "$TEST_DIR"

# 3. Active + user_settings → exit 2 (blocked)
TEST_DIR=$(setup_tmpdir)
echo "config-test" > "$TEST_DIR/.claude/.afc-active"
set +e
OUTPUT=$(echo '{"source":"user_settings","file_path":"/tmp/settings.json"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-config-change.sh" 2>&1); CODE=$?
set -e
assert_exit "user_settings → exit 2 (block)" "2" "$CODE"
assert_file_exists "audit log created (user)" "$TEST_DIR/.claude/.afc-config-audit.log"
assert_file_contains "audit log has user_settings" "$TEST_DIR/.claude/.afc-config-audit.log" "user_settings"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== afc-teammate-idle.sh ==="
# ============================================================

# 1. Inactive pipeline → exit 0
TEST_DIR=$(setup_tmpdir)
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-teammate-idle.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "inactive pipeline → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 2. Active + spec phase → exit 0 (idle allowed)
TEST_DIR=$(setup_tmpdir)
echo "teammate-test" > "$TEST_DIR/.claude/.afc-active"
echo "spec" > "$TEST_DIR/.claude/.afc-phase"
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-teammate-idle.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "spec phase → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 3. Active + implement phase → exit 2 (idle blocked)
TEST_DIR=$(setup_tmpdir)
echo "teammate-test" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-teammate-idle.sh" 2>&1); CODE=$?
set -e
assert_exit "implement phase → exit 2" "2" "$CODE"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== afc-pipeline-manage.sh (extended) ==="
# ============================================================

# T-1a: ci-pass subcommand
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-pipeline-manage.sh" ci-pass 2>/dev/null); CODE=$?
assert_exit "ci-pass → exit 0" "0" "$CODE"
assert_file_exists "ci-pass flag created" "$TEST_DIR/.claude/.afc-ci-passed"
cleanup_tmpdir "$TEST_DIR"

# T-1b: status subcommand (active pipeline)
TEST_DIR=$(setup_tmpdir)
echo "status-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-pipeline-manage.sh" status 2>/dev/null); CODE=$?
assert_exit "status → exit 0" "0" "$CODE"
assert_stdout_contains "status → Active" "Active" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T-1c: status subcommand (no active pipeline)
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-pipeline-manage.sh" status 2>/dev/null); CODE=$?
assert_exit "status inactive → exit 0" "0" "$CODE"
assert_stdout_contains "status → No active" "No active" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== afc-stop-gate.sh (extended) ==="
# ============================================================

# T-2: stale CI (>600 seconds) → block
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
echo "1000000000" > "$TEST_DIR/.claude/.afc-ci-passed"
set +e
OUTPUT=$(echo '{}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-stop-gate.sh" 2>&1); CODE=$?
set -e
assert_exit "stale CI → exit 2" "2" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# T-5: stop_hook_active=true → pass through (prevent infinite loop)
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
set +e
OUTPUT=$(echo '{"stop_hook_active":true}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-stop-gate.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "stop_hook_active → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== afc-task-completed-gate.sh (extended) ==="
# ============================================================

# T-2b: stale CI in task-completed-gate → block
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
echo "review" > "$TEST_DIR/.claude/.afc-phase"
echo "1000000000" > "$TEST_DIR/.claude/.afc-ci-passed"
set +e
OUTPUT=$(echo '{}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-task-completed-gate.sh" 2>&1); CODE=$?
set -e
assert_exit "stale CI (task) → exit 2" "2" "$CODE"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== afc-permission-request.sh (extended) ==="
# ============================================================

# T-3: command chaining detection (&&)
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
OUTPUT=$(echo '{"tool_input":{"command":"npm test && rm -rf /"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-permission-request.sh" 2>/dev/null); CODE=$?
assert_exit "chaining && → exit 0" "0" "$CODE"
assert_stdout_empty "chaining && → no allow" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T-3b: command chaining detection (;)
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
OUTPUT=$(echo '{"tool_input":{"command":"npm test; rm -rf /"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-permission-request.sh" 2>/dev/null); CODE=$?
assert_exit "chaining ; → exit 0" "0" "$CODE"
assert_stdout_empty "chaining ; → no allow" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T-3c: redirect detection (>)
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
OUTPUT=$(echo '{"tool_input":{"command":"shellcheck foo > /tmp/out"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-permission-request.sh" 2>/dev/null); CODE=$?
assert_exit "redirect > → exit 0" "0" "$CODE"
assert_stdout_empty "redirect > → no allow" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T-4: chmod +x path traversal → blocked
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
OUTPUT=$(echo '{"tool_input":{"command":"chmod +x ../../etc/evil.sh"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-permission-request.sh" 2>/dev/null); CODE=$?
assert_exit "chmod path traversal → exit 0" "0" "$CODE"
assert_stdout_empty "chmod path traversal → no allow" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== agents/ + hooks.json type validation ==="
# ============================================================

# 1. agents/afc-architect.md exists
assert_file_exists "agents/afc-architect.md exists" "$SCRIPT_DIR/agents/afc-architect.md"

# 2. agents/afc-security.md exists
assert_file_exists "agents/afc-security.md exists" "$SCRIPT_DIR/agents/afc-security.md"

# 3. afc-architect.md contains memory: project
assert_file_contains "architect agent has memory: project" "$SCRIPT_DIR/agents/afc-architect.md" "memory: project"

# 4. afc-security.md contains memory: project
assert_file_contains "security agent has memory: project" "$SCRIPT_DIR/agents/afc-security.md" "memory: project"

# 5. hooks.json contains type: "prompt"
assert_file_contains "hooks.json has type prompt" "$SCRIPT_DIR/hooks/hooks.json" '"type": "prompt"'

# 6. hooks.json contains type: "agent"
assert_file_contains "hooks.json has type agent" "$SCRIPT_DIR/hooks/hooks.json" '"type": "agent"'

# 7. commands/architect.md contains agent: afc-architect
assert_file_contains "architect.md references afc-architect agent" "$SCRIPT_DIR/commands/architect.md" "agent: afc-architect"

# 8. commands/security.md contains agent: afc-security
assert_file_contains "security.md references afc-security agent" "$SCRIPT_DIR/commands/security.md" "agent: afc-security"

# 9. plugin.json contains commands field
assert_file_contains "plugin.json has commands field" "$SCRIPT_DIR/.claude-plugin/plugin.json" '"commands"'

# 10. hooks.json contains ConfigChange event
assert_file_contains "hooks.json has ConfigChange event" "$SCRIPT_DIR/hooks/hooks.json" '"ConfigChange"'

# 11. hooks.json contains TeammateIdle event
assert_file_contains "hooks.json has TeammateIdle event" "$SCRIPT_DIR/hooks/hooks.json" '"TeammateIdle"'

# 12. afc-security.md contains isolation: worktree
assert_file_contains "security agent has isolation: worktree" "$SCRIPT_DIR/agents/afc-security.md" "isolation: worktree"

# 13. afc-architect.md contains skills field
assert_file_contains "architect agent has skills field" "$SCRIPT_DIR/agents/afc-architect.md" "skills:"

# 14. afc-security.md contains skills field
assert_file_contains "security agent has skills field" "$SCRIPT_DIR/agents/afc-security.md" "skills:"

# ============================================================
echo "=== afc-timeline-log.sh ==="
# ============================================================

# T012-1. Basic event logging
TEST_DIR=$(setup_tmpdir)
mkdir -p "$TEST_DIR/.claude"
echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-timeline-log.sh" "phase-start" "Test event" 2>/dev/null; CODE=$?
assert_exit "timeline: basic log → exit 0" "0" "$CODE"
assert_file_exists "timeline: jsonl file created" "$TEST_DIR/.claude/.afc-timeline.jsonl"
cleanup_tmpdir "$TEST_DIR"

# T012-2. Log without active pipeline
TEST_DIR=$(setup_tmpdir)
mkdir -p "$TEST_DIR/.claude"
CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-timeline-log.sh" "pipeline-start" "No pipeline" 2>/dev/null; CODE=$?
assert_exit "timeline: no pipeline → exit 0" "0" "$CODE"
OUTPUT=$(cat "$TEST_DIR/.claude/.afc-timeline.jsonl" 2>/dev/null)
assert_stdout_contains "timeline: feature=none when no pipeline" '"feature":"none"' "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T012-3. Missing arguments → exit 0 (never block)
TEST_DIR=$(setup_tmpdir)
CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-timeline-log.sh" 2>/dev/null; CODE=$?
assert_exit "timeline: missing args → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# T012-4. Log rotation (file exceeds 1MB)
TEST_DIR=$(setup_tmpdir)
mkdir -p "$TEST_DIR/.claude"
# Create a file just over 1MB
dd if=/dev/zero bs=1048577 count=1 2>/dev/null | tr '\0' 'x' > "$TEST_DIR/.claude/.afc-timeline.jsonl"
CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-timeline-log.sh" "test" "rotation test" 2>/dev/null; CODE=$?
assert_exit "timeline: rotation → exit 0" "0" "$CODE"
assert_file_exists "timeline: rotated file exists" "$TEST_DIR/.claude/.afc-timeline.jsonl.1"
cleanup_tmpdir "$TEST_DIR"

# T012-5. JSONL contains required fields
TEST_DIR=$(setup_tmpdir)
mkdir -p "$TEST_DIR/.claude"
echo "my-feature" > "$TEST_DIR/.claude/.afc-active"
echo "spec" > "$TEST_DIR/.claude/.afc-phase"
CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-timeline-log.sh" "gate-pass" "CI passed" 2>/dev/null
OUTPUT=$(cat "$TEST_DIR/.claude/.afc-timeline.jsonl" 2>/dev/null)
assert_stdout_contains "timeline: has ts field" '"ts":' "$OUTPUT"
assert_stdout_contains "timeline: has event field" '"event":"gate-pass"' "$OUTPUT"
assert_stdout_contains "timeline: has feature field" '"feature":"my-feature"' "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# ============================================================
echo "=== afc-parallel-validate.sh ==="
# ============================================================

# T013-1. Valid [P] tasks (no overlap)
TEST_DIR=$(setup_tmpdir)
cat > "$TEST_DIR/tasks.md" << 'TASKS_EOF'
## Phase 1: Setup
- [ ] T001 [P] Create service `src/a.ts`
- [ ] T002 [P] Create helper `src/b.ts`
## Phase 2: Core
- [ ] T003 Do something `src/c.ts`
TASKS_EOF
OUTPUT=$("$SCRIPT_DIR/scripts/afc-parallel-validate.sh" "$TEST_DIR/tasks.md" 2>/dev/null); CODE=$?
assert_exit "parallel-validate: valid → exit 0" "0" "$CODE"
assert_stdout_contains "parallel-validate: reports valid" "Valid:" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T013-2. Conflicting [P] tasks (same file)
TEST_DIR=$(setup_tmpdir)
cat > "$TEST_DIR/tasks.md" << 'TASKS_EOF'
## Phase 1: Setup
- [ ] T001 [P] Create service `src/shared.ts`
- [ ] T002 [P] Modify service `src/shared.ts`
TASKS_EOF
set +e
OUTPUT=$("$SCRIPT_DIR/scripts/afc-parallel-validate.sh" "$TEST_DIR/tasks.md" 2>/dev/null); CODE=$?
set -e
assert_exit "parallel-validate: conflict → exit 1" "1" "$CODE"
assert_stdout_contains "parallel-validate: reports CONFLICT" "CONFLICT" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T013-3. No [P] tasks at all
TEST_DIR=$(setup_tmpdir)
cat > "$TEST_DIR/tasks.md" << 'TASKS_EOF'
## Phase 1: Setup
- [ ] T001 Create service `src/a.ts`
- [ ] T002 Create helper `src/b.ts`
TASKS_EOF
OUTPUT=$("$SCRIPT_DIR/scripts/afc-parallel-validate.sh" "$TEST_DIR/tasks.md" 2>/dev/null); CODE=$?
assert_exit "parallel-validate: no [P] → exit 0" "0" "$CODE"
assert_stdout_contains "parallel-validate: no [P] message" "no [P] tasks found" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T013-4. Empty file
TEST_DIR=$(setup_tmpdir)
: > "$TEST_DIR/tasks.md"
OUTPUT=$("$SCRIPT_DIR/scripts/afc-parallel-validate.sh" "$TEST_DIR/tasks.md" 2>/dev/null); CODE=$?
assert_exit "parallel-validate: empty file → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# T013-5. File not found
TEST_DIR=$(setup_tmpdir)
set +e
OUTPUT=$("$SCRIPT_DIR/scripts/afc-parallel-validate.sh" "$TEST_DIR/nonexistent.md" 2>&1); CODE=$?
set -e
assert_exit "parallel-validate: missing file → exit 1" "1" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# T013-6. Multi-file [P] tasks with no overlap
TEST_DIR=$(setup_tmpdir)
cat > "$TEST_DIR/tasks.md" <<'TASKS_EOF'
## Phase 1: Setup
- [ ] T001 [P] Create models `src/user.ts` `src/auth.ts`
- [ ] T002 [P] Create services `src/svc.ts` `src/helper.ts`
TASKS_EOF
OUTPUT=$("$SCRIPT_DIR/scripts/afc-parallel-validate.sh" "$TEST_DIR/tasks.md" 2>/dev/null); CODE=$?
assert_exit "parallel-validate: multi-file no overlap → exit 0" "0" "$CODE"
assert_stdout_contains "parallel-validate: multi-file valid" "Valid:" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T013-7. Multi-file [P] tasks with overlap on second path
TEST_DIR=$(setup_tmpdir)
cat > "$TEST_DIR/tasks.md" <<'TASKS_EOF'
## Phase 1: Setup
- [ ] T001 [P] Create models `src/user.ts` `src/shared.ts`
- [ ] T002 [P] Create services `src/svc.ts` `src/shared.ts`
TASKS_EOF
set +e
OUTPUT=$("$SCRIPT_DIR/scripts/afc-parallel-validate.sh" "$TEST_DIR/tasks.md" 2>/dev/null); CODE=$?
set -e
assert_exit "parallel-validate: multi-file overlap → exit 1" "1" "$CODE"
assert_stdout_contains "parallel-validate: multi-file CONFLICT" "CONFLICT" "$OUTPUT"
assert_stdout_contains "parallel-validate: identifies shared file" "src/shared.ts" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T013-8. Mixed backtick content (code keywords + file paths)
TEST_DIR=$(setup_tmpdir)
cat > "$TEST_DIR/tasks.md" <<'TASKS_EOF'
## Phase 1: Setup
- [ ] T001 [P] Set `enabled` to `true` in `src/config.ts`
- [ ] T002 [P] Update `src/app.ts` with `exit` handler
TASKS_EOF
OUTPUT=$("$SCRIPT_DIR/scripts/afc-parallel-validate.sh" "$TEST_DIR/tasks.md" 2>/dev/null); CODE=$?
assert_exit "parallel-validate: mixed backticks → exit 0" "0" "$CODE"
assert_stdout_contains "parallel-validate: mixed backticks valid" "Valid:" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# ============================================================
echo "=== afc-preflight-check.sh ==="
# ============================================================

# T014-1. Clean environment → pass
TEST_DIR=$(setup_tmpdir_with_git)
# Create a minimal package.json with test:all script
cat > "$TEST_DIR/package.json" << 'PKG_EOF'
{"scripts":{"test:all":"echo ok"}}
PKG_EOF
mkdir -p "$TEST_DIR/node_modules"
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-preflight-check.sh" 2>/dev/null); CODE=$?
assert_exit "preflight: clean env → exit 0" "0" "$CODE"
assert_stdout_contains "preflight: reports PASS" "PASS" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T014-2. Missing package.json CI scripts → fail
TEST_DIR=$(setup_tmpdir_with_git)
cat > "$TEST_DIR/package.json" << 'PKG_EOF'
{"scripts":{}}
PKG_EOF
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-preflight-check.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "preflight: no CI script → exit 1" "1" "$CODE"
assert_stdout_contains "preflight: reports FAIL" "FAIL" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T014-3. Active pipeline → fail
TEST_DIR=$(setup_tmpdir_with_git)
cat > "$TEST_DIR/package.json" << 'PKG_EOF'
{"scripts":{"test":"echo ok"}}
PKG_EOF
mkdir -p "$TEST_DIR/node_modules"
echo "existing-pipeline" > "$TEST_DIR/.claude/.afc-active"
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-preflight-check.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "preflight: active pipeline → exit 1" "1" "$CODE"
assert_stdout_contains "preflight: reports pipeline running" "already running" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T014-4. Missing node_modules → warn but pass
TEST_DIR=$(setup_tmpdir_with_git)
cat > "$TEST_DIR/package.json" << 'PKG_EOF'
{"scripts":{"test:all":"echo ok"}}
PKG_EOF
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-preflight-check.sh" 2>/dev/null); CODE=$?
assert_exit "preflight: no node_modules → exit 0 (warn)" "0" "$CODE"
assert_stdout_contains "preflight: warns about node_modules" "node_modules" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T014-5. No package.json at all → warn (not fail)
TEST_DIR=$(setup_tmpdir_with_git)
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-preflight-check.sh" 2>/dev/null); CODE=$?
assert_exit "preflight: no package.json → exit 0 (warn)" "0" "$CODE"
assert_stdout_contains "preflight: warns about missing CI" "not detected" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T014-6. afc.config.md with ci: field → pass (config takes priority)
TEST_DIR=$(setup_tmpdir_with_git)
cat > "$TEST_DIR/.claude/afc.config.md" << 'CFG_EOF'
## CI Commands
```yaml
ci: "cargo test"
gate: "cargo check"
```
CFG_EOF
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-preflight-check.sh" 2>/dev/null); CODE=$?
assert_exit "preflight: afc.config.md ci → exit 0" "0" "$CODE"
assert_stdout_contains "preflight: detects CI from config" "cargo test" "$OUTPUT"
assert_stdout_contains "preflight: reports config source" "afc.config.md" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T014-7. turbo.json + pnpm-workspace.yaml → pass (monorepo detection)
TEST_DIR=$(setup_tmpdir_with_git)
echo '{}' > "$TEST_DIR/turbo.json"
echo 'packages:' > "$TEST_DIR/pnpm-workspace.yaml"
touch "$TEST_DIR/pnpm-lock.yaml"
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-preflight-check.sh" 2>/dev/null); CODE=$?
assert_exit "preflight: turbo+pnpm → exit 0" "0" "$CODE"
assert_stdout_contains "preflight: detects pnpm turbo" "pnpm turbo test" "$OUTPUT"
assert_stdout_contains "preflight: reports turbo source" "turbo.json" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T014-8. Makefile with test: target → pass
TEST_DIR=$(setup_tmpdir_with_git)
cat > "$TEST_DIR/Makefile" << 'MAKE_EOF'
test:
	echo "running tests"
MAKE_EOF
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-preflight-check.sh" 2>/dev/null); CODE=$?
assert_exit "preflight: Makefile test → exit 0" "0" "$CODE"
assert_stdout_contains "preflight: detects make test" "make test" "$OUTPUT"
assert_stdout_contains "preflight: reports Makefile source" "Makefile" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T014-9. yarn.lock → PM=yarn, uses yarn test
TEST_DIR=$(setup_tmpdir_with_git)
cat > "$TEST_DIR/package.json" << 'PKG_EOF'
{"scripts":{"test":"jest"}}
PKG_EOF
touch "$TEST_DIR/yarn.lock"
mkdir -p "$TEST_DIR/node_modules"
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-preflight-check.sh" 2>/dev/null); CODE=$?
assert_exit "preflight: yarn.lock → exit 0" "0" "$CODE"
assert_stdout_contains "preflight: detects yarn test" "yarn test" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T014-10. bun.lock → PM=bun
TEST_DIR=$(setup_tmpdir_with_git)
cat > "$TEST_DIR/package.json" << 'PKG_EOF'
{"scripts":{"test":"bun test"}}
PKG_EOF
touch "$TEST_DIR/bun.lock"
mkdir -p "$TEST_DIR/node_modules"
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-preflight-check.sh" 2>/dev/null); CODE=$?
assert_exit "preflight: bun.lock → exit 0" "0" "$CODE"
assert_stdout_contains "preflight: detects bun test" "bun test" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T014-11. nx.json → npx nx run-many
TEST_DIR=$(setup_tmpdir_with_git)
echo '{}' > "$TEST_DIR/nx.json"
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-preflight-check.sh" 2>/dev/null); CODE=$?
assert_exit "preflight: nx.json → exit 0" "0" "$CODE"
assert_stdout_contains "preflight: detects nx" "npx nx run-many" "$OUTPUT"
assert_stdout_contains "preflight: reports nx source" "nx.json" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T014-12. afc.config.md with only gate: (no ci:) → uses gate as fallback
TEST_DIR=$(setup_tmpdir_with_git)
cat > "$TEST_DIR/.claude/afc.config.md" << 'CFG_EOF'
## CI Commands
```yaml
gate: "make check"
```
CFG_EOF
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-preflight-check.sh" 2>/dev/null); CODE=$?
assert_exit "preflight: gate fallback → exit 0" "0" "$CODE"
assert_stdout_contains "preflight: detects gate command" "make check" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T014-13. package.json with "ci" script (not "test")
TEST_DIR=$(setup_tmpdir_with_git)
cat > "$TEST_DIR/package.json" << 'PKG_EOF'
{"scripts":{"ci":"npm run lint && npm run typecheck"}}
PKG_EOF
mkdir -p "$TEST_DIR/node_modules"
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-preflight-check.sh" 2>/dev/null); CODE=$?
assert_exit "preflight: ci script → exit 0" "0" "$CODE"
assert_stdout_contains "preflight: detects npm run ci" "npm run ci" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# ============================================================
echo "=== afc-pipeline-manage.sh (new subcommands) ==="
# ============================================================

# T015-1. log subcommand
TEST_DIR=$(setup_tmpdir)
mkdir -p "$TEST_DIR/.claude"
echo "log-test" > "$TEST_DIR/.claude/.afc-active"
echo "plan" > "$TEST_DIR/.claude/.afc-phase"
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-pipeline-manage.sh" log "test-event" "test message" 2>/dev/null); CODE=$?
assert_exit "pipeline-manage log → exit 0" "0" "$CODE"
assert_file_exists "pipeline-manage log → jsonl created" "$TEST_DIR/.claude/.afc-timeline.jsonl"
cleanup_tmpdir "$TEST_DIR"

# T015-2. phase-tag subcommand
TEST_DIR=$(setup_tmpdir_with_git)
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-pipeline-manage.sh" phase-tag 1 2>/dev/null); CODE=$?
assert_exit "pipeline-manage phase-tag → exit 0" "0" "$CODE"
assert_stdout_contains "pipeline-manage phase-tag → creates tag" "afc/phase-1" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T015-3. phase-tag-clean subcommand
TEST_DIR=$(setup_tmpdir_with_git)
(cd "$TEST_DIR" && git tag "afc/phase-1" && git tag "afc/phase-2") 2>/dev/null
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-pipeline-manage.sh" phase-tag-clean 2>/dev/null); CODE=$?
assert_exit "pipeline-manage phase-tag-clean → exit 0" "0" "$CODE"
assert_stdout_contains "pipeline-manage phase-tag-clean → removes tags" "Removed 2 phase tags" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T015-4. phase-tag-clean with no tags
TEST_DIR=$(setup_tmpdir_with_git)
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-pipeline-manage.sh" phase-tag-clean 2>/dev/null); CODE=$?
assert_exit "pipeline-manage phase-tag-clean (no tags) → exit 0" "0" "$CODE"
assert_stdout_contains "pipeline-manage phase-tag-clean (no tags) → message" "No phase tags" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T015-5. end subcommand cleans phase tags
TEST_DIR=$(setup_tmpdir_with_git)
echo "end-test" > "$TEST_DIR/.claude/.afc-active"
(cd "$TEST_DIR" && git tag "afc/pre-auto" && git tag "afc/phase-1" && git tag "afc/phase-2") 2>/dev/null
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-pipeline-manage.sh" end 2>/dev/null); CODE=$?
assert_exit "pipeline-manage end → exit 0" "0" "$CODE"
# Verify phase tags are gone
REMAINING_TAGS=$(cd "$TEST_DIR" && git tag -l 'afc/phase-*' 2>/dev/null || true)
TOTAL=$((TOTAL + 1))
if [ -z "$REMAINING_TAGS" ]; then
  echo "  ✓ pipeline-manage end → phase tags cleaned"; PASS=$((PASS + 1))
else
  echo "  ✗ pipeline-manage end → phase tags remain: $REMAINING_TAGS"; FAIL=$((FAIL + 1))
fi
cleanup_tmpdir "$TEST_DIR"

# ============================================================
echo "=== afc-worktree-create.sh ==="
# ============================================================

# T016-1. Pipeline inactive → exit 0, no output
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(echo '{"worktree_path":"/tmp/wt1"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-worktree-create.sh" 2>/dev/null); CODE=$?
assert_exit "worktree-create: inactive → exit 0" "0" "$CODE"
assert_stdout_empty "worktree-create: inactive → no output" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T016-2. Pipeline active → context output
TEST_DIR=$(setup_tmpdir)
echo "wt-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
OUTPUT=$(echo '{"worktree_path":"/tmp/wt1"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-worktree-create.sh" 2>/dev/null); CODE=$?
assert_exit "worktree-create: active → exit 0" "0" "$CODE"
assert_stdout_contains "worktree-create: has additionalContext" "additionalContext" "$OUTPUT"
assert_stdout_contains "worktree-create: has feature name" "wt-feature" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T016-3. Empty stdin → exit 0
TEST_DIR=$(setup_tmpdir)
echo "wt-feature" > "$TEST_DIR/.claude/.afc-active"
OUTPUT=$(echo '{}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-worktree-create.sh" 2>/dev/null); CODE=$?
assert_exit "worktree-create: no worktree_path → exit 0" "0" "$CODE"
assert_stdout_empty "worktree-create: no worktree_path → no output" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# ============================================================
echo "=== afc-worktree-remove.sh ==="
# ============================================================

# T017-1. Pipeline inactive → exit 0, no archive
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(echo '{"worktree_path":"/tmp/wt1"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-worktree-remove.sh" 2>/dev/null); CODE=$?
assert_exit "worktree-remove: inactive → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# T017-2. Pipeline active + worktree results → archive to main
TEST_DIR=$(setup_tmpdir)
echo "rm-feature" > "$TEST_DIR/.claude/.afc-active"
WT_DIR=$(mktemp -d)
mkdir -p "$WT_DIR/.claude"
echo "1234 [general-purpose] agent1: task done" > "$WT_DIR/.claude/.afc-task-results.log"
OUTPUT=$(echo "{\"worktree_path\":\"$WT_DIR\"}" | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-worktree-remove.sh" 2>/dev/null); CODE=$?
assert_exit "worktree-remove: active + results → exit 0" "0" "$CODE"
assert_file_exists "worktree-remove: results archived" "$TEST_DIR/.claude/.afc-task-results.log"
assert_file_contains "worktree-remove: results content" "$TEST_DIR/.claude/.afc-task-results.log" "task done"
rm -rf "$WT_DIR"
cleanup_tmpdir "$TEST_DIR"

# T017-3. Pipeline active + no worktree results → exit 0, no crash
TEST_DIR=$(setup_tmpdir)
echo "rm-feature" > "$TEST_DIR/.claude/.afc-active"
WT_DIR=$(mktemp -d)
OUTPUT=$(echo "{\"worktree_path\":\"$WT_DIR\"}" | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-worktree-remove.sh" 2>/dev/null); CODE=$?
assert_exit "worktree-remove: no results → exit 0" "0" "$CODE"
rm -rf "$WT_DIR"
cleanup_tmpdir "$TEST_DIR"

# ============================================================
echo "=== afc-stop-gate.sh (last_assistant_message) ==="
# ============================================================

# T018-1. Completion claim without CI → exit 2
TEST_DIR=$(setup_tmpdir)
echo "gate-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
set +e
OUTPUT=$(echo '{"last_assistant_message":"All tasks are done and implemented."}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-stop-gate.sh" 2>&1); CODE=$?
set -e
assert_exit "stop-gate: completion claim + no CI → exit 2" "2" "$CODE"
assert_stdout_contains "stop-gate: mentions completion claim" "claims completion" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# T018-2. Completion claim WITH CI → exit 0
TEST_DIR=$(setup_tmpdir)
echo "gate-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
date +%s > "$TEST_DIR/.claude/.afc-ci-passed"
OUTPUT=$(echo '{"last_assistant_message":"All tasks are done and implemented."}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-stop-gate.sh" 2>/dev/null); CODE=$?
assert_exit "stop-gate: completion claim + CI passed → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# T018-3. No completion claim, no CI → generic CI message
TEST_DIR=$(setup_tmpdir)
echo "gate-feature" > "$TEST_DIR/.claude/.afc-active"
echo "implement" > "$TEST_DIR/.claude/.afc-phase"
set +e
OUTPUT=$(echo '{"last_assistant_message":"Working on the next task."}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/afc-stop-gate.sh" 2>&1); CODE=$?
set -e
assert_exit "stop-gate: no claim + no CI → exit 2" "2" "$CODE"
assert_stdout_contains "stop-gate: generic CI message" "CI has not been run" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
# Results output
# ============================================================
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
exit "$FAIL"
