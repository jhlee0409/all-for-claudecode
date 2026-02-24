#!/bin/bash
# shellcheck shell=bash


Describe "afc-auto-format.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when stdin is empty"
    It "exits 0 gracefully"
      Data ''
      When run script scripts/afc-auto-format.sh
      The status should eq 0
    End
  End

  Context "when input refers to a nonexistent file"
    It "exits 0 gracefully"
      Data '{"tool_input":{"file_path":"/nonexistent/path/file.ts"}}'
      When run script scripts/afc-auto-format.sh
      The status should eq 0
    End
  End
End
