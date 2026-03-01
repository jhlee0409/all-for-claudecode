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
End
