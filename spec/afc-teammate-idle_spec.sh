#!/bin/bash
# shellcheck shell=bash


Describe "afc-teammate-idle.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when pipeline is inactive"
    It "exits 0"
      Data '{}'
      When run script scripts/afc-teammate-idle.sh
      The status should eq 0
    End
  End

  Context "when pipeline is active in spec phase"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "my-feature" "spec"
    }

    It "exits 0 allowing idle"
      Data '{}'
      When run script scripts/afc-teammate-idle.sh
      The status should eq 0
    End
  End

  Context "when pipeline is active in implement phase"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "my-feature" "implement"
    }

    It "exits 2 blocking idle"
      Data '{}'
      When run script scripts/afc-teammate-idle.sh
      The status should eq 2
      The stderr should include "[afc:teammate]"
    End
  End
End
