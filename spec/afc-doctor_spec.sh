#!/bin/bash
# shellcheck shell=bash


Describe "afc-doctor.sh"
  setup() {
    setup_tmpdir TEST_DIR
    # Create minimal plugin structure for hook health checks
    mkdir -p "$SHELLSPEC_PROJECT_ROOT/hooks"
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "with minimal healthy setup"
    setup() {
      setup_tmpdir TEST_DIR
      setup_config_fixture "$TEST_DIR"
    }

    It "runs and exits 0"
      When run script scripts/afc-doctor.sh
      The status should eq 0
      The output should include "Environment"
      The output should include "Results:"
    End
  End

  Context "when config file is missing"
    It "reports failure for missing config"
      When run script scripts/afc-doctor.sh
      The status should eq 0
      The output should include "afc.config.md not found"
    End
  End

  Context "when zombie state exists"
    setup() {
      setup_tmpdir TEST_DIR
      setup_config_fixture "$TEST_DIR"
      printf '{"feature": null, "phase": "spec"}' > "$TEST_DIR/.claude/.afc-state.json"
    }

    It "reports zombie state"
      When run script scripts/afc-doctor.sh
      The status should eq 0
      The output should include "Zombie state"
    End
  End

  Context "with active pipeline"
    setup() {
      setup_tmpdir TEST_DIR
      setup_config_fixture "$TEST_DIR"
      setup_state_fixture "$TEST_DIR" "test-feature" "implement"
    }

    It "reports active pipeline as warning"
      When run script scripts/afc-doctor.sh
      The status should eq 0
      The output should include "Active pipeline"
      The output should include "test-feature"
    End
  End

  Context "in dev repo with version sync"
    setup() {
      setup_tmpdir TEST_DIR
      setup_config_fixture "$TEST_DIR"
      # Simulate dev repo
      printf '{"name": "all-for-claudecode", "version": "2.5.0"}' > "$TEST_DIR/package.json"
      mkdir -p "$TEST_DIR/.claude-plugin"
      printf '{"version": "2.5.0"}' > "$TEST_DIR/.claude-plugin/plugin.json"
      printf '{"metadata": {"version": "2.5.0"}, "plugins": [{"version": "2.5.0"}]}' > "$TEST_DIR/.claude-plugin/marketplace.json"
    }

    It "checks version triple match"
      When run script scripts/afc-doctor.sh
      The status should eq 0
      The output should include "Version Sync"
      The output should include "Version triple match"
    End
  End

  Context "in dev repo with version mismatch"
    setup() {
      setup_tmpdir TEST_DIR
      setup_config_fixture "$TEST_DIR"
      printf '{"name": "all-for-claudecode", "version": "2.5.0"}' > "$TEST_DIR/package.json"
      mkdir -p "$TEST_DIR/.claude-plugin"
      printf '{"version": "2.4.0"}' > "$TEST_DIR/.claude-plugin/plugin.json"
      printf '{"metadata": {"version": "2.5.0"}, "plugins": [{"version": "2.5.0"}]}' > "$TEST_DIR/.claude-plugin/marketplace.json"
    }

    It "reports version mismatch"
      When run script scripts/afc-doctor.sh
      The status should eq 0
      The output should include "Version mismatch"
    End
  End

  Context "with --verbose flag"
    setup() {
      setup_tmpdir TEST_DIR
      setup_config_fixture "$TEST_DIR"
    }

    It "runs with verbose output"
      When run script scripts/afc-doctor.sh --verbose
      The status should eq 0
      The output should include "Environment"
    End
  End

  Context "hooks health"
    setup() {
      setup_tmpdir TEST_DIR
      setup_config_fixture "$TEST_DIR"
    }

    It "validates hooks.json"
      When run script scripts/afc-doctor.sh
      The status should eq 0
      The output should include "Hook Health"
      The output should include "hooks.json"
    End
  End
End
