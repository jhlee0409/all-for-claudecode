#!/bin/bash
# shellcheck shell=bash


Describe "track-afc-changes.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when pipeline is inactive"
    It "exits 0 and does not modify state"
      Data '{"tool_input":{"file_path":"/tmp/test.ts"}}'
      When run script scripts/track-afc-changes.sh
      The status should eq 0
    End
  End

  Context "when pipeline is active"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_with_ci "$TEST_DIR" "feature" "implement"
    }

    It "exits 0 and writes file path to state"
      Data '{"tool_input":{"file_path":"/tmp/test.ts"}}'
      When run script scripts/track-afc-changes.sh
      The status should eq 0
      The contents of file "$TEST_DIR/.claude/.afc-state.json" should include '/tmp/test.ts'
    End

    It "invalidates CI results after file change"
      Data '{"tool_input":{"file_path":"/tmp/changed.ts"}}'
      When run script scripts/track-afc-changes.sh
      The status should eq 0
      The contents of file "$TEST_DIR/.claude/.afc-state.json" should not include "ciPassedAt"
    End
  End

  Context "when stdin is empty"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "feature"
    }

    It "exits 0 gracefully"
      Data ''
      When run script scripts/track-afc-changes.sh
      The status should eq 0
    End
  End

  Context "when file_path is missing from input"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "feature"
    }

    It "exits 0 without modifying state"
      Data '{"tool_input":{"other_field":"value"}}'
      When run script scripts/track-afc-changes.sh
      The status should eq 0
    End
  End
End
