#!/bin/bash
# shellcheck shell=bash


Describe "afc-stop-gate.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when pipeline is inactive"
    It "exits 0"
      Data '{}'
      When run script scripts/afc-stop-gate.sh
      The status should eq 0
    End
  End

  Context "when pipeline is active in spec phase"
    setup() {
      setup_tmpdir TEST_DIR
      echo "feature-name" > "$TEST_DIR/.claude/.afc-active"
      echo "spec" > "$TEST_DIR/.claude/.afc-phase"
    }

    It "exits 0 for spec phase (no CI required)"
      Data '{}'
      When run script scripts/afc-stop-gate.sh
      The status should eq 0
    End
  End

  Context "when pipeline is active in implement phase with no CI passed"
    setup() {
      setup_tmpdir TEST_DIR
      echo "feature-name" > "$TEST_DIR/.claude/.afc-active"
      echo "implement" > "$TEST_DIR/.claude/.afc-phase"
    }

    It "exits 2 blocking stop"
      Data '{}'
      When run script scripts/afc-stop-gate.sh
      The status should eq 2
      The stderr should include "AFC GATE"
    End
  End

  Context "when pipeline is active in implement phase with fresh CI passed"
    setup() {
      setup_tmpdir TEST_DIR
      echo "feature-name" > "$TEST_DIR/.claude/.afc-active"
      echo "implement" > "$TEST_DIR/.claude/.afc-phase"
      date +%s > "$TEST_DIR/.claude/.afc-ci-passed"
    }

    It "exits 0 when CI passed recently"
      Data '{}'
      When run script scripts/afc-stop-gate.sh
      The status should eq 0
    End
  End

  Context "when pipeline is active in implement phase with stale CI timestamp"
    setup() {
      setup_tmpdir TEST_DIR
      echo "feature-name" > "$TEST_DIR/.claude/.afc-active"
      echo "implement" > "$TEST_DIR/.claude/.afc-phase"
      echo "1000000000" > "$TEST_DIR/.claude/.afc-ci-passed"
    }

    It "exits 2 for stale CI results"
      Data '{}'
      When run script scripts/afc-stop-gate.sh
      The status should eq 2
      The stderr should include "stale"
    End
  End

  Context "when stop_hook_active is true"
    setup() {
      setup_tmpdir TEST_DIR
      echo "feature-name" > "$TEST_DIR/.claude/.afc-active"
      echo "implement" > "$TEST_DIR/.claude/.afc-phase"
    }

    It "exits 0 to prevent infinite loop"
      Data '{"stop_hook_active":true}'
      When run script scripts/afc-stop-gate.sh
      The status should eq 0
    End
  End
End
