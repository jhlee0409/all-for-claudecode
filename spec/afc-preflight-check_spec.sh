#!/bin/bash
# shellcheck shell=bash


Describe "afc-preflight-check.sh"
  setup() {
    setup_tmpdir_with_git TEST_DIR
    setup_config_fixture "$TEST_DIR"
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when no active pipeline"
    It "exits 0 and outputs Preflight Check"
      When run script scripts/afc-preflight-check.sh
      The status should eq 0
      The output should include "Preflight Check"
      The output should include "No active pipeline"
    End
  End

  Context "when pipeline is already active"
    setup() {
      setup_tmpdir_with_git TEST_DIR
      setup_config_fixture "$TEST_DIR"
      setup_state_fixture "$TEST_DIR" "existing-feature"
    }

    It "exits 1 and reports pipeline already running"
      When run script scripts/afc-preflight-check.sh
      The status should eq 1
      The output should include "pipeline already running"
    End
  End

  Context "when CI command is found in afc.config.md"
    It "exits 0 and reports CI command"
      When run script scripts/afc-preflight-check.sh
      The status should eq 0
      The output should include "CI command"
    End
  End
End
