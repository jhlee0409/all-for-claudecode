#!/bin/bash
# shellcheck shell=bash


Describe "afc-learner-collect.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when learner is not enabled"
    It "exits 0 with no output and no queue file"
      Data '{"prompt":"always use const"}'
      When run script scripts/afc-learner-collect.sh
      The status should eq 0
      The output should eq ""
      The path "$TEST_DIR/.claude/.afc-learner-queue.jsonl" should not be exist
    End
  End

  Context "when learner is enabled"
    setup() {
      setup_tmpdir TEST_DIR
      mkdir -p "$TEST_DIR/.claude/afc"
      printf '{"enabled":true}\n' > "$TEST_DIR/.claude/afc/learner.json"
    }

    Context "explicit preference signals"
      It "detects 'from now on' pattern"
        Data '{"prompt":"from now on always use tabs instead of spaces"}'
        When run script scripts/afc-learner-collect.sh
        The status should eq 0
        The output should eq ""
        The path "$TEST_DIR/.claude/.afc-learner-queue.jsonl" should be exist
        The contents of file "$TEST_DIR/.claude/.afc-learner-queue.jsonl" should include "explicit-preference"
      End

      It "detects Korean explicit preference"
        Data '{"prompt":"앞으로는 항상 const를 사용해"}'
        When run script scripts/afc-learner-collect.sh
        The status should eq 0
        The contents of file "$TEST_DIR/.claude/.afc-learner-queue.jsonl" should include "explicit-preference"
      End

      It "detects 'remember that' pattern"
        Data '{"prompt":"remember that we always run lint before commit"}'
        When run script scripts/afc-learner-collect.sh
        The status should eq 0
        The contents of file "$TEST_DIR/.claude/.afc-learner-queue.jsonl" should include "explicit-preference"
      End
    End

    Context "universal preference signals"
      It "detects 'always' at sentence start"
        Data '{"prompt":"always use named exports in React components"}'
        When run script scripts/afc-learner-collect.sh
        The status should eq 0
        The contents of file "$TEST_DIR/.claude/.afc-learner-queue.jsonl" should include "universal-preference"
      End

      It "detects 'never' at sentence start"
        Data '{"prompt":"never use default exports"}'
        When run script scripts/afc-learner-collect.sh
        The status should eq 0
        The contents of file "$TEST_DIR/.claude/.afc-learner-queue.jsonl" should include "universal-preference"
      End
    End

    Context "permanent correction signals"
      It "detects 'stop doing' pattern"
        Data '{"prompt":"stop using var declarations"}'
        When run script scripts/afc-learner-collect.sh
        The status should eq 0
        The contents of file "$TEST_DIR/.claude/.afc-learner-queue.jsonl" should include "permanent-correction"
      End

      It "detects Korean prohibition"
        Data '{"prompt":"let 쓰지마 항상 const 써"}'
        When run script scripts/afc-learner-collect.sh
        The status should eq 0
        The contents of file "$TEST_DIR/.claude/.afc-learner-queue.jsonl" should include "permanent-correction"
      End
    End

    Context "convention preference signals"
      It "detects 'use X instead of Y' pattern"
        Data '{"prompt":"use const instead of let"}'
        When run script scripts/afc-learner-collect.sh
        The status should eq 0
        The contents of file "$TEST_DIR/.claude/.afc-learner-queue.jsonl" should include "convention-preference"
      End

      It "detects 'prefer X over Y' pattern"
        Data '{"prompt":"prefer named exports over default exports"}'
        When run script scripts/afc-learner-collect.sh
        The status should eq 0
        The contents of file "$TEST_DIR/.claude/.afc-learner-queue.jsonl" should include "convention-preference"
      End
    End

    Context "no signal detected"
      It "does not create queue for task-specific redirection"
        Data '{"prompt":"no I meant the other file"}'
        When run script scripts/afc-learner-collect.sh
        The status should eq 0
        The path "$TEST_DIR/.claude/.afc-learner-queue.jsonl" should not be exist
      End

      It "does not create queue for normal conversation"
        Data '{"prompt":"add a function to parse the JSON response"}'
        When run script scripts/afc-learner-collect.sh
        The status should eq 0
        The path "$TEST_DIR/.claude/.afc-learner-queue.jsonl" should not be exist
      End
    End

    Context "edge cases"
      It "exits 0 on empty prompt"
        Data '{"prompt":""}'
        When run script scripts/afc-learner-collect.sh
        The status should eq 0
        The path "$TEST_DIR/.claude/.afc-learner-queue.jsonl" should not be exist
      End

      It "exits 0 on slash command"
        Data '{"prompt":"/afc:review always check for bugs"}'
        When run script scripts/afc-learner-collect.sh
        The status should eq 0
        The path "$TEST_DIR/.claude/.afc-learner-queue.jsonl" should not be exist
      End

      It "exits 0 on empty stdin"
        Data ""
        When run script scripts/afc-learner-collect.sh
        The status should eq 0
      End
    End

    Context "queue cap enforcement"
      setup() {
        setup_tmpdir TEST_DIR
        mkdir -p "$TEST_DIR/.claude/afc"
        printf '{"enabled":true}\n' > "$TEST_DIR/.claude/afc/learner.json"
        # Pre-fill queue to 50 entries
        for i in $(seq 1 50); do
          printf '{"signal_type":"test","category":"style","excerpt":"entry %d","timestamp":"2026-03-07T00:00:00Z","source":"standalone"}\n' "$i"
        done > "$TEST_DIR/.claude/.afc-learner-queue.jsonl"
      }

      It "does not append when queue is full"
        Data '{"prompt":"always use const"}'
        When run script scripts/afc-learner-collect.sh
        The status should eq 0
        # Queue should still be exactly 50 lines
        The contents of file "$TEST_DIR/.claude/.afc-learner-queue.jsonl" should not include "universal-preference"
      End
    End

    Context "secret redaction"
      It "redacts API key patterns in excerpt"
        Data '{"prompt":"always use token=sk-abc123 for auth"}'
        When run script scripts/afc-learner-collect.sh
        The status should eq 0
        The contents of file "$TEST_DIR/.claude/.afc-learner-queue.jsonl" should include "REDACTED"
        The contents of file "$TEST_DIR/.claude/.afc-learner-queue.jsonl" should not include "sk-abc123"
      End
    End

    Context "pipeline context tagging"
      setup() {
        setup_tmpdir TEST_DIR
        mkdir -p "$TEST_DIR/.claude/afc"
        printf '{"enabled":true}\n' > "$TEST_DIR/.claude/afc/learner.json"
        setup_state_fixture "$TEST_DIR" "auth-feature" "implement"
      }

      It "tags signal with pipeline context"
        Data '{"prompt":"from now on run tests before each commit"}'
        When run script scripts/afc-learner-collect.sh
        The status should eq 0
        The contents of file "$TEST_DIR/.claude/.afc-learner-queue.jsonl" should include "pipeline:auth-feature:implement"
      End
    End
  End
End
