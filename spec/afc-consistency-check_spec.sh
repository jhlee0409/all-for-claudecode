Describe "afc-consistency-check.sh"
  SCRIPT="$SHELLSPEC_PROJECT_ROOT/scripts/afc-consistency-check.sh"

  setup_project_fixture() {
    local dir="$1"
    mkdir -p "$dir/skills/spec" "$dir/skills/init" "$dir/agents" "$dir/hooks" "$dir/scripts" \
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

    # Skill referencing config and agent (name matches valid phase 'spec')
    cat > "$dir/skills/spec/SKILL.md" << 'CMD'
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

    # README.md with command table entries
    cat > "$dir/README.md" << 'README'
# Test Project
| `/afc:spec` | Write spec |
| `/afc:init` | Project setup |
README

    # CLAUDE.md with fork list
    cat > "$dir/CLAUDE.md" << 'CLAUDEMD'
# Architecture
- `context: fork` — runs in isolated subagent (validate, analyze, qa, architect, security)
CLAUDEMD

    # init/SKILL.md with skill routing
    cat > "$dir/skills/init/SKILL.md" << 'INIT'
---
name: afc:init
---
| Specification | `afc:spec` | spec command |
INIT

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
      printf '{config.nonexistent}\n' >> "$DIR2/skills/spec/SKILL.md"
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
      printf 'subagent_type: "afc:afc-missing-agent"\n' >> "$DIR3/skills/spec/SKILL.md"
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

  Describe "when command is missing from README.md"
    setup_tmpdir DIR9
    BeforeAll "setup_project_fixture $DIR9"
    AfterAll "cleanup_tmpdir $DIR9"

    It "warns on undocumented skill"
      mkdir -p "$DIR9/skills/unknown-phase"
      cat > "$DIR9/skills/unknown-phase/SKILL.md" << 'CMD'
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
      The stderr should include "missing from README.md"
    End
  End

  Describe "when unprefixed subagent_type is used"
    setup_tmpdir DIR8
    BeforeAll "setup_project_fixture $DIR8"
    AfterAll "cleanup_tmpdir $DIR8"

    It "fails on subagent_type without afc: prefix"
      mkdir -p "$DIR8/skills/bad-cmd"
      cat > "$DIR8/skills/bad-cmd/SKILL.md" << 'CMD'
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

  Describe "when user-invocable command is missing from init.md"
    setup_tmpdir DIR10
    BeforeAll "setup_project_fixture $DIR10"
    AfterAll "cleanup_tmpdir $DIR10"

    It "warns on missing init/SKILL.md routing"
      mkdir -p "$DIR10/skills/newcmd"
      cat > "$DIR10/skills/newcmd/SKILL.md" << 'CMD'
---
name: afc:newcmd
description: "New command"
---
New command body
CMD
      printf '| `/afc:newcmd` | New |\n' >> "$DIR10/README.md"
      When run bash "$SCRIPT" "$DIR10"
      The status should eq 0
      The output should include "Done"
      The stderr should include "newcmd"
      The stderr should include "missing from init/SKILL.md"
    End
  End

  Describe "when context:fork command is missing from CLAUDE.md"
    setup_tmpdir DIR11
    BeforeAll "setup_project_fixture $DIR11"
    AfterAll "cleanup_tmpdir $DIR11"

    It "warns on missing CLAUDE.md fork list entry"
      mkdir -p "$DIR11/skills/newfork"
      cat > "$DIR11/skills/newfork/SKILL.md" << 'CMD'
---
name: afc:newfork
description: "New fork command"
context: fork
user-invocable: false
---
Fork command body
CMD
      printf '| `/afc:newfork` | New fork |\n' >> "$DIR11/README.md"
      When run bash "$SCRIPT" "$DIR11"
      The status should eq 0
      The output should include "Done"
      The stderr should include "newfork"
      The stderr should include "missing from CLAUDE.md fork list"
    End
  End

  Describe "when dynamic template pattern is used in subagent_type"
    setup_tmpdir DIR13
    BeforeAll "setup_project_fixture $DIR13"
    AfterAll "cleanup_tmpdir $DIR13"

    It "skips dynamic template patterns like afc-{domain}-expert"
      mkdir -p "$DIR13/skills/auto"
      cat > "$DIR13/skills/auto/SKILL.md" << 'CMD'
---
name: afc:auto
description: "Auto pipeline"
---
Task("consult", subagent_type: "afc:afc-{domain}-expert")
Task("test", subagent_type: "afc:afc-test-agent")
CMD
      printf '| `/afc:auto` | Auto |\n' >> "$DIR13/README.md"
      printf '| Auto | `afc:auto` | auto |\n' >> "$DIR13/skills/init/SKILL.md"
      When run bash "$SCRIPT" "$DIR13"
      The status should eq 0
      The output should include "Agent names:"
      The output should include "0 errors"
    End
  End

  Describe "when all command docs are present including fork and non-invocable"
    setup_tmpdir DIR12
    BeforeAll "setup_project_fixture $DIR12"
    AfterAll "cleanup_tmpdir $DIR12"

    It "passes with no warnings for documented skills"
      # Add a context:fork skill properly documented in all places
      mkdir -p "$DIR12/skills/analyze" "$DIR12/skills/hidden"
      cat > "$DIR12/skills/analyze/SKILL.md" << 'CMD'
---
name: afc:analyze
description: "Analysis command"
context: fork
---
Analysis body
CMD
      printf '| `/afc:analyze` | Analysis |\n' >> "$DIR12/README.md"
      printf '| Analyze | `afc:analyze` | analysis |\n' >> "$DIR12/skills/init/SKILL.md"
      # Add analyze to CLAUDE.md fork list
      printf '%s\n' '- `context: fork` — runs in subagent (validate, analyze, qa, architect, security)' > "$DIR12/CLAUDE.md"
      # Add a user-invocable:false skill (should NOT require init/SKILL.md entry)
      cat > "$DIR12/skills/hidden/SKILL.md" << 'CMD'
---
name: afc:hidden
description: "Hidden command"
user-invocable: false
---
Hidden body
CMD
      printf '| `/afc:hidden` | Hidden |\n' >> "$DIR12/README.md"
      When run bash "$SCRIPT" "$DIR12"
      The status should eq 0
      The output should include "Skill docs: all skills referenced"
      The output should include "0 errors, 0 warnings"
    End
  End
End
