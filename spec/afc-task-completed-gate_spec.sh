#!/bin/bash
# shellcheck shell=bash


Describe "afc-task-completed-gate.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when pipeline is inactive"
    It "exits 0"
      Data '{}'
      When run script scripts/afc-task-completed-gate.sh
      The status should eq 0
    End
  End

  Context "when pipeline is active in spec phase"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "my-feature" "spec"
    }

    It "exits 0 without requiring CI"
      Data '{}'
      When run script scripts/afc-task-completed-gate.sh
      The status should eq 0
    End
  End

  Context "when pipeline is active in implement phase with no CI flag"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "my-feature" "implement"
    }

    It "exits 2 and reports CI not run"
      Data '{}'
      When run script scripts/afc-task-completed-gate.sh
      The status should eq 2
      The stderr should include "CI has not been run"
    End
  End

  Context "when pipeline is active in implement phase with recent CI flag"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_with_ci "$TEST_DIR" "my-feature" "implement"
    }

    It "exits 0"
      Data '{}'
      When run script scripts/afc-task-completed-gate.sh
      The status should eq 0
    End
  End

  Context "when pipeline is active in review phase with stale CI timestamp"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_with_ci "$TEST_DIR" "my-feature" "review" "1000000000"
    }

    It "exits 2 and reports stale CI results"
      Data '{}'
      When run script scripts/afc-task-completed-gate.sh
      The status should eq 2
      The stderr should include "stale"
    End
  End
End
