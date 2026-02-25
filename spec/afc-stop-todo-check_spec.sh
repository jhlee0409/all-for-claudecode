#!/bin/bash
# shellcheck shell=bash


Describe "afc-stop-todo-check.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when pipeline is inactive"
    It "exits 0 immediately (zero overhead)"
      Data '{}'
      When run script scripts/afc-stop-todo-check.sh
      The status should eq 0
    End
  End

  Context "when pipeline is active in spec phase"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "feature-name" "spec"
    }

    It "exits 0 for spec phase (CI-exempt)"
      Data '{}'
      When run script scripts/afc-stop-todo-check.sh
      The status should eq 0
    End
  End

  Context "when pipeline is active in implement phase with no changes"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "feature-name" "implement"
    }

    It "exits 0 when no changed files tracked"
      Data '{}'
      When run script scripts/afc-stop-todo-check.sh
      The status should eq 0
    End
  End

  Context "when pipeline is active in implement phase with clean files"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "feature-name" "implement"
      # Add a change entry and create a clean file
      printf '{"feature":"feature-name","phase":"implement","startedAt":1000,"changes":["src/clean.ts"]}\n' > "$TEST_DIR/.claude/.afc-state.json"
      mkdir -p "$TEST_DIR/src"
      printf 'const x = 1;\n' > "$TEST_DIR/src/clean.ts"
    }

    It "exits 0 when changed files have no TODO/FIXME"
      Data '{}'
      When run script scripts/afc-stop-todo-check.sh
      The status should eq 0
    End
  End

  Context "when pipeline is active in implement phase with TODO markers"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "feature-name" "implement"
      printf '{"feature":"feature-name","phase":"implement","startedAt":1000,"changes":["src/dirty.ts"]}\n' > "$TEST_DIR/.claude/.afc-state.json"
      mkdir -p "$TEST_DIR/src"
      printf 'const x = 1; // TODO: fix this\n' > "$TEST_DIR/src/dirty.ts"
    }

    It "exits 2 blocking stop"
      Data '{}'
      When run script scripts/afc-stop-todo-check.sh
      The status should eq 2
      The stderr should include "[afc:todo-check]"
      The stderr should include "TODO"
    End
  End

  Context "when pipeline is active in review phase with FIXME markers"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "feature-name" "review"
      printf '{"feature":"feature-name","phase":"review","startedAt":1000,"changes":["src/broken.ts"]}\n' > "$TEST_DIR/.claude/.afc-state.json"
      mkdir -p "$TEST_DIR/src"
      printf 'function foo() { // FIXME: handle edge case\n  return null;\n}\n' > "$TEST_DIR/src/broken.ts"
    }

    It "exits 2 blocking stop for FIXME"
      Data '{}'
      When run script scripts/afc-stop-todo-check.sh
      The status should eq 2
      The stderr should include "FIXME"
    End
  End

  Context "when stop_hook_active is true"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "feature-name" "implement"
      printf '{"feature":"feature-name","phase":"implement","startedAt":1000,"changes":["src/dirty.ts"]}\n' > "$TEST_DIR/.claude/.afc-state.json"
      mkdir -p "$TEST_DIR/src"
      printf 'const x = 1; // TODO: fix this\n' > "$TEST_DIR/src/dirty.ts"
    }

    It "exits 0 to prevent infinite loop"
      Data '{"stop_hook_active":true}'
      When run script scripts/afc-stop-todo-check.sh
      The status should eq 0
    End
  End
End
