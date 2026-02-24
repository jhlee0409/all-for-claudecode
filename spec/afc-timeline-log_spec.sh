#!/bin/bash
# shellcheck shell=bash


Describe "afc-timeline-log.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when missing required arguments"
    It "exits 0 gracefully"
      When run script scripts/afc-timeline-log.sh
      The status should eq 0
      The stderr should include "Usage"
    End
  End

  Context "when logging an event"
    It "exits 0 and creates timeline file"
      When run script scripts/afc-timeline-log.sh pipeline-start "Test pipeline started"
      The status should eq 0
      The path "$TEST_DIR/.claude/.afc-timeline.jsonl" should be exist
    End

    It "appends a valid JSONL line with event and message"
      When run script scripts/afc-timeline-log.sh gate-pass "Phase 1 gate passed"
      The status should eq 0
      The contents of file "$TEST_DIR/.claude/.afc-timeline.jsonl" should include "gate-pass"
      The contents of file "$TEST_DIR/.claude/.afc-timeline.jsonl" should include "Phase 1 gate passed"
    End
  End

  Context "when pipeline is active"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "my-feature" "implement"
    }

    It "includes feature and phase in the log entry"
      When run script scripts/afc-timeline-log.sh phase-end "implement complete"
      The status should eq 0
      The contents of file "$TEST_DIR/.claude/.afc-timeline.jsonl" should include "my-feature"
      The contents of file "$TEST_DIR/.claude/.afc-timeline.jsonl" should include "implement"
    End
  End
End
