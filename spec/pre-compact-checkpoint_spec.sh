#!/bin/bash
# shellcheck shell=bash


Describe "pre-compact-checkpoint.sh"
  setup() {
    setup_tmpdir_with_git TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when run"
    It "exits 0 and prints Auto-checkpoint saved"
      Data '{}'
      When run script scripts/pre-compact-checkpoint.sh
      The status should eq 0
      The output should include "Auto-checkpoint saved"
    End
  End
End
