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
    It "exits 0 and stdout contains afc:hint"
      Data '{"tool_name":"Write","error":"EACCES: permission denied"}'
      When run script scripts/afc-failure-hint.sh
      The status should eq 0
      The output should include "afc:hint"
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

  Context "when error is ECONNREFUSED"
    It "exits 0 and hints about server/service"
      Data '{"tool_name":"Bash","error":"ECONNREFUSED: connection refused"}'
      When run script scripts/afc-failure-hint.sh
      The status should eq 0
      The output should include "afc:hint"
      The output should include "server"
    End
  End

  Context "when error is command not found"
    It "exits 0 and hints about tool installation"
      Data '{"tool_name":"Bash","error":"eslint: command not found"}'
      When run script scripts/afc-failure-hint.sh
      The status should eq 0
      The output should include "afc:hint"
      The output should include "installed"
    End
  End

  Context "when error mentions shellcheck"
    It "exits 0 and hints about shellcheck install"
      Data '{"tool_name":"Bash","error":"shellcheck not available"}'
      When run script scripts/afc-failure-hint.sh
      The status should eq 0
      The output should include "afc:hint"
      The output should include "shellcheck"
    End
  End

  Context "when error is ENOMEM"
    It "exits 0 and hints about memory"
      Data '{"tool_name":"Bash","error":"ENOMEM: Cannot allocate memory"}'
      When run script scripts/afc-failure-hint.sh
      The status should eq 0
      The output should include "afc:hint"
      The output should include "memory"
    End
  End

  Context "when pipeline is active and error is ENOENT"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "feature-name"
    }

    It "exits 0 and creates .afc-failures.log"
      Data '{"tool_name":"Bash","error":"ENOENT: no such file or directory"}'
      When run script scripts/afc-failure-hint.sh
      The status should eq 0
      The output should include "afc:hint"
      The path "$TEST_DIR/.claude/.afc-failures.log" should be exist
    End

    It "log entry contains tool name and error"
      Data '{"tool_name":"Write","error":"ENOENT: file not found"}'
      When run script scripts/afc-failure-hint.sh
      The status should eq 0
      The output should include "afc:hint"
      The contents of file "$TEST_DIR/.claude/.afc-failures.log" should include "Write"
      The contents of file "$TEST_DIR/.claude/.afc-failures.log" should include "ENOENT"
    End
  End

  Context "when pipeline is inactive and error occurs"
    It "does not create failures log"
      Data '{"tool_name":"Bash","error":"EACCES: permission denied"}'
      When run script scripts/afc-failure-hint.sh
      The status should eq 0
      The output should include "afc:hint"
      The path "$TEST_DIR/.claude/.afc-failures.log" should not be exist
    End
  End

  Context "when stdin is empty"
    It "exits 0 with no output"
      Data ''
      When run script scripts/afc-failure-hint.sh
      The status should eq 0
      The output should eq ""
    End
  End
End
