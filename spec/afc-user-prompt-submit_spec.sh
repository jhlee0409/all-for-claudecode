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
    It "exits 0 and output is empty with no prompt"
      Data '{}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should eq ""
    End

    It "exits 0 and output is empty for short prompt"
      Data '{"prompt":"ㅇㅇ"}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should eq ""
    End

    It "exits 0 and output is empty when no keyword matches"
      Data '{"prompt":"hello there friend"}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should eq ""
    End

    It "does not false-positive on substrings like latest or prefix"
      Data '{"prompt":"explain the latest prefix contest"}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should eq ""
    End

    It "injects analyze routing hint for Korean analysis keyword"
      Data '{"prompt":"프로젝트 분석해줘"}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should include "AFC ROUTE"
      The output should include "afc:analyze"
    End

    It "injects source verify hint for analyze skill"
      Data '{"prompt":"analyze the API integration"}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should include "afc:analyze"
      The output should include "SOURCE VERIFY"
    End

    It "injects review routing hint for English keyword"
      Data '{"prompt":"review this PR please"}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should include "AFC ROUTE"
      The output should include "afc:review"
    End

    It "injects implement routing hint for Korean keyword"
      Data '{"prompt":"이 기능 구현해주세요"}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should include "afc:implement"
    End

    It "injects debug routing hint for error keyword"
      Data '{"prompt":"이 에러 좀 고쳐줘"}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should include "afc:debug"
    End

    It "injects research routing hint with source verify"
      Data '{"prompt":"research this library deeply"}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should include "afc:research"
      The output should include "SOURCE VERIFY"
    End

    It "injects plan routing hint for design keyword"
      Data '{"prompt":"how to implement auth flow"}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should include "afc:plan"
    End

    It "injects test routing hint"
      Data '{"prompt":"테스트 커버리지 높여줘"}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should include "afc:test"
    End

    It "injects spec routing hint"
      Data '{"prompt":"스펙 문서 작성해줘"}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should include "afc:spec"
    End

    It "injects ideate routing hint"
      Data '{"prompt":"아이디어 브레인스톰 해보자"}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should include "afc:ideate"
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

  Context "when pipeline is active with keyword in prompt"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "test-feature" "implement"
    }

    It "does not inject routing hint when pipeline is active"
      Data '{"prompt":"analyze the code"}'
      When run script scripts/afc-user-prompt-submit.sh
      The status should eq 0
      The output should not include "AFC ROUTE"
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
