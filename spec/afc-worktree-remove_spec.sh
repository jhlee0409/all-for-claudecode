#!/bin/bash
# shellcheck shell=bash


Describe "afc-worktree-remove.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when pipeline is inactive"
    It "exits 0 with no output"
      Data '{"worktree_path":"/tmp/worktree-test"}'
      When run script scripts/afc-worktree-remove.sh
      The status should eq 0
      The output should eq ""
    End
  End

  Context "when pipeline is active but worktree has no results log"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "my-feature"
    }

    It "exits 0 without creating task-results.log"
      Data '{"worktree_path":"/tmp/empty-worktree"}'
      When run script scripts/afc-worktree-remove.sh
      The status should eq 0
      The path "$TEST_DIR/.claude/.afc-task-results.log" should not be exist
    End
  End

  Context "when pipeline is active and worktree has results log"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "my-feature"
      # Create a mock worktree with a task results log
      mkdir -p "$TEST_DIR/worktree/.claude"
      echo "agent-result: T001 complete" > "$TEST_DIR/worktree/.claude/.afc-task-results.log"
    }

    It "exits 0 and archives results to main project log"
      Data "{\"worktree_path\":\"$TEST_DIR/worktree\"}"
      When run script scripts/afc-worktree-remove.sh
      The status should eq 0
      The path "$TEST_DIR/.claude/.afc-task-results.log" should be exist
      The contents of file "$TEST_DIR/.claude/.afc-task-results.log" should include "agent-result"
    End
  End
End
