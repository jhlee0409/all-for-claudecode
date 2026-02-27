#!/bin/bash
# shellcheck shell=bash


Describe "afc-user-prompt-submit.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when pipeline is inactive"
    It "exits 0 and output is empty"
      Data '{}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should eq ""
    End
  End

  Context "when pipeline is active with implement phase"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "test-feature" "implement"
    }

    It "exits 0 and stdout contains Pipeline and Phase info"
      Data '{}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should include "test-feature"
      The output should include "implement"
    End
  End

  Context "when pipeline is active and prompt count reaches threshold"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "test-feature" "implement"
      # Set counter to 49 so next call is 50 (threshold)
      . scripts/afc-state.sh
      _AFC_STATE_DIR="$TEST_DIR/.claude"
      _AFC_STATE_FILE="$TEST_DIR/.claude/.afc-state.json"
      afc_state_write "promptCount" "49"
    }

    It "injects drift checkpoint at 50 prompts"
      Data '{}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should include "DRIFT CHECKPOINT"
      The output should include "50 prompts"
    End
  End

  Context "when pipeline is active and counter below threshold"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "test-feature" "implement"
      . scripts/afc-state.sh
      _AFC_STATE_DIR="$TEST_DIR/.claude"
      _AFC_STATE_FILE="$TEST_DIR/.claude/.afc-state.json"
      afc_state_write "promptCount" "10"
    }

    It "does not inject drift checkpoint"
      Data '{}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should not include "DRIFT CHECKPOINT"
    End
  End

  Context "when pipeline is active and prompt count reaches second threshold"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "test-feature" "implement"
      . scripts/afc-state.sh
      _AFC_STATE_DIR="$TEST_DIR/.claude"
      _AFC_STATE_FILE="$TEST_DIR/.claude/.afc-state.json"
      afc_state_write "promptCount" "99"
    }

    It "injects drift checkpoint at 100 prompts"
      Data '{}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should include "DRIFT CHECKPOINT"
      The output should include "100 prompts"
    End
  End

  Context "when pipeline is active in spec phase at threshold"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "test-feature" "spec"
      . scripts/afc-state.sh
      _AFC_STATE_DIR="$TEST_DIR/.claude"
      _AFC_STATE_FILE="$TEST_DIR/.claude/.afc-state.json"
      afc_state_write "promptCount" "49"
    }

    It "does not inject drift checkpoint in spec phase"
      Data '{}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should not include "DRIFT CHECKPOINT"
    End
  End

  Context "when pipeline is active but no phase field"
    setup() {
      setup_tmpdir TEST_DIR
      # State with feature only, no phase field
      mkdir -p "$TEST_DIR/.claude"
      printf '{"feature": "test-feature", "startedAt": %s}\n' "$(date +%s)" > "$TEST_DIR/.claude/.afc-state.json"
    }

    It "exits 0 and stdout contains Phase: unknown"
      Data '{}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should include "unknown"
    End
  End
End
