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
      echo "context-test" > "$TEST_DIR/.claude/.afc-active"
    }

    It "exits 0 and outputs AFC PIPELINE"
      Data ""
      When run script scripts/session-start-context.sh
      The status should eq 0
      The output should include "AFC PIPELINE"
    End
  End
End
