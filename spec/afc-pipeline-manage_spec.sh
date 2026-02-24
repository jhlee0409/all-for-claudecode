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
    It "exits 0 and creates .afc-active with feature name"
      When run script scripts/afc-pipeline-manage.sh start test-feature
      The status should eq 0
      The output should include "Pipeline started"
      The path "$TEST_DIR/.claude/.afc-active" should be exist
      The contents of file "$TEST_DIR/.claude/.afc-active" should include "test-feature"
    End
  End

  Context "phase subcommand"
    setup() {
      setup_tmpdir_with_git TEST_DIR
      echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
    }

    It "exits 0 and updates .afc-phase"
      When run script scripts/afc-pipeline-manage.sh phase plan
      The status should eq 0
      The output should include "Phase: plan"
      The contents of file "$TEST_DIR/.claude/.afc-phase" should include "plan"
    End
  End

  Context "end subcommand"
    setup() {
      setup_tmpdir_with_git TEST_DIR
      echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
      echo "implement" > "$TEST_DIR/.claude/.afc-phase"
    }

    It "exits 0 and deletes pipeline flags"
      When run script scripts/afc-pipeline-manage.sh end
      The status should eq 0
      The output should include "Pipeline ended"
      The path "$TEST_DIR/.claude/.afc-active" should not be exist
    End
  End

  Context "ci-pass subcommand"
    setup() {
      setup_tmpdir TEST_DIR
      echo "test-feature" > "$TEST_DIR/.claude/.afc-active"
    }

    It "exits 0 and creates .afc-ci-passed"
      When run script scripts/afc-pipeline-manage.sh ci-pass
      The status should eq 0
      The output should include "CI passed"
      The path "$TEST_DIR/.claude/.afc-ci-passed" should be exist
    End
  End

  Context "status subcommand"
    Context "when pipeline is active"
      setup() {
        setup_tmpdir TEST_DIR
        echo "status-feature" > "$TEST_DIR/.claude/.afc-active"
        echo "implement" > "$TEST_DIR/.claude/.afc-phase"
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
