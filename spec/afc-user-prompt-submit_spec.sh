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

      It "routes review intent from code review keyword"
        Data '{"prompt":"please do a code review of this PR"}'
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

      It "routes launch intent from changelog keyword"
        Data '{"prompt":"generate the changelog for this release"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:launch"
      End

      It "routes security intent from security scan keyword"
        Data '{"prompt":"run a security scan on the codebase"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:security"
      End

      It "routes security intent from security audit keyword"
        Data '{"prompt":"perform a security audit of the project"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:security"
      End

      It "routes architect intent"
        Data '{"prompt":"review the system design and architecture"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:architect"
      End

      It "routes doctor intent"
        Data '{"prompt":"run a health check on the project"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:doctor"
      End

      It "routes qa intent"
        Data '{"prompt":"run a quality audit on the project"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:qa"
      End

      It "routes spec intent from specification keyword"
        Data '{"prompt":"write a specification for the auth feature"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:spec"
      End

      It "routes ideate intent from brainstorm keyword"
        Data '{"prompt":"brainstorm ideas for the new dashboard"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:ideate"
      End

      It "routes consult intent from expert advice keyword"
        Data '{"prompt":"I need expert advice on database design"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:consult"
      End

      It "routes consult intent from discuss keyword"
        Data '{"prompt":"let us discuss the API design approach"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:consult"
      End

      It "routes consult intent from think together keyword"
        Data '{"prompt":"think together about the best approach"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:consult"
      End

      It "routes triage intent"
        Data '{"prompt":"triage the open PRs and issues"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:triage"
      End

      It "routes release-notes intent"
        Data '{"prompt":"generate release notes for this version"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:release-notes"
      End

      It "routes clean intent"
        Data '{"prompt":"clean up the pipeline artifacts"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:clean"
      End

      It "routes auto intent for new feature request"
        Data '{"prompt":"build a feature for user notifications"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:auto"
      End
    End

    Context "Korean language intent detection"
      It "routes debug intent from Korean keyword"
        Data '{"prompt":"로그인에서 버그가 발생합니다"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:debug"
      End

      It "routes debug intent from Korean error keyword"
        Data '{"prompt":"API에서 에러가 납니다"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:debug"
      End

      It "routes review intent from Korean keyword"
        Data '{"prompt":"이 PR 코드리뷰 해주세요"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:review"
      End

      It "routes test intent from Korean keyword"
        Data '{"prompt":"인증 모듈 테스트 작성해줘"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:test"
      End

      It "routes security intent from Korean keyword"
        Data '{"prompt":"보안 검사 실행해줘"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:security"
      End

      It "routes architect intent from Korean keyword"
        Data '{"prompt":"시스템 설계 검토해줘"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:architect"
      End

      It "routes spec intent from Korean keyword"
        Data '{"prompt":"요구사항 정의해줘"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:spec"
      End

      It "routes consult intent from Korean keyword"
        Data '{"prompt":"데이터베이스 설계에 대해 조언 구합니다"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:consult"
      End

      It "routes analyze intent from Korean keyword"
        Data '{"prompt":"훅 시스템 코드 분석해줘"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:analyze"
      End

      It "routes research intent from Korean keyword"
        Data '{"prompt":"테스팅 프레임워크 리서치해줘"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:research"
      End

      It "routes auto intent from Korean new feature request"
        Data '{"prompt":"새 기능 만들어줘 사용자 알림"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:auto"
      End

      It "routes implement intent from Korean refactor keyword"
        Data '{"prompt":"인증 모듈 리팩터링 해줘"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:implement"
      End

      It "routes launch intent from Korean release keyword"
        Data '{"prompt":"릴리스 준비해줘"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:launch"
      End

      It "routes plan intent from Korean keyword"
        Data '{"prompt":"구현 계획 세워줘"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:plan"
      End
    End

    Context "natural language variants (English)"
      It "routes debug from fix keyword"
        Data '{"prompt":"fix the OAuth token expiry issue"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:debug"
      End

      It "routes debug from error keyword"
        Data '{"prompt":"getting an error when submitting the form"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:debug"
      End

      It "routes test from unit test keyword"
        Data '{"prompt":"add unit tests for the payment service"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:test"
      End

      It "routes auto from create feature keyword"
        Data '{"prompt":"create a feature for user onboarding flow"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:auto"
      End

      It "routes consult from advice keyword"
        Data '{"prompt":"I need advice on the caching strategy"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:route"
        The output should include "afc:consult"
      End
    End

    Context "false positive guards"
      It "does not route to debug for 안전 keyword (operational safety)"
        Data '{"prompt":"동작 안전 모드 설명해줘"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should not include "afc:debug"
      End

      It "does not route to debug for generic Korean greeting"
        Data '{"prompt":"안녕하세요 도움이 필요합니다"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should not include "afc:debug"
      End
    End

    Context "priority ordering"
      It "debug takes priority over review when both match"
        Data '{"prompt":"review the bug fix in the login"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:debug"
        The output should not include "afc:review"
      End
    End

    Context "no match fallback"
      It "injects generic reminder for unmatched prompt"
        Data '{"prompt":"hello how are you"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "[afc] Route via Skill tool"
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

    Context "no task hygiene in inactive mode"
      It "does not include TASK HYGIENE in routed output"
        Data '{"prompt":"there is a crash in the app"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "afc:debug"
        The output should not include "TASK HYGIENE"
      End

      It "does not include TASK HYGIENE in fallback output"
        Data '{"prompt":"hello"}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should not include "TASK HYGIENE"
      End
    End

    Context "empty input"
      It "exits 0 with generic reminder for empty prompt"
        Data '{}'
        When run script scripts/afc-user-prompt-submit.sh
        The status should eq 0
        The output should include "[afc] Route via Skill tool"
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
