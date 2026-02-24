#!/bin/bash
# shellcheck shell=bash


Describe "afc-session-end.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when pipeline is inactive"
    It "exits 0 with no stderr"
      Data '{}'
      When run script scripts/afc-session-end.sh
      The status should eq 0
      The stderr should eq ""
    End
  End

  Context "when pipeline is active"
    setup() {
      setup_tmpdir TEST_DIR
      echo "session-feature" > "$TEST_DIR/.claude/.afc-active"
    }

    It "exits 0 and warns with feature name in stderr"
      Data '{}'
      When run script scripts/afc-session-end.sh
      The status should eq 0
      The stderr should include "session-feature"
    End
  End

  Context "when pipeline is active and reason is logout"
    setup() {
      setup_tmpdir TEST_DIR
      echo "session-feature" > "$TEST_DIR/.claude/.afc-active"
    }

    It "exits 0 and includes logout reason in stderr"
      Data '{"reason":"logout"}'
      When run script scripts/afc-session-end.sh
      The status should eq 0
      The stderr should include "logout"
    End
  End
End
