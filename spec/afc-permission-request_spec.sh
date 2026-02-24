#!/bin/bash
# shellcheck shell=bash


Describe "afc-permission-request.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when pipeline is inactive"
    It "exits 0 with no output"
      Data '{"tool_input":{"command":"npm test"}}'
      When run script scripts/afc-permission-request.sh
      The status should eq 0
      The output should eq ""
    End
  End

  Context "when in implement phase"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "test-feature" "implement"
    }

    It "allows npm test"
      Data '{"tool_input":{"command":"npm test"}}'
      When run script scripts/afc-permission-request.sh
      The status should eq 0
      The output should include '"behavior":"allow"'
    End

    It "allows shellcheck with a path"
      Data '{"tool_input":{"command":"shellcheck scripts/foo.sh"}}'
      When run script scripts/afc-permission-request.sh
      The status should eq 0
      The output should include '"behavior":"allow"'
    End

    It "produces no output for dangerous rm -rf /"
      Data '{"tool_input":{"command":"rm -rf /"}}'
      When run script scripts/afc-permission-request.sh
      The status should eq 0
      The output should eq ""
    End

    It "produces no output for command chaining with &&"
      Data '{"tool_input":{"command":"npm test && rm -rf /"}}'
      When run script scripts/afc-permission-request.sh
      The status should eq 0
      The output should eq ""
    End

    It "produces no output for command chaining with ;"
      Data '{"tool_input":{"command":"npm test; rm -rf /"}}'
      When run script scripts/afc-permission-request.sh
      The status should eq 0
      The output should eq ""
    End

    It "produces no output for redirect >"
      Data '{"tool_input":{"command":"shellcheck foo > /tmp/out"}}'
      When run script scripts/afc-permission-request.sh
      The status should eq 0
      The output should eq ""
    End

    It "produces no output for chmod +x with path traversal"
      Data '{"tool_input":{"command":"chmod +x ../../etc/evil.sh"}}'
      When run script scripts/afc-permission-request.sh
      The status should eq 0
      The output should eq ""
    End
  End

  Context "when in spec phase"
    setup() {
      setup_tmpdir TEST_DIR
      setup_state_fixture "$TEST_DIR" "test-feature" "spec"
    }

    It "produces no output (only implement/review phases apply)"
      Data '{"tool_input":{"command":"npm test"}}'
      When run script scripts/afc-permission-request.sh
      The status should eq 0
      The output should eq ""
    End
  End

  Context "dynamic whitelist from afc.config.md"
    Context "when config has pnpm commands"
      setup() {
        setup_tmpdir TEST_DIR
        setup_state_fixture "$TEST_DIR" "test-feature" "implement"
        cat > "$TEST_DIR/.claude/afc.config.md" << 'CFGEOF'
## CI Commands

```yaml
ci: "pnpm run lint"
gate: "pnpm run lint"
test: "pnpm test"
```
CFGEOF
      }

      It "allows pnpm run lint from dynamic whitelist"
        Data '{"tool_input":{"command":"pnpm run lint"}}'
        When run script scripts/afc-permission-request.sh
        The status should eq 0
        The output should include '"behavior":"allow"'
      End
    End

    Context "when config has npm commands"
      setup() {
        setup_tmpdir TEST_DIR
        setup_state_fixture "$TEST_DIR" "test-feature" "implement"
        setup_config_fixture "$TEST_DIR" "npm run lint"
      }

      It "allows yarn run lint as PM-agnostic variant"
        Data '{"tool_input":{"command":"yarn run lint"}}'
        When run script scripts/afc-permission-request.sh
        The status should eq 0
        The output should include '"behavior":"allow"'
      End
    End
  End
End
