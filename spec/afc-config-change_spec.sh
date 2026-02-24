#!/bin/bash
# shellcheck shell=bash


Describe "afc-config-change.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when pipeline is inactive"
    It "exits 0 without creating audit log"
      Data '{"source":"user_settings","file_path":"/some/path"}'
      When run script scripts/afc-config-change.sh
      The status should eq 0
    End
  End

  Context "when pipeline is active and source is policy_settings"
    setup() {
      setup_tmpdir TEST_DIR
      echo "feature-name" > "$TEST_DIR/.claude/.afc-active"
    }

    It "exits 0 and creates audit log with policy_settings"
      Data '{"source":"policy_settings","file_path":"/policy/settings.json"}'
      When run script scripts/afc-config-change.sh
      The status should eq 0
      The file "$TEST_DIR/.claude/.afc-config-audit.log" should be exist
      The contents of file "$TEST_DIR/.claude/.afc-config-audit.log" should include 'policy_settings'
    End
  End

  Context "when pipeline is active and source is user_settings"
    setup() {
      setup_tmpdir TEST_DIR
      echo "feature-name" > "$TEST_DIR/.claude/.afc-active"
    }

    It "exits 2 and creates audit log with user_settings"
      Data '{"source":"user_settings","file_path":"/user/settings.json"}'
      When run script scripts/afc-config-change.sh
      The status should eq 2
      The stderr should include "AFC CONFIG"
      The file "$TEST_DIR/.claude/.afc-config-audit.log" should be exist
      The contents of file "$TEST_DIR/.claude/.afc-config-audit.log" should include 'user_settings'
    End
  End
End
