#!/bin/bash
# shellcheck shell=bash


Describe "afc-notify.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when notification_type is unknown"
    It "exits 0 immediately"
      Data '{"notification_type":"unknown_type","message":"some message"}'
      When run script scripts/afc-notify.sh
      The status should eq 0
    End
  End

  Context "when notification_type is idle_prompt"
    It "exits 0 even if notification delivery fails"
      Data '{"notification_type":"idle_prompt","message":"Task completed successfully"}'
      When run script scripts/afc-notify.sh
      The status should eq 0
    End
  End
End
