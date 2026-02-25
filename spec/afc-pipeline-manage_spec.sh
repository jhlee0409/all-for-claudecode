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
End
