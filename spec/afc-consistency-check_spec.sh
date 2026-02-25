Describe "afc-consistency-check.sh"
  SCRIPT="$SHELLSPEC_PROJECT_ROOT/scripts/afc-consistency-check.sh"

  setup_project_fixture() {
    local dir="$1"
    mkdir -p "$dir/commands" "$dir/agents" "$dir/hooks" "$dir/scripts" \
             "$dir/templates" "$dir/docs" "$dir/spec" "$dir/schemas" \
             "$dir/.claude-plugin"

    # Minimal config template
    cat > "$dir/templates/afc.config.template.md" << 'TMPL'
# Config
## CI Commands
```yaml
ci: "npm run ci"
gate: "npm run lint"
test: "npm test"
```
## Architecture
## Code Style
## Project Context
TMPL

    # Agent definition
    cat > "$dir/agents/afc-test-agent.md" << 'AGENT'
---
name: afc-test-agent
---
Test agent
AGENT

    # Command referencing config and agent (name matches valid phase 'spec')
    cat > "$dir/commands/spec.md" << 'CMD'
---
name: afc:spec
description: "Test command"
---
Use {config.ci} and {config.architecture}
Task("test", subagent_type: "afc:afc-test-agent")
CMD

    # Valid hooks.json
    cat > "$dir/hooks/hooks.json" << 'HOOKS'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/afc-hook.sh\"" }
        ]
      }
    ]
  }
}
HOOKS

    # Referenced hook script
    cat > "$dir/scripts/afc-hook.sh" << 'SCRIPT'
#!/bin/bash
set -euo pipefail
cleanup() { :; }
trap cleanup EXIT
exit 0
SCRIPT

    # Copy shared library
    cp "$SHELLSPEC_PROJECT_ROOT/scripts/afc-state.sh" "$dir/scripts/afc-state.sh"

    # Matching spec file
    touch "$dir/spec/afc-hook_spec.sh"

    # Version files (all matching)
    printf '{"version": "1.0.0"}\n' > "$dir/package.json"
    printf '{"name": "test", "version": "1.0.0", "description": "test"}\n' > "$dir/.claude-plugin/plugin.json"
    printf '{"metadata": {"version": "1.0.0"}, "plugins": [{"version": "1.0.0"}]}\n' > "$dir/.claude-plugin/marketplace.json"
  }

  Describe "when all checks pass"
    setup_tmpdir DIR
    BeforeAll "setup_project_fixture $DIR"
    AfterAll "cleanup_tmpdir $DIR"

    It "exits 0 with all checks passing"
      When run bash "$SCRIPT" "$DIR"
      The status should eq 0
      The output should include "0 errors"
    End
  End

  Describe "when config placeholder is invalid"
    setup_tmpdir DIR2
    BeforeAll "setup_project_fixture $DIR2"
    AfterAll "cleanup_tmpdir $DIR2"

    It "fails on undefined {config.nonexistent}"
      printf '{config.nonexistent}\n' >> "$DIR2/commands/spec.md"
      When run bash "$SCRIPT" "$DIR2"
      The status should eq 1
      The output should include "Done"
      The stderr should include "{config.nonexistent}"
    End
  End

  Describe "when agent name is inconsistent"
    setup_tmpdir DIR3
    BeforeAll "setup_project_fixture $DIR3"
    AfterAll "cleanup_tmpdir $DIR3"

    It "fails on missing agent definition"
      printf 'subagent_type: "afc:afc-missing-agent"\n' >> "$DIR3/commands/spec.md"
      When run bash "$SCRIPT" "$DIR3"
      The status should eq 1
      The output should include "Done"
      The stderr should include "afc-missing-agent"
    End
  End

  Describe "when hook script is missing"
    setup_tmpdir DIR4
    BeforeAll "setup_project_fixture $DIR4"
    AfterAll "cleanup_tmpdir $DIR4"

    It "fails on missing script file"
      cat > "$DIR4/hooks/hooks.json" << 'HOOKS'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/afc-missing.sh\"" }
        ]
      }
    ]
  }
}
HOOKS
      When run bash "$SCRIPT" "$DIR4"
      The status should eq 1
      The output should include "Done"
      The stderr should include "afc-missing.sh"
    End
  End

  Describe "when versions mismatch"
    setup_tmpdir DIR5
    BeforeAll "setup_project_fixture $DIR5"
    AfterAll "cleanup_tmpdir $DIR5"

    It "fails on version mismatch"
      printf '{"version": "9.9.9"}\n' > "$DIR5/package.json"
      When run bash "$SCRIPT" "$DIR5"
      The status should eq 1
      The output should include "Done"
      The stderr should include "Version mismatch"
    End
  End

  Describe "when test spec is missing"
    setup_tmpdir DIR6
    BeforeAll "setup_project_fixture $DIR6"
    AfterAll "cleanup_tmpdir $DIR6"

    It "fails on missing spec file"
      cat > "$DIR6/scripts/afc-orphan.sh" << 'SCRIPT'
#!/bin/bash
set -euo pipefail
cleanup() { :; }
trap cleanup EXIT
exit 0
SCRIPT
      When run bash "$SCRIPT" "$DIR6"
      The status should eq 1
      The output should include "Done"
      The stderr should include "afc-orphan.sh"
    End
  End

  Describe "when hardcoded phase list exists"
    setup_tmpdir DIR7
    BeforeAll "setup_project_fixture $DIR7"
    AfterAll "cleanup_tmpdir $DIR7"

    It "fails on hardcoded phase list in scripts"
      cat > "$DIR7/scripts/afc-bad-gate.sh" << 'SCRIPT'
#!/bin/bash
case "$PHASE" in
  spec|plan|tasks|implement|review|clean)
    exit 0
    ;;
esac
SCRIPT
      touch "$DIR7/spec/afc-bad-gate_spec.sh"
      When run bash "$SCRIPT" "$DIR7"
      The status should eq 1
      The output should include "Done"
      The stderr should include "hardcoded phase list"
    End
  End

  Describe "when command name is not a valid phase and not in non-phase list"
    setup_tmpdir DIR9
    BeforeAll "setup_project_fixture $DIR9"
    AfterAll "cleanup_tmpdir $DIR9"

    It "warns on unrecognized command name"
      cat > "$DIR9/commands/unknown-phase.md" << 'CMD'
---
name: afc:unknown-phase
description: "Unknown"
---
Unknown phase command
CMD
      When run bash "$SCRIPT" "$DIR9"
      The status should eq 0
      The output should include "Done"
      The stderr should include "unknown-phase"
      The stderr should include "not a recognized phase"
    End
  End

  Describe "when unprefixed subagent_type is used"
    setup_tmpdir DIR8
    BeforeAll "setup_project_fixture $DIR8"
    AfterAll "cleanup_tmpdir $DIR8"

    It "fails on subagent_type without afc: prefix"
      cat > "$DIR8/commands/bad-cmd.md" << 'CMD'
---
name: afc:bad-cmd
description: "Bad"
---
Task("test", subagent_type: "afc-test-agent")
CMD
      When run bash "$SCRIPT" "$DIR8"
      The status should eq 1
      The output should include "Done"
      The stderr should include "should use"
    End
  End
End
