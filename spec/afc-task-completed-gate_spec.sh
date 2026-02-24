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
      echo "my-feature" > "$TEST_DIR/.claude/.afc-active"
      echo "spec" > "$TEST_DIR/.claude/.afc-phase"
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
      echo "my-feature" > "$TEST_DIR/.claude/.afc-active"
      echo "implement" > "$TEST_DIR/.claude/.afc-phase"
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
      echo "my-feature" > "$TEST_DIR/.claude/.afc-active"
      echo "implement" > "$TEST_DIR/.claude/.afc-phase"
      date +%s > "$TEST_DIR/.claude/.afc-ci-passed"
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
      echo "my-feature" > "$TEST_DIR/.claude/.afc-active"
      echo "review" > "$TEST_DIR/.claude/.afc-phase"
      echo "1000000000" > "$TEST_DIR/.claude/.afc-ci-passed"
    }

    It "exits 2 and reports stale CI results"
      Data '{}'
      When run script scripts/afc-task-completed-gate.sh
      The status should eq 2
      The stderr should include "stale"
    End
  End
End
