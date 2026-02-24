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
      echo "feature" > "$TEST_DIR/.claude/.afc-active"
    }

    It "exits 0 and writes file path to changes log"
      Data '{"tool_input":{"file_path":"/tmp/test.ts"}}'
      When run script scripts/track-afc-changes.sh
      The status should eq 0
      The file "$TEST_DIR/.claude/.afc-changes.log" should be exist
      The contents of file "$TEST_DIR/.claude/.afc-changes.log" should include '/tmp/test.ts'
    End
  End
End
