#!/bin/bash
# shellcheck shell=bash


Describe "afc-worktree-create.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when pipeline is inactive"
    It "exits 0 with no output"
      Data '{"worktree_path":"/tmp/worktree-test"}'
      When run script scripts/afc-worktree-create.sh
      The status should eq 0
      The output should eq ""
    End
  End

  Context "when pipeline is active with worktree_path"
    setup() {
      setup_tmpdir TEST_DIR
      echo "my-feature" > "$TEST_DIR/.claude/.afc-active"
      echo "implement" > "$TEST_DIR/.claude/.afc-phase"
    }

    It "exits 0 and outputs additionalContext with pipeline info"
      Data '{"worktree_path":"/tmp/worktree-test"}'
      When run script scripts/afc-worktree-create.sh
      The status should eq 0
      The output should include "additionalContext"
      The output should include "AFC WORKTREE"
      The output should include "my-feature"
    End
  End

  Context "when pipeline is active but no worktree_path"
    setup() {
      setup_tmpdir TEST_DIR
      echo "my-feature" > "$TEST_DIR/.claude/.afc-active"
    }

    It "exits 0 with no output"
      Data '{}'
      When run script scripts/afc-worktree-create.sh
      The status should eq 0
      The output should eq ""
    End
  End
End
