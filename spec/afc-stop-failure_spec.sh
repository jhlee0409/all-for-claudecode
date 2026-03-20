#!/bin/bash
# shellcheck shell=bash


Describe "afc-stop-failure.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when error is rate_limit"
    It "exits 0 and outputs rate limit message to stderr"
      Data '{"error":"rate_limit","session_id":"abc123"}'
      When run script scripts/afc-stop-failure.sh
      The status should eq 0
      The stderr should include "[afc] Rate limit reached"
      The stderr should include "30-60 seconds"
    End
  End

  Context "when error is authentication_failed"
    It "exits 0 and outputs authentication message to stderr"
      Data '{"error":"authentication_failed","session_id":"abc123"}'
      When run script scripts/afc-stop-failure.sh
      The status should eq 0
      The stderr should include "[afc] Authentication failed"
      The stderr should include "gh auth login"
    End
  End

  Context "when error is server_error"
    It "exits 0 and outputs server error message to stderr"
      Data '{"error":"server_error","session_id":"abc123"}'
      When run script scripts/afc-stop-failure.sh
      The status should eq 0
      The stderr should include "[afc] API server error"
      The stderr should include "temporary"
    End
  End

  Context "when error is an unknown type"
    It "exits 0 and outputs fallback message with error to stderr"
      Data '{"error":"connection_timeout","session_id":"abc123"}'
      When run script scripts/afc-stop-failure.sh
      The status should eq 0
      The stderr should include "[afc] API error:"
      The stderr should include "connection_timeout"
      The stderr should include "Check Claude Code status"
    End
  End

  Context "when error field is absent"
    It "exits 0 with no stderr output"
      Data '{"session_id":"abc123"}'
      When run script scripts/afc-stop-failure.sh
      The status should eq 0
      The stderr should eq ""
    End
  End

  Context "when stdin is empty JSON object"
    It "exits 0 with no stderr output"
      Data '{}'
      When run script scripts/afc-stop-failure.sh
      The status should eq 0
      The stderr should eq ""
    End
  End

  Context "when error contains rate limit phrase"
    It "exits 0 and outputs rate limit message"
      Data '{"error":"Rate limit exceeded for model","session_id":"xyz"}'
      When run script scripts/afc-stop-failure.sh
      The status should eq 0
      The stderr should include "[afc] Rate limit reached"
    End
  End

  Context "when error is internal_server_error"
    It "exits 0 and outputs server error message"
      Data '{"error":"internal_server_error","session_id":"xyz"}'
      When run script scripts/afc-stop-failure.sh
      The status should eq 0
      The stderr should include "[afc] API server error"
    End
  End
End
