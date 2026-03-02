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
    Context "intent detection"
      It "routes debug intent from bug keyword"
        Data '{"prompt":"there is a bug in the login flow"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:debug"
      End

      It "routes review intent"
        Data '{"prompt":"review this PR please"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:review"
      End

      It "routes test intent from write test keyword"
        Data '{"prompt":"write tests for the auth module"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:test"
      End

      It "routes analyze intent"
        Data '{"prompt":"analyze how the hook system works"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:analyze"
      End

      It "routes research intent"
        Data '{"prompt":"research the best testing framework"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:research"
      End

      It "routes implement intent"
        Data '{"prompt":"implement the new user profile feature"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:implement"
      End

      It "routes launch intent from release keyword"
        Data '{"prompt":"prepare a release with changelog"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:launch"
      End
    End

    Context "no match fallback"
      It "injects generic reminder for unmatched prompt"
        Data '{"prompt":"hello how are you"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc"
        The output should include "Skill tool"
        The output should not include "afc:route"
      End
    End

    Context "explicit slash command"
      It "exits silently for /afc: commands"
        Data '{"prompt":"/afc:debug fix the login"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should eq ""
      End
    End

    Context "task hygiene"
      It "includes task hygiene reminder in routed output"
        Data '{"prompt":"fix the broken test"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "TASK HYGIENE"
        The output should include "TaskUpdate"
      End

      It "includes task hygiene reminder in fallback output"
        Data '{"prompt":"hello"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "TASK HYGIENE"
      End
    End

    Context "empty input"
      It "exits 0 with generic reminder for empty prompt"
        Data '{}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc"
      End
    End
  End

  Context "when pipeline is active with implement phase"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "test-feature" "implement"
    }

    It "exits 0 and stdout contains Pipeline, Phase info and task hygiene"
      Data '{}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should include "test-feature"
      The output should include "implement"
      The output should include "TASK HYGIENE"
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

  Context "when pipeline is active with any prompt"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "test-feature" "implement"
    }

    It "does not inject routing hint when pipeline is active"
      Data '{"prompt":"analyze the code"}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should not include "afc:route"
      The output should include "test-feature"
      The output should include "implement"
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
