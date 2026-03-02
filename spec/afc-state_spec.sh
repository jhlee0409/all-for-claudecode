#!/bin/bash
# shellcheck shell=bash


Describe "afc-state.sh"
  Include scripts/afc-state.sh

  # Helper: re-initialize internal state paths after setup_tmpdir changes CLAUDE_PROJECT_DIR
  reinit_state_paths() {
    _AFC_STATE_DIR="${CLAUDE_PROJECT_DIR}/.claude"
    _AFC_STATE_FILE="${_AFC_STATE_DIR}/.afc-state.json"
  }

  setup() {
    setup_tmpdir TEST_DIR
    reinit_state_paths
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Describe "afc_state_is_active"
    Context "when state file does not exist"
      It "returns 1"
        When call afc_state_is_active
        The status should eq 1
      End
    End

    Context "when state file exists with valid JSON"
      setup() {
        setup_tmpdir TEST_DIR
        reinit_state_paths
        setup_state_fixture "$TEST_DIR" "test-feature" "implement"
      }

      It "returns 0"
        When call afc_state_is_active
        The status should eq 0
      End
    End

    Context "when state file is empty"
      setup() {
        setup_tmpdir TEST_DIR
        reinit_state_paths
        printf '' > "$TEST_DIR/.claude/.afc-state.json"
      }

      It "returns 1"
        When call afc_state_is_active
        The status should eq 1
      End
    End

    Context "when state file has no feature field"
      setup() {
        setup_tmpdir TEST_DIR
        reinit_state_paths
        printf '{"phase": "spec"}' > "$TEST_DIR/.claude/.afc-state.json"
      }

      It "returns 1"
        When call afc_state_is_active
        The status should eq 1
      End
    End

    Context "when feature is null (zombie state)"
      setup() {
        setup_tmpdir TEST_DIR
        reinit_state_paths
        printf '{"feature": null, "phase": "spec"}' > "$TEST_DIR/.claude/.afc-state.json"
      }

      It "returns 1"
        When call afc_state_is_active
        The status should eq 1
      End
    End

    Context "when feature is empty string (zombie state)"
      setup() {
        setup_tmpdir TEST_DIR
        reinit_state_paths
        printf '{"feature": "", "phase": "spec"}' > "$TEST_DIR/.claude/.afc-state.json"
      }

      It "returns 1"
        When call afc_state_is_active
        The status should eq 1
      End
    End
  End

  Describe "afc_state_read"
    Context "when state file does not exist"
      It "returns 1"
        When call afc_state_read "feature"
        The status should eq 1
      End
    End

    Context "when state file has the field"
      setup() {
        setup_tmpdir TEST_DIR
        reinit_state_paths
        setup_state_fixture "$TEST_DIR" "my-feature" "plan"
      }

      It "returns the feature value"
        When call afc_state_read "feature"
        The status should eq 0
        The output should eq "my-feature"
      End

      It "returns the phase value"
        When call afc_state_read "phase"
        The status should eq 0
        The output should eq "plan"
      End
    End

    Context "when field does not exist"
      setup() {
        setup_tmpdir TEST_DIR
        reinit_state_paths
        setup_state_fixture "$TEST_DIR" "my-feature" "spec"
      }

      It "returns 1"
        When call afc_state_read "nonexistent"
        The status should eq 1
      End
    End
  End

  Describe "afc_state_write"
    Context "when state file does not exist"
      It "creates the file and writes the field"
        When call afc_state_write "feature" "new-feature"
        The status should eq 0
        The path "$TEST_DIR/.claude/.afc-state.json" should be exist
      End
    End

    Context "when state file exists"
      setup() {
        setup_tmpdir TEST_DIR
        reinit_state_paths
        setup_state_fixture "$TEST_DIR" "old-feature" "spec"
      }

      It "updates an existing field"
        When call afc_state_write "phase" "implement"
        The status should eq 0
        The contents of file "$TEST_DIR/.claude/.afc-state.json" should include "implement"
      End

      It "adds a new field"
        When call afc_state_write "newField" "newValue"
        The status should eq 0
        The contents of file "$TEST_DIR/.claude/.afc-state.json" should include "newValue"
      End
    End
  End

  Describe "afc_state_init"
    It "creates a new state file with feature and phase"
      When call afc_state_init "test-feature"
      The status should eq 0
      The path "$TEST_DIR/.claude/.afc-state.json" should be exist
      The contents of file "$TEST_DIR/.claude/.afc-state.json" should include "test-feature"
      The contents of file "$TEST_DIR/.claude/.afc-state.json" should include "spec"
      The contents of file "$TEST_DIR/.claude/.afc-state.json" should include "startedAt"
    End
  End

  Describe "afc_state_delete"
    Context "when state file exists"
      setup() {
        setup_tmpdir TEST_DIR
        reinit_state_paths
        setup_state_fixture "$TEST_DIR" "test-feature" "implement"
      }

      It "removes the state file"
        When call afc_state_delete
        The status should eq 0
        The path "$TEST_DIR/.claude/.afc-state.json" should not be exist
      End
    End

    Context "when state file does not exist"
      It "succeeds silently"
        When call afc_state_delete
        The status should eq 0
      End
    End
  End

  Describe "afc_state_append_change"
    Context "when state file does not exist"
      It "returns 1"
        When call afc_state_append_change "src/foo.ts"
        The status should eq 1
      End
    End

    Context "when state file exists"
      setup() {
        setup_tmpdir TEST_DIR
        reinit_state_paths
        setup_state_fixture "$TEST_DIR" "test-feature" "implement"
      }

      It "appends a file path to changes array"
        When call afc_state_append_change "src/foo.ts"
        The status should eq 0
        The contents of file "$TEST_DIR/.claude/.afc-state.json" should include "src/foo.ts"
      End
    End
  End

  Describe "afc_state_ci_pass"
    setup() {
      setup_tmpdir TEST_DIR
      reinit_state_paths
      setup_state_fixture "$TEST_DIR" "test-feature" "implement"
    }

    It "records ciPassedAt timestamp"
      When call afc_state_ci_pass
      The status should eq 0
      The contents of file "$TEST_DIR/.claude/.afc-state.json" should include "ciPassedAt"
    End
  End

  Describe "afc_state_invalidate_ci"
    Context "when ciPassedAt exists"
      setup() {
        setup_tmpdir TEST_DIR
        reinit_state_paths
        setup_state_with_ci "$TEST_DIR" "test-feature" "implement"
      }

      It "removes ciPassedAt field from state file"
        When call afc_state_invalidate_ci
        The status should eq 0
        The contents of file "$TEST_DIR/.claude/.afc-state.json" should not include "ciPassedAt"
      End
    End
  End

  Describe "afc_state_remove"
    Context "when field exists"
      setup() {
        setup_tmpdir TEST_DIR
        reinit_state_paths
        setup_state_fixture "$TEST_DIR" "test-feature" "implement"
      }

      It "removes the specified field"
        When call afc_state_remove "phase"
        The status should eq 0
        The contents of file "$TEST_DIR/.claude/.afc-state.json" should not include '"phase"'
        The contents of file "$TEST_DIR/.claude/.afc-state.json" should include "test-feature"
      End
    End

    Context "when field does not exist"
      setup() {
        setup_tmpdir TEST_DIR
        reinit_state_paths
        setup_state_fixture "$TEST_DIR" "test-feature" "implement"
      }

      It "succeeds silently"
        When call afc_state_remove "nonexistent"
        The status should eq 0
        The contents of file "$TEST_DIR/.claude/.afc-state.json" should include "test-feature"
      End
    End

    Context "when state file does not exist"
      It "succeeds silently"
        When call afc_state_remove "anything"
        The status should eq 0
      End
    End
  End

  Describe "afc_state_read_changes"
    Context "when changes exist"
      setup() {
        setup_tmpdir TEST_DIR
        reinit_state_paths
        setup_state_fixture "$TEST_DIR" "test-feature" "implement"
        afc_state_append_change "src/foo.ts"
        afc_state_append_change "src/bar.ts"
      }

      It "returns all change entries"
        When call afc_state_read_changes
        The status should eq 0
        The output should include "src/foo.ts"
        The output should include "src/bar.ts"
      End
    End

    Context "when no changes exist"
      setup() {
        setup_tmpdir TEST_DIR
        reinit_state_paths
        setup_state_fixture "$TEST_DIR" "test-feature" "implement"
      }

      It "returns empty"
        When call afc_state_read_changes
        The output should eq ""
      End
    End

    Context "when state file does not exist"
      It "returns 1"
        When call afc_state_read_changes
        The status should eq 1
      End
    End
  End

  Describe "afc_state_append_change deduplication"
    Context "when same file appended twice"
      setup() {
        setup_tmpdir TEST_DIR
        reinit_state_paths
        setup_state_fixture "$TEST_DIR" "test-feature" "implement"
      }

      It "stores only one entry"
        When call eval 'afc_state_append_change "src/dup.ts"; afc_state_append_change "src/dup.ts"; afc_state_read_changes | grep -c "src/dup.ts"'
        The status should eq 0
        The output should eq "1"
      End
    End
  End

  Describe "afc_is_valid_phase"
    It "returns 0 for valid phase 'spec'"
      When call afc_is_valid_phase "spec"
      The status should eq 0
    End

    It "returns 0 for valid phase 'implement'"
      When call afc_is_valid_phase "implement"
      The status should eq 0
    End

    It "returns 1 for invalid phase"
      When call afc_is_valid_phase "nonexistent"
      The status should eq 1
    End
  End

  Describe "afc_is_ci_exempt"
    It "returns 0 for exempt phase 'spec'"
      When call afc_is_ci_exempt "spec"
      The status should eq 0
    End

    It "returns 0 for exempt phase 'clarify'"
      When call afc_is_ci_exempt "clarify"
      The status should eq 0
    End

    It "returns 1 for non-exempt phase 'implement'"
      When call afc_is_ci_exempt "implement"
      The status should eq 1
    End

    It "returns 1 for non-exempt phase 'review'"
      When call afc_is_ci_exempt "review"
      The status should eq 1
    End
  End

  Describe "afc_state_increment"
    Context "when state file does not exist"
      It "returns 1"
        When call afc_state_increment "promptCount"
        The status should eq 1
      End
    End

    Context "when state file exists with no counter"
      setup() {
        setup_tmpdir TEST_DIR
        reinit_state_paths
        setup_state_fixture "$TEST_DIR" "test-feature" "implement"
      }

      It "initializes counter to 1"
        When call afc_state_increment "promptCount"
        The status should eq 0
        The stdout should eq 1
      End
    End

    Context "when counter already exists"
      setup() {
        setup_tmpdir TEST_DIR
        reinit_state_paths
        setup_state_fixture "$TEST_DIR" "test-feature" "implement"
        afc_state_write "promptCount" "5"
      }

      It "increments by 1"
        When call afc_state_increment "promptCount"
        The status should eq 0
        The stdout should eq 6
      End
    End

    Context "when value is non-numeric"
      setup() {
        setup_tmpdir TEST_DIR
        reinit_state_paths
        setup_state_fixture "$TEST_DIR" "test-feature" "implement"
        afc_state_write "promptCount" "abc"
      }

      It "resets to 1"
        When call afc_state_increment "promptCount"
        The status should eq 0
        The stdout should eq 1
      End
    End

    Context "when called consecutively"
      setup() {
        setup_tmpdir TEST_DIR
        reinit_state_paths
        setup_state_fixture "$TEST_DIR" "test-feature" "implement"
      }

      It "increments correctly across two calls"
        When call eval 'afc_state_increment "promptCount" > /dev/null; afc_state_increment "promptCount"'
        The status should eq 0
        The stdout should eq 2
      End
    End
  End

  Describe "afc_state_checkpoint"
    Context "when state file does not exist"
      It "returns 1"
        When call afc_state_checkpoint "spec"
        The status should eq 1
      End
    End

    Context "when state file exists"
      setup() {
        setup_tmpdir_with_git TEST_DIR
        reinit_state_paths
        setup_state_fixture "$TEST_DIR" "test-feature" "implement"
      }

      It "records phase checkpoint"
        When call afc_state_checkpoint "implement"
        The status should eq 0
        The contents of file "$TEST_DIR/.claude/.afc-state.json" should include "phaseCheckpoints"
        The contents of file "$TEST_DIR/.claude/.afc-state.json" should include "implement"
      End
    End
  End
End
