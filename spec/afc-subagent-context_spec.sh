#!/bin/bash
# shellcheck shell=bash


Describe "afc-subagent-context.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when pipeline is inactive"
    It "exits 0 and produces no output"
      Data '{}'
      When run script scripts/afc-subagent-context.sh
      The status should eq 0
      The output should eq ""
    End
  End

  Context "when pipeline is active in implement phase"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "subagent-test" "implement"
    }

    It "exits 0 and includes Feature and Phase in output"
      Data '{}'
      When run script scripts/afc-subagent-context.sh
      The status should eq 0
      The output should include "Feature: subagent-test"
      The output should include "Phase: implement"
    End

    It "includes AFC routing rule in output"
      Data '{}'
      When run script scripts/afc-subagent-context.sh
      The status should eq 0
      The output should include "[AFC]"
      The output should include "Skill tool"
      The output should include "official documentation"
    End
  End

  Context "when config has Project Context section"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "ctx-test" "implement"
      mkdir -p "$TEST_DIR/.claude"
      cat > "$TEST_DIR/.claude/afc.config.md" << 'CFGEOF'
## CI Commands

```yaml
ci: "npm test"
gate: "npm test"
test: "npm test"
```

## Architecture

FSD architecture with strict layer rules.

## Code Style

TypeScript strict mode.

## Project Context

Next.js 14 App Router. Zustand for state. Tailwind CSS.
CFGEOF
    }

    It "includes Project Context in output"
      Data '{}'
      When run script scripts/afc-subagent-context.sh
      The status should eq 0
      The output should include "Project Context:"
      The output should include "Next.js"
    End
  End
End
