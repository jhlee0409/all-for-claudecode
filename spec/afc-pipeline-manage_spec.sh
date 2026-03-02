#!/bin/bash
# shellcheck shell=bash


Describe "afc-pipeline-manage.sh"
  setup() {
    setup_tmpdir_with_git TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "start subcommand"
    It "exits 0 and creates state with feature name"
      When run script scripts/afc-pipeline-manage.sh start test-feature
      The status should eq 0
      The output should include "Pipeline started"
      The path "$TEST_DIR/.claude/.afc-state.json" should be exist
      The contents of file "$TEST_DIR/.claude/.afc-state.json" should include "test-feature"
    End

    It "strips special characters from feature name"
      When run script scripts/afc-pipeline-manage.sh start 'feat&"fix\test'
      The status should eq 0
      The output should include "Pipeline started"
      The contents of file "$TEST_DIR/.claude/.afc-state.json" should include "featfixtest"
    End
  End

  Context "phase subcommand"
    setup() {
      setup_tmpdir_with_git TEST_DIR
      setup_state_fixture "$TEST_DIR" "test-feature"
    }

    It "exits 0 and updates phase in state"
      When run script scripts/afc-pipeline-manage.sh phase plan
      The status should eq 0
      The output should include "Phase: plan"
      The contents of file "$TEST_DIR/.claude/.afc-state.json" should include "plan"
    End

    It "records phase checkpoint with timestamp"
      When run script scripts/afc-pipeline-manage.sh phase spec
      The status should eq 0
      The output should include "Phase: spec"
      The contents of file "$TEST_DIR/.claude/.afc-state.json" should include "phaseCheckpoints"
      The contents of file "$TEST_DIR/.claude/.afc-state.json" should include '"phase"'
    End

    It "resets promptCount on phase change"
      # Set a counter value first
      . scripts/afc-state.sh
      _AFC_STATE_DIR="$TEST_DIR/.claude"
      _AFC_STATE_FILE="$TEST_DIR/.claude/.afc-state.json"
      afc_state_write "promptCount" "42"
      When run script scripts/afc-pipeline-manage.sh phase review
      The status should eq 0
      The output should include "Phase: review"
      # Verify promptCount is exactly 0 (not just "42 is gone")
      The contents of file "$TEST_DIR/.claude/.afc-state.json" should include '"promptCount": 0'
    End

    Context "new phase names"
      It "accepts clarify phase"
        When run script scripts/afc-pipeline-manage.sh phase clarify
        The status should eq 0
        The output should include "Phase: clarify"
      End

      It "accepts test-pre-gen phase"
        When run script scripts/afc-pipeline-manage.sh phase test-pre-gen
        The status should eq 0
        The output should include "Phase: test-pre-gen"
      End

      It "accepts blast-radius phase"
        When run script scripts/afc-pipeline-manage.sh phase blast-radius
        The status should eq 0
        The output should include "Phase: blast-radius"
      End

      It "rejects invalid phase name"
        When run script scripts/afc-pipeline-manage.sh phase invalid-name
        The status should eq 1
        The stderr should include "Invalid phase"
      End
    End
  End

  Context "end subcommand"
    setup() {
      setup_tmpdir_with_git TEST_DIR
      setup_state_fixture "$TEST_DIR" "test-feature" "implement"
    }

    It "exits 0 and deletes state file"
      When run script scripts/afc-pipeline-manage.sh end
      The status should eq 0
      The output should include "Pipeline ended"
      The path "$TEST_DIR/.claude/.afc-state.json" should not be exist
    End
  End

  Context "ci-pass subcommand"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "test-feature"
    }

    It "exits 0 and records CI timestamp in state"
      When run script scripts/afc-pipeline-manage.sh ci-pass
      The status should eq 0
      The output should include "CI passed"
      The contents of file "$TEST_DIR/.claude/.afc-state.json" should include "ciPassedAt"
    End
  End

  Context "status subcommand"
    Context "when pipeline is active"
      setup() {
        setup_tmpdir TEST_DIR
        setup_state_fixture "$TEST_DIR" "status-feature" "implement"
      }

      It "exits 0 and outputs Active"
        When run script scripts/afc-pipeline-manage.sh status
        The status should eq 0
        The output should include "Active"
      End
    End

    Context "when pipeline is inactive"
      setup() {
        setup_tmpdir TEST_DIR
      }

      It "exits 0 and outputs No active"
        When run script scripts/afc-pipeline-manage.sh status
        The status should eq 0
        The output should include "No active"
      End
    End
  End

  Context "start when already active"
    setup() {
      setup_tmpdir_with_git TEST_DIR
      setup_state_fixture "$TEST_DIR" "existing-feature"
    }

    It "exits 1 with warning"
      When run script scripts/afc-pipeline-manage.sh start new-feature
      The status should eq 1
      The stderr should include "already active"
    End
  End

  Context "end --force when no active pipeline"
    setup() {
      setup_tmpdir_with_git TEST_DIR
    }

    It "exits 0 and cleans up"
      When run script scripts/afc-pipeline-manage.sh end --force
      The status should eq 0
      The output should include "Pipeline ended"
    End
  End

  Context "phase-tag subcommand"
    setup() {
      setup_tmpdir_with_git TEST_DIR
    }

    It "creates a git tag"
      When run script scripts/afc-pipeline-manage.sh phase-tag 1
      The status should eq 0
      The output should include "afc/phase-1"
    End
  End

  Context "phase-tag-clean subcommand"
    setup() {
      setup_tmpdir_with_git TEST_DIR
      (cd "$TEST_DIR" && git tag "afc/phase-1" && git tag "afc/phase-2")
    }

    It "removes all phase tags"
      When run script scripts/afc-pipeline-manage.sh phase-tag-clean
      The status should eq 0
      The output should include "Removed 2 phase tags"
    End
  End

  Context "unknown subcommand"
    setup() {
      setup_tmpdir_with_git TEST_DIR
    }

    It "exits 1 with usage"
      When run script scripts/afc-pipeline-manage.sh nonexistent
      The status should eq 1
      The stderr should include "Usage"
    End
  End
End
