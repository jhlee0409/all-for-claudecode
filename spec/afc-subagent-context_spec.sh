#!/bin/bash
# shellcheck shell=bash


Describe "afc-subagent-context.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when pipeline is inactive"
    It "exits 0 and produces no output"
      Data '{}'
      When run script scripts/afc-subagent-context.sh
      The status should eq 0
      The output should eq ""
    End
  End

  Context "when pipeline is active in implement phase"
    setup() {
      setup_tmpdir TEST_DIR
      echo "subagent-test" > "$TEST_DIR/.claude/.afc-active"
      echo "implement" > "$TEST_DIR/.claude/.afc-phase"
    }

    It "exits 0 and includes Feature and Phase in output"
      Data '{}'
      When run script scripts/afc-subagent-context.sh
      The status should eq 0
      The output should include "Feature: subagent-test"
      The output should include "Phase: implement"
    End
  End
End
