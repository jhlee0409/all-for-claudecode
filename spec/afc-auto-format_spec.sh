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

  Context "when file_path is missing from input"
    It "exits 0 gracefully"
      Data '{"tool_input":{"other":"value"}}'
      When run script scripts/afc-auto-format.sh
      The status should eq 0
    End
  End

  Context "when file exists but no formatter is available"
    setup() {
      setup_tmpdir TEST_DIR
      printf 'fn main() {}\n' > "$TEST_DIR/test.rs"
    }

    It "exits 0 without error"
      Data "$(printf '{"tool_input":{"file_path":"%s/test.rs"}}' "$TEST_DIR")"
      When run script scripts/afc-auto-format.sh
      The status should eq 0
    End
  End

  Context "when .go file exists and gofmt is available"
    setup() {
      setup_tmpdir TEST_DIR
      printf 'package main\nfunc  main()  { }\n' > "$TEST_DIR/test.go"
    }

    It "exits 0 and processes the file"
      # gofmt is often available on dev machines; test the code path
      Skip if "gofmt not available" command -v gofmt
      Data "$(printf '{"tool_input":{"file_path":"%s/test.go"}}' "$TEST_DIR")"
      When run script scripts/afc-auto-format.sh
      The status should eq 0
    End
  End

  Context "when file extension does not match any formatter"
    setup() {
      setup_tmpdir TEST_DIR
      printf 'hello world\n' > "$TEST_DIR/test.txt"
    }

    It "exits 0 without attempting format"
      Data "$(printf '{"tool_input":{"file_path":"%s/test.txt"}}' "$TEST_DIR")"
      When run script scripts/afc-auto-format.sh
      The status should eq 0
    End
  End
End
