#!/bin/bash
# shellcheck shell=bash


Describe "session-start-context.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when pipeline is inactive"
    It "exits 0 with no output"
      Data ""
      When run script scripts/session-start-context.sh
      The status should eq 0
      The output should eq ""
    End
  End

  Context "when pipeline is active"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "context-test"
    }

    It "exits 0 and outputs AFC PIPELINE"
      Data ""
      When run script scripts/session-start-context.sh
      The status should eq 0
      The output should include "AFC PIPELINE"
    End
  End

  Context "when zombie state exists (feature: null)"
    setup() {
      setup_tmpdir TEST_DIR
      printf '{"feature": null, "phase": "spec"}' > "$TEST_DIR/.claude/.afc-state.json"
    }

    It "cleans up zombie state and reports"
      Data ""
      When run script scripts/session-start-context.sh
      The status should eq 0
      The output should include "ZOMBIE STATE CLEANED"
      The path "$TEST_DIR/.claude/.afc-state.json" should not be exist
    End
  End

  Context "when version mismatch exists"
    setup() {
      setup_tmpdir TEST_DIR
      mkdir -p "$TEST_DIR/.claude"
      cat > "$TEST_DIR/.claude/CLAUDE.md" << 'HEREDOC'
<!-- AFC:START -->
<!-- AFC:VERSION:1.0.0 -->
test block
<!-- AFC:END -->
HEREDOC
    }

    It "reports version mismatch"
      Data ""
      When run script scripts/session-start-context.sh
      The status should eq 0
      The output should include "AFC VERSION MISMATCH"
    End
  End

  Context "when version matches"
    setup() {
      setup_tmpdir TEST_DIR
      # Read actual plugin version
      local ver
      ver=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "scripts/../package.json" 2>/dev/null | head -1 | sed 's/.*: *"//;s/"//')
      mkdir -p "$TEST_DIR/.claude"
      cat > "$TEST_DIR/.claude/CLAUDE.md" << HEREDOC
<!-- AFC:START -->
<!-- AFC:VERSION:${ver} -->
test block
<!-- AFC:END -->
HEREDOC
    }

    It "does not report version mismatch"
      Data ""
      When run script scripts/session-start-context.sh
      The status should eq 0
      The output should not include "VERSION MISMATCH"
    End
  End

  Context "when checkpoint exists"
    setup() {
      setup_tmpdir TEST_DIR
      # Create auto-memory checkpoint
      local project_path encoded_path
      project_path=$(cd "$TEST_DIR" && pwd)
      encoded_path="${project_path//\//-}"
      mkdir -p "$TEST_DIR/.claude/projects/$encoded_path/memory"
      printf '# Checkpoint\nAuto-generated: 2026-03-01 12:00:00\n' > "$TEST_DIR/.claude/projects/$encoded_path/memory/checkpoint.md"
    }

    It "reports checkpoint existence"
      Data ""
      When run script scripts/session-start-context.sh
      The status should eq 0
      The output should include "CHECKPOINT EXISTS"
      The output should include "2026-03-01"
    End
  End

  Context "when pipeline active with tasks.md progress"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "progress-test" "implement"
      mkdir -p "$TEST_DIR/.claude/afc/specs/progress-test"
      cat > "$TEST_DIR/.claude/afc/specs/progress-test/tasks.md" << 'EOF'
- [x] T001 Done task
- [ ] T002 Pending task
- [x] T003 Done task
EOF
    }

    It "reports task progress count"
      Data ""
      When run script scripts/session-start-context.sh
      The status should eq 0
      The output should include "AFC PIPELINE"
      The output should include "Tasks: 2/3"
    End
  End

  Context "when pipeline active with CI passed"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "ci-test" "implement"
      . scripts/afc-state.sh
      _AFC_STATE_DIR="$TEST_DIR/.claude"
      _AFC_STATE_FILE="$TEST_DIR/.claude/.afc-state.json"
      afc_state_write "ciPassedAt" "1709337600"
    }

    It "reports CI pass status"
      Data ""
      When run script scripts/session-start-context.sh
      The status should eq 0
      The output should include "AFC PIPELINE"
      The output should include "Last CI: PASSED"
    End
  End

  Context "when pipeline active with safety tag"
    setup() {
      setup_tmpdir_with_git TEST_DIR
      setup_state_fixture "$TEST_DIR" "safe-test"
      (cd "$TEST_DIR" && git tag "afc/pre-safe-test")
    }

    It "reports safety tag"
      Data ""
      When run script scripts/session-start-context.sh
      The status should eq 0
      The output should include "AFC PIPELINE"
      The output should include "Safety tag"
    End
  End
End
