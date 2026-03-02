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
    It "exits 0 and attempts notification"
      Data '{"notification_type":"idle_prompt","message":"Task completed successfully"}'
      When run script scripts/afc-notify.sh
      The status should eq 0
    End
  End

  Context "when notification_type is permission_prompt"
    It "exits 0 and attempts notification"
      Data '{"notification_type":"permission_prompt","message":"Permission needed"}'
      When run script scripts/afc-notify.sh
      The status should eq 0
    End
  End

  Context "when message is empty"
    It "exits 0 gracefully"
      Data '{"notification_type":"idle_prompt","message":""}'
      When run script scripts/afc-notify.sh
      The status should eq 0
    End
  End

  Context "when message contains special characters"
    It "exits 0 without injection"
      Data '{"notification_type":"idle_prompt","message":"test'\''s \"quoted\" & <special>"}'
      When run script scripts/afc-notify.sh
      The status should eq 0
    End
  End

  Context "when stdin is empty"
    It "exits 0 gracefully"
      Data ''
      When run script scripts/afc-notify.sh
      The status should eq 0
    End
  End
End
