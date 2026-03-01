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

  Context "checkpoint file creation"
    It "creates checkpoint in project-local memory directory"
      Data '{}'
      When run script scripts/pre-compact-checkpoint.sh
      The status should eq 0
      The output should include "Auto-checkpoint saved"
      The path "$TEST_DIR/.claude/afc/memory/checkpoint.md" should be exist
    End
  End

  Context "checkpoint content includes git info"
    It "contains branch name"
      Data '{}'
      When run script scripts/pre-compact-checkpoint.sh
      The status should eq 0
      The output should include "Auto-checkpoint saved"
      The contents of file "$TEST_DIR/.claude/afc/memory/checkpoint.md" should include "Branch:"
    End

    It "contains commit hash"
      Data '{}'
      When run script scripts/pre-compact-checkpoint.sh
      The status should eq 0
      The output should include "Auto-checkpoint saved"
      The contents of file "$TEST_DIR/.claude/afc/memory/checkpoint.md" should include "Commit:"
    End

    It "contains modified files count"
      Data '{}'
      When run script scripts/pre-compact-checkpoint.sh
      The status should eq 0
      The output should include "Auto-checkpoint saved"
      The contents of file "$TEST_DIR/.claude/afc/memory/checkpoint.md" should include "Modified files:"
    End

    It "contains staged files section"
      Data '{}'
      When run script scripts/pre-compact-checkpoint.sh
      The status should eq 0
      The output should include "Auto-checkpoint saved"
      The contents of file "$TEST_DIR/.claude/afc/memory/checkpoint.md" should include "Staged Files"
    End
  End

  Context "when files are modified in git"
    setup() {
      setup_tmpdir_with_git TEST_DIR
      # Create and commit a file first, then modify it (tracked file)
      echo "original" > "$TEST_DIR/tracked-file.txt"
      (cd "$TEST_DIR" && git add tracked-file.txt && git commit -q -m "add tracked file")
      echo "changed" > "$TEST_DIR/tracked-file.txt"
    }

    It "reports modified file in checkpoint"
      Data '{}'
      When run script scripts/pre-compact-checkpoint.sh
      The status should eq 0
      The output should include "Auto-checkpoint saved"
      The contents of file "$TEST_DIR/.claude/afc/memory/checkpoint.md" should include "Modified files: 1"
    End
  End

  Context "when files are staged in git"
    setup() {
      setup_tmpdir_with_git TEST_DIR
      echo "staged" > "$TEST_DIR/staged-file.txt"
      (cd "$TEST_DIR" && git add staged-file.txt)
    }

    It "reports staged file count"
      Data '{}'
      When run script scripts/pre-compact-checkpoint.sh
      The status should eq 0
      The output should include "Auto-checkpoint saved"
      The contents of file "$TEST_DIR/.claude/afc/memory/checkpoint.md" should include "Staged Files (1)"
    End
  End

  Context "when pipeline is inactive"
    It "shows pipeline as inactive in checkpoint"
      Data '{}'
      When run script scripts/pre-compact-checkpoint.sh
      The status should eq 0
      The output should include "pipeline: inactive"
      The contents of file "$TEST_DIR/.claude/afc/memory/checkpoint.md" should include "Active: No"
    End
  End

  Context "when pipeline is active"
    setup() {
      setup_tmpdir_with_git TEST_DIR
      setup_state_fixture "$TEST_DIR" "my-feature" "implement"
    }

    It "shows pipeline feature name in checkpoint"
      Data '{}'
      When run script scripts/pre-compact-checkpoint.sh
      The status should eq 0
      The output should include "pipeline: my-feature"
      The contents of file "$TEST_DIR/.claude/afc/memory/checkpoint.md" should include "Active: Yes (my-feature)"
    End
  End

  Context "when tasks.md exists with progress"
    setup() {
      setup_tmpdir_with_git TEST_DIR
      setup_state_fixture "$TEST_DIR" "test-feature" "implement"
      mkdir -p "$TEST_DIR/.claude/afc/specs/test-feature"
      cat > "$TEST_DIR/.claude/afc/specs/test-feature/tasks.md" << 'TASKS'
## Tasks
- [x] Task 1
- [x] Task 2
- [ ] Task 3
TASKS
    }

    It "reports task progress in checkpoint"
      Data '{}'
      When run script scripts/pre-compact-checkpoint.sh
      The status should eq 0
      The output should include "Auto-checkpoint saved"
      The contents of file "$TEST_DIR/.claude/afc/memory/checkpoint.md" should include "Task progress: 2/3"
    End
  End

  Context "when no tasks.md exists"
    It "reports 0/0 task progress"
      Data '{}'
      When run script scripts/pre-compact-checkpoint.sh
      The status should eq 0
      The output should include "Auto-checkpoint saved"
      The contents of file "$TEST_DIR/.claude/afc/memory/checkpoint.md" should include "Task progress: 0/0"
    End
  End

  Context "checkpoint contains restore command"
    It "includes /afc:resume command"
      Data '{}'
      When run script scripts/pre-compact-checkpoint.sh
      The status should eq 0
      The output should include "Auto-checkpoint saved"
      The contents of file "$TEST_DIR/.claude/afc/memory/checkpoint.md" should include "/afc:resume"
    End
  End
End
