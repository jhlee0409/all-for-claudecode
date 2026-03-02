#!/bin/bash
# shellcheck shell=bash


Describe "afc-sync-cache.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when cache directory does not exist"
    It "exits with error"
      When run script scripts/afc-sync-cache.sh
      The status should eq 1
      The stderr should include "Cache directory not found"
    End
  End

  Context "when cache directory exists"
    setup() {
      setup_tmpdir TEST_DIR
      # Read actual version from package.json
      local ver
      if command -v jq >/dev/null 2>&1; then
        ver=$(jq -r '.version' "$SHELLSPEC_PROJECT_ROOT/package.json")
      else
        ver=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$SHELLSPEC_PROJECT_ROOT/package.json" | head -1 | sed 's/.*: *"//;s/"//')
      fi
      # Create fake cache dir with minimal structure
      mkdir -p "$TEST_DIR/.claude/plugins/cache/all-for-claudecode/afc/$ver/commands"
      mkdir -p "$TEST_DIR/.claude/plugins/cache/all-for-claudecode/afc/$ver/scripts"
    }

    It "syncs files to cache and reports success"
      When run script scripts/afc-sync-cache.sh
      The status should eq 0
      The output should include "Synced source to cache"
    End

    It "copies commands files to cache directory"
      When run script scripts/afc-sync-cache.sh
      The status should eq 0
      The output should include "Synced"
      # Verify at least one known file was synced
      local ver
      ver=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$SHELLSPEC_PROJECT_ROOT/package.json" | head -1 | sed 's/.*: *"//;s/"//')
      The path "$TEST_DIR/.claude/plugins/cache/all-for-claudecode/afc/$ver/commands/auto.md" should be exist
    End

    It "copies scripts files to cache directory"
      When run script scripts/afc-sync-cache.sh
      The status should eq 0
      The output should include "Synced"
      local ver
      ver=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$SHELLSPEC_PROJECT_ROOT/package.json" | head -1 | sed 's/.*: *"//;s/"//')
      The path "$TEST_DIR/.claude/plugins/cache/all-for-claudecode/afc/$ver/scripts/afc-state.sh" should be exist
    End
  End
End
