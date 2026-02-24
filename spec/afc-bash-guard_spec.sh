#!/bin/bash
# shellcheck shell=bash


Describe "afc-bash-guard.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when pipeline is inactive"
    It "exits 0 and allows"
      Data '{}'
      When run script scripts/afc-bash-guard.sh
      The status should eq 0
      The output should include '"permissionDecision":"allow"'
    End
  End

  Context "when pipeline is active"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "feature"
    }

    It "denies git push --force"
      Data '{"tool_input":{"command":"git push --force"}}'
      When run script scripts/afc-bash-guard.sh
      The status should eq 0
      The output should include '"permissionDecision":"deny"'
    End

    It "allows a safe command"
      Data '{"tool_input":{"command":"git status"}}'
      When run script scripts/afc-bash-guard.sh
      The status should eq 0
      The output should include '"permissionDecision":"allow"'
    End

    It "allows reset --hard for afc/pre- tag rollback"
      Data '{"tool_input":{"command":"git reset --hard afc/pre-feature"}}'
      When run script scripts/afc-bash-guard.sh
      The status should eq 0
      The output should include '"permissionDecision":"allow"'
    End

    It "exits 0 and allows on empty stdin"
      Data ''
      When run script scripts/afc-bash-guard.sh
      The status should eq 0
      The output should include '"permissionDecision":"allow"'
    End

    It "returns updatedInput with git push for push --force"
      Data '{"tool_input":{"command":"git push --force"}}'
      When run script scripts/afc-bash-guard.sh
      The status should eq 0
      The output should include '"updatedInput"'
      The output should include 'git push'
    End

    It "returns updatedInput with git stash for reset --hard HEAD"
      Data '{"tool_input":{"command":"git reset --hard HEAD"}}'
      When run script scripts/afc-bash-guard.sh
      The status should eq 0
      The output should include '"updatedInput"'
      The output should include 'git stash'
    End

    It "returns updatedInput with git clean -n for clean -f"
      Data '{"tool_input":{"command":"git clean -f"}}'
      When run script scripts/afc-bash-guard.sh
      The status should eq 0
      The output should include '"updatedInput"'
      The output should include 'git clean -n'
    End
  End
End
