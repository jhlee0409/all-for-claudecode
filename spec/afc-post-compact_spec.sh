#!/bin/bash
# shellcheck shell=bash


Describe "afc-post-compact.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when pipeline is inactive"
    It "exits 0 and produces no output"
      Data '{"compact_summary":"summary","trigger":"auto","session_id":"abc"}'
      When run script scripts/afc-post-compact.sh
      The status should eq 0
      The output should eq ""
    End
  End

  Context "when pipeline is active with context.md"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "my-feature" "implement"
      mkdir -p "$TEST_DIR/.claude/afc/specs/my-feature"
      cat > "$TEST_DIR/.claude/afc/specs/my-feature/context.md" << 'CTXEOF'
## Summary
This is the spec summary.

## Plan Decisions
- Decision 1: use React
- Decision 2: use TypeScript

## Advisor Results
No advisors invoked.
CTXEOF
    }

    It "exits 0 and includes restored marker in output"
      Data '{"compact_summary":"summary","trigger":"auto","session_id":"abc"}'
      When run script scripts/afc-post-compact.sh
      The status should eq 0
      The output should include "[afc:restored]"
    End

    It "includes feature name in output"
      Data '{"compact_summary":"summary","trigger":"manual","session_id":"abc"}'
      When run script scripts/afc-post-compact.sh
      The status should eq 0
      The output should include "Pipeline: my-feature"
    End

    It "includes phase in output"
      Data '{"compact_summary":"summary","trigger":"auto","session_id":"abc"}'
      When run script scripts/afc-post-compact.sh
      The status should eq 0
      The output should include "Phase: implement"
    End

    It "includes context.md content in output"
      Data '{"compact_summary":"summary","trigger":"auto","session_id":"abc"}'
      When run script scripts/afc-post-compact.sh
      The status should eq 0
      The output should include "spec summary"
    End

    It "outputs hookSpecificOutput JSON wrapper"
      Data '{"compact_summary":"summary","trigger":"auto","session_id":"abc"}'
      When run script scripts/afc-post-compact.sh
      The status should eq 0
      The output should include "hookSpecificOutput"
      The output should include "additionalContext"
    End
  End

  Context "when pipeline is active without context.md"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "no-context-feature" "plan"
    }

    It "exits 0 and includes restored marker"
      Data '{"compact_summary":"summary","trigger":"auto","session_id":"abc"}'
      When run script scripts/afc-post-compact.sh
      The status should eq 0
      The output should include "[afc:restored]"
    End

    It "includes feature name in output"
      Data '{"compact_summary":"summary","trigger":"auto","session_id":"abc"}'
      When run script scripts/afc-post-compact.sh
      The status should eq 0
      The output should include "Pipeline: no-context-feature"
    End

    It "falls back to no context.md message"
      Data '{"compact_summary":"summary","trigger":"auto","session_id":"abc"}'
      When run script scripts/afc-post-compact.sh
      The status should eq 0
      The output should include "no context.md"
    End
  End
End
