#!/bin/bash
# shellcheck shell=bash


Describe "afc-user-prompt-submit.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when pipeline is inactive"
    It "exits 0 and output is empty"
      Data '{}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should eq ""
    End
  End

  Context "when pipeline is active with implement phase"
    setup() {
      setup_tmpdir TEST_DIR
      echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
      echo "implement" > "$TEST_DIR/.claude/.afc-phase"
    }

    It "exits 0 and stdout contains Pipeline and Phase info"
      Data '{}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should include "test-feature"
      The output should include "implement"
    End
  End

  Context "when pipeline is active but no phase file"
    setup() {
      setup_tmpdir TEST_DIR
      echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
    }

    It "exits 0 and stdout contains Phase: unknown"
      Data '{}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should include "unknown"
    End
  End
End
