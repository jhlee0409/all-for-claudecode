#!/bin/bash
# selfish-pipeline Hook 스크립트 테스트
# 실행: bash tests/test-hooks.sh (또는 npm test)

set -uo pipefail

# --- 테스트 프레임워크 ---
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

# --- tmpdir 셋업 ---
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
echo "=== selfish-bash-guard.sh ==="
# ============================================================

# 1. 비활성 파이프라인 → allow
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(echo '{}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-bash-guard.sh" 2>/dev/null); CODE=$?
assert_exit "inactive pipeline → exit 0" "0" "$CODE"
assert_stdout_contains "inactive → allow" '"decision":"allow"' "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 2. push --force → deny
TEST_DIR=$(setup_tmpdir)
echo "bash-guard-test" > "$TEST_DIR/.claude/.selfish-active"
OUTPUT=$(echo '{"tool_input":{"command":"git push --force origin main"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-bash-guard.sh" 2>/dev/null); CODE=$?
assert_exit "push --force → exit 0 (deny in output)" "0" "$CODE"
assert_stdout_contains "push --force → deny" '"decision":"deny"' "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 3. safe command → allow
TEST_DIR=$(setup_tmpdir)
echo "bash-guard-test" > "$TEST_DIR/.claude/.selfish-active"
OUTPUT=$(echo '{"tool_input":{"command":"ls -la"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-bash-guard.sh" 2>/dev/null); CODE=$?
assert_exit "safe command → exit 0" "0" "$CODE"
assert_stdout_contains "safe command → allow" '"decision":"allow"' "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 4. reset --hard selfish/pre- → allow (rollback 허용)
TEST_DIR=$(setup_tmpdir)
echo "bash-guard-test" > "$TEST_DIR/.claude/.selfish-active"
OUTPUT=$(echo '{"tool_input":{"command":"git reset --hard selfish/pre-auto"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-bash-guard.sh" 2>/dev/null); CODE=$?
assert_stdout_contains "reset --hard selfish/pre- → allow" '"decision":"allow"' "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 5. empty stdin → allow
TEST_DIR=$(setup_tmpdir)
echo "bash-guard-test" > "$TEST_DIR/.claude/.selfish-active"
OUTPUT=$(echo '' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-bash-guard.sh" 2>/dev/null); CODE=$?
assert_exit "empty stdin → exit 0" "0" "$CODE"
assert_stdout_contains "empty stdin → allow" '"decision":"allow"' "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== selfish-stop-gate.sh ==="
# ============================================================

# 1. 비활성 파이프라인 → pass
TEST_DIR=$(setup_tmpdir)
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-stop-gate.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "inactive pipeline → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 2. spec phase → pass (CI 불필요)
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.selfish-active"
echo "spec" > "$TEST_DIR/.claude/.selfish-phase"
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-stop-gate.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "spec phase → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 3. implement phase, no CI → block (exit 2)
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.selfish-active"
echo "implement" > "$TEST_DIR/.claude/.selfish-phase"
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-stop-gate.sh" 2>&1); CODE=$?
set -e
assert_exit "implement no-ci → exit 2" "2" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 4. implement phase, CI passed → pass
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.selfish-active"
echo "implement" > "$TEST_DIR/.claude/.selfish-phase"
date +%s > "$TEST_DIR/.claude/.selfish-ci-passed"
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-stop-gate.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "implement ci-passed → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== track-selfish-changes.sh ==="
# ============================================================

# 1. 비활성 → skip
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(echo '{"tool_input":{"file_path":"/tmp/test.ts"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/track-selfish-changes.sh" 2>/dev/null); CODE=$?
assert_exit "inactive → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 2. 활성 → 파일 기록
TEST_DIR=$(setup_tmpdir)
echo "track-test" > "$TEST_DIR/.claude/.selfish-active"
OUTPUT=$(echo '{"tool_input":{"file_path":"/tmp/test.ts"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/track-selfish-changes.sh" 2>/dev/null); CODE=$?
assert_exit "active → exit 0" "0" "$CODE"
assert_file_contains "file logged" "$TEST_DIR/.claude/.selfish-changes.log" "/tmp/test.ts"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== selfish-auto-format.sh ==="
# ============================================================

# 1. empty stdin → exit 0
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(echo '' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-auto-format.sh" 2>/dev/null); CODE=$?
assert_exit "empty stdin → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 2. valid input, nonexistent file → exit 0 (graceful)
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(echo '{"tool_input":{"file_path":"/tmp/nonexistent-file.ts"}}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-auto-format.sh" 2>/dev/null); CODE=$?
assert_exit "nonexistent file → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== session-start-context.sh ==="
# ============================================================

# 1. 파이프라인 비활성 → silent (stdout empty 또는 checkpoint 관련만)
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/session-start-context.sh" 2>/dev/null); CODE=$?
assert_exit "no pipeline → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 2. 파이프라인 활성 → stdout에 SELFISH 포함
TEST_DIR=$(setup_tmpdir)
echo "context-test" > "$TEST_DIR/.claude/.selfish-active"
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/session-start-context.sh" 2>/dev/null); CODE=$?
assert_exit "active pipeline → exit 0" "0" "$CODE"
assert_stdout_contains "active → SELFISH PIPELINE" "SELFISH PIPELINE" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== pre-compact-checkpoint.sh ==="
# ============================================================

# 1. 실행 → checkpoint 파일 생성 확인
TEST_DIR=$(setup_tmpdir_with_git)
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/pre-compact-checkpoint.sh" 2>/dev/null); CODE=$?
assert_exit "run → exit 0" "0" "$CODE"
# checkpoint는 HOME/.claude/projects/{encoded}/ 에 생성되므로 stdout 확인
assert_stdout_contains "checkpoint saved" "Auto-checkpoint saved" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== selfish-subagent-context.sh ==="
# ============================================================

# 1. 비활성 → silent
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-subagent-context.sh" 2>/dev/null); CODE=$?
assert_exit "inactive → exit 0" "0" "$CODE"
assert_stdout_empty "inactive → no output" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 2. 활성 → stdout에 Feature 포함
TEST_DIR=$(setup_tmpdir)
echo "subagent-test" > "$TEST_DIR/.claude/.selfish-active"
echo "implement" > "$TEST_DIR/.claude/.selfish-phase"
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-subagent-context.sh" 2>/dev/null); CODE=$?
assert_exit "active → exit 0" "0" "$CODE"
assert_stdout_contains "active → Feature" "Feature: subagent-test" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== selfish-pipeline-manage.sh ==="
# ============================================================

# 1. start → flag 생성
TEST_DIR=$(setup_tmpdir_with_git)
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-pipeline-manage.sh" start test-feature 2>/dev/null); CODE=$?
assert_exit "start → exit 0" "0" "$CODE"
assert_file_exists "flag created" "$TEST_DIR/.claude/.selfish-active"
assert_file_contains "flag contains feature" "$TEST_DIR/.claude/.selfish-active" "test-feature"
cleanup_tmpdir "$TEST_DIR"

# 2. phase → flag 업데이트
TEST_DIR=$(setup_tmpdir_with_git)
echo "test-feature" > "$TEST_DIR/.claude/.selfish-active"
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-pipeline-manage.sh" phase plan 2>/dev/null); CODE=$?
assert_exit "phase → exit 0" "0" "$CODE"
assert_file_contains "phase updated" "$TEST_DIR/.claude/.selfish-phase" "plan"
cleanup_tmpdir "$TEST_DIR"

# 3. end → flags 삭제
TEST_DIR=$(setup_tmpdir_with_git)
echo "test-feature" > "$TEST_DIR/.claude/.selfish-active"
echo "implement" > "$TEST_DIR/.claude/.selfish-phase"
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-pipeline-manage.sh" end 2>/dev/null); CODE=$?
assert_exit "end → exit 0" "0" "$CODE"
TOTAL=$((TOTAL + 1))
if [ ! -f "$TEST_DIR/.claude/.selfish-active" ]; then
  echo "  ✓ flags deleted"; PASS=$((PASS + 1))
else
  echo "  ✗ flags deleted (.selfish-active still exists)"; FAIL=$((FAIL + 1))
fi
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== selfish-session-end.sh ==="
# ============================================================

# 1. 비활성 → exit 0, stderr 없음
TEST_DIR=$(setup_tmpdir)
STDERR_OUT=$(echo '{"reason":"other"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-session-end.sh" 2>&1 1>/dev/null); CODE=$?
assert_exit "inactive → exit 0" "0" "$CODE"
assert_stdout_empty "inactive → no stderr" "$STDERR_OUT"
cleanup_tmpdir "$TEST_DIR"

# 2. 활성 → stderr에 feature명 포함
TEST_DIR=$(setup_tmpdir)
echo "session-end-test" > "$TEST_DIR/.claude/.selfish-active"
STDERR_OUT=$(echo '{"reason":"other"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-session-end.sh" 2>&1 1>/dev/null); CODE=$?
assert_exit "active → exit 0" "0" "$CODE"
assert_stdout_contains "active → feature in stderr" "session-end-test" "$STDERR_OUT"
cleanup_tmpdir "$TEST_DIR"

# 3. 활성 + reason → stderr에 reason 포함
TEST_DIR=$(setup_tmpdir)
echo "session-end-test" > "$TEST_DIR/.claude/.selfish-active"
STDERR_OUT=$(echo '{"reason":"logout"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-session-end.sh" 2>&1 1>/dev/null); CODE=$?
assert_stdout_contains "active → reason in stderr" "logout" "$STDERR_OUT"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== selfish-failure-hint.sh ==="
# ============================================================

# 1. EACCES 에러 → JSON에 hint 포함
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(echo '{"tool_name":"Bash","error":"EACCES: permission denied"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-failure-hint.sh" 2>/dev/null); CODE=$?
assert_exit "EACCES → exit 0" "0" "$CODE"
assert_stdout_contains "EACCES → hint" "SELFISH HINT" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 2. 알 수 없는 에러 → stdout 없음
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(echo '{"tool_name":"Bash","error":"some random error"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-failure-hint.sh" 2>/dev/null); CODE=$?
assert_exit "unknown error → exit 0" "0" "$CODE"
assert_stdout_empty "unknown error → no output" "$OUTPUT"
cleanup_tmpdir "$TEST_DIR"

# 3. 파이프라인 활성 + 에러 → failures.log 기록
TEST_DIR=$(setup_tmpdir)
echo "hint-test" > "$TEST_DIR/.claude/.selfish-active"
OUTPUT=$(echo '{"tool_name":"Edit","error":"ENOENT: no such file"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-failure-hint.sh" 2>/dev/null); CODE=$?
assert_file_exists "failures.log created" "$TEST_DIR/.claude/.selfish-failures.log"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== selfish-notify.sh ==="
# ============================================================

# 1. 알 수 없는 notification_type → exit 0
TEST_DIR=$(setup_tmpdir)
set +e
OUTPUT=$(echo '{"notification_type":"auth_success","message":"done"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-notify.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "unknown type → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 2. idle_prompt → exit 0 (알림 발송 시도, 실패해도 exit 0)
TEST_DIR=$(setup_tmpdir)
set +e
OUTPUT=$(echo '{"notification_type":"idle_prompt","message":"Task completed"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-notify.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "idle_prompt → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== selfish-task-completed-gate.sh ==="
# ============================================================

# 1. 비활성 파이프라인 → exit 0
TEST_DIR=$(setup_tmpdir)
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-task-completed-gate.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "inactive pipeline → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 2. spec phase → exit 0 (CI 불필요)
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.selfish-active"
echo "spec" > "$TEST_DIR/.claude/.selfish-phase"
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-task-completed-gate.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "spec phase → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 3. implement phase, no CI → block (exit 2)
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.selfish-active"
echo "implement" > "$TEST_DIR/.claude/.selfish-phase"
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-task-completed-gate.sh" 2>&1); CODE=$?
set -e
assert_exit "implement no-ci → exit 2" "2" "$CODE"
cleanup_tmpdir "$TEST_DIR"

# 4. implement phase, CI passed → exit 0
TEST_DIR=$(setup_tmpdir)
echo "test-feature" > "$TEST_DIR/.claude/.selfish-active"
echo "implement" > "$TEST_DIR/.claude/.selfish-phase"
date +%s > "$TEST_DIR/.claude/.selfish-ci-passed"
set +e
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-task-completed-gate.sh" 2>/dev/null); CODE=$?
set -e
assert_exit "implement ci-passed → exit 0" "0" "$CODE"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
echo "=== selfish-subagent-stop.sh ==="
# ============================================================

# 1. 비활성 → exit 0, stdout 없음
TEST_DIR=$(setup_tmpdir)
OUTPUT=$(echo '{"stop_hook_active":false,"agent_id":"a1","agent_type":"Explore"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-subagent-stop.sh" 2>/dev/null); CODE=$?
assert_exit "inactive → exit 0" "0" "$CODE"
TOTAL=$((TOTAL + 1))
if [ ! -f "$TEST_DIR/.claude/.selfish-task-results.log" ]; then
  echo "  ✓ inactive → no log file"; PASS=$((PASS + 1))
else
  echo "  ✗ inactive → no log file (file exists)"; FAIL=$((FAIL + 1))
fi
cleanup_tmpdir "$TEST_DIR"

# 2. stop_hook_active: true → exit 0, no log
TEST_DIR=$(setup_tmpdir)
echo "stop-test" > "$TEST_DIR/.claude/.selfish-active"
OUTPUT=$(echo '{"stop_hook_active":true,"agent_id":"a2","agent_type":"Task"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-subagent-stop.sh" 2>/dev/null); CODE=$?
assert_exit "stop_hook_active → exit 0" "0" "$CODE"
TOTAL=$((TOTAL + 1))
if [ ! -f "$TEST_DIR/.claude/.selfish-task-results.log" ]; then
  echo "  ✓ stop_hook_active → no log"; PASS=$((PASS + 1))
else
  echo "  ✗ stop_hook_active → no log (file exists)"; FAIL=$((FAIL + 1))
fi
cleanup_tmpdir "$TEST_DIR"

# 3. 활성 + 정상 → log에 기록
TEST_DIR=$(setup_tmpdir)
echo "subagent-stop-test" > "$TEST_DIR/.claude/.selfish-active"
OUTPUT=$(echo '{"stop_hook_active":false,"agent_id":"abc123","agent_type":"Explore","last_assistant_message":"Analysis complete"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-subagent-stop.sh" 2>/dev/null); CODE=$?
assert_exit "active normal → exit 0" "0" "$CODE"
assert_file_exists "task-results.log created" "$TEST_DIR/.claude/.selfish-task-results.log"
assert_file_contains "log has agent_id" "$TEST_DIR/.claude/.selfish-task-results.log" "abc123"
assert_file_contains "log has agent_type" "$TEST_DIR/.claude/.selfish-task-results.log" "Explore"
cleanup_tmpdir "$TEST_DIR"

# 4. 활성 + 빈 메시지 → "no message" 기본값
TEST_DIR=$(setup_tmpdir)
echo "subagent-stop-test" > "$TEST_DIR/.claude/.selfish-active"
OUTPUT=$(echo '{"stop_hook_active":false,"agent_id":"def456","agent_type":"Task"}' | CLAUDE_PROJECT_DIR="$TEST_DIR" "$SCRIPT_DIR/scripts/selfish-subagent-stop.sh" 2>/dev/null); CODE=$?
assert_exit "empty message → exit 0" "0" "$CODE"
assert_file_contains "log has no message" "$TEST_DIR/.claude/.selfish-task-results.log" "no message"
cleanup_tmpdir "$TEST_DIR"

echo ""

# ============================================================
# 결과 출력
# ============================================================
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
exit "$FAIL"
