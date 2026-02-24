#!/bin/bash
# shellcheck shell=bash


Describe "afc-failure-hint.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when error is EACCES"
    It "exits 0 and stdout contains AFC HINT"
      Data '{"tool_name":"Write","error":"EACCES: permission denied"}'
      When run script scripts/afc-failure-hint.sh
      The status should eq 0
      The output should include "AFC HINT"
    End
  End

  Context "when error is unknown"
    It "exits 0 and output is empty"
      Data '{"tool_name":"Write","error":"some totally unknown error xyz"}'
      When run script scripts/afc-failure-hint.sh
      The status should eq 0
      The output should eq ""
    End
  End

  Context "when pipeline is active and error is ENOENT"
    setup() {
      setup_tmpdir TEST_DIR
      echo "feature-name" > "$TEST_DIR/.claude/.afc-active"
    }

    It "exits 0 and creates .afc-failures.log"
      Data '{"tool_name":"Bash","error":"ENOENT: no such file or directory"}'
      When run script scripts/afc-failure-hint.sh
      The status should eq 0
      The output should include "AFC HINT"
      The path "$TEST_DIR/.claude/.afc-failures.log" should be exist
    End
  End
End
