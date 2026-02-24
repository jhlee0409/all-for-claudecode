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
      echo "my-feature" > "$TEST_DIR/.claude/.afc-active"
      echo "spec" > "$TEST_DIR/.claude/.afc-phase"
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
      echo "my-feature" > "$TEST_DIR/.claude/.afc-active"
      echo "implement" > "$TEST_DIR/.claude/.afc-phase"
    }

    It "exits 2 blocking idle"
      Data '{}'
      When run script scripts/afc-teammate-idle.sh
      The status should eq 2
      The stderr should include "AFC TEAMMATE GATE"
    End
  End
End
