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
    It "exits 0 and does not create changes log"
      Data '{"tool_input":{"file_path":"/tmp/test.ts"}}'
      When run script scripts/track-afc-changes.sh
      The status should eq 0
      The file "$TEST_DIR/.claude/.afc-changes.log" should not be exist
    End
  End

  Context "when pipeline is active"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "feature"
    }

    It "exits 0 and writes file path to state"
      Data '{"tool_input":{"file_path":"/tmp/test.ts"}}'
      When run script scripts/track-afc-changes.sh
      The status should eq 0
      The contents of file "$TEST_DIR/.claude/.afc-state.json" should include '/tmp/test.ts'
    End
  End
End
