#!/bin/bash
# shellcheck shell=bash


Describe "afc-subagent-stop.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when pipeline is inactive"
    It "exits 0 without creating log file"
      Data '{"stop_hook_active":false,"agent_id":"agent-1","agent_type":"worker","last_assistant_message":"done"}'
      When run script scripts/afc-subagent-stop.sh
      The status should eq 0
      The file "$TEST_DIR/.claude/.afc-task-results.log" should not be exist
    End
  End

  Context "when stop_hook_active is true"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "feature-name"
    }

    It "exits 0 without creating log file"
      Data '{"stop_hook_active":true,"agent_id":"agent-1","agent_type":"worker","last_assistant_message":"done"}'
      When run script scripts/afc-subagent-stop.sh
      The status should eq 0
      The file "$TEST_DIR/.claude/.afc-task-results.log" should not be exist
    End
  End

  Context "when pipeline is active and stop_hook_active is false"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "feature-name"
    }

    It "exits 0 and creates task-results.log with agent_id and agent_type"
      Data '{"stop_hook_active":false,"agent_id":"agent-42","agent_type":"impl-worker","last_assistant_message":"task complete"}'
      When run script scripts/afc-subagent-stop.sh
      The status should eq 0
      The file "$TEST_DIR/.claude/.afc-task-results.log" should be exist
      The contents of file "$TEST_DIR/.claude/.afc-task-results.log" should include 'agent-42'
      The contents of file "$TEST_DIR/.claude/.afc-task-results.log" should include 'impl-worker'
    End
  End

  Context "when pipeline is active and message is empty"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "feature-name"
    }

    It "exits 0 and logs no message default"
      Data '{"stop_hook_active":false,"agent_id":"agent-99","agent_type":"worker"}'
      When run script scripts/afc-subagent-stop.sh
      The status should eq 0
      The file "$TEST_DIR/.claude/.afc-task-results.log" should be exist
      The contents of file "$TEST_DIR/.claude/.afc-task-results.log" should include 'no message'
    End
  End
End
