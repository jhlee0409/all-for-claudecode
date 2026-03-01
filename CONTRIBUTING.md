# Contributing to all-for-claudecode

Development guidelines for adding features, modifying behavior, upgrading, and maintaining the all-for-claudecode project.

## Project Map

```
commands/   markdown slash commands (the product surface)
scripts/    bash hook handlers (enforcement layer)
hooks/      hooks.json (event → handler binding)
agents/     subagent definitions (persistent memory + ephemeral workers)
docs/       shared reference documents
templates/  project preset configs
spec/       ShellSpec BDD test suite
bin/        ESM CLI installer
.claude-plugin/  plugin.json + marketplace.json
```

## Quick Reference: What to Change Where

| I want to... | Primary file(s) | Also update |
|---------------|-----------------|-------------|
| Add a new slash command | `commands/{name}.md` | README.md (table), `spec/{name}_spec.sh` if hooks involved |
| Add a new hook event | `hooks/hooks.json` + `scripts/{name}.sh` | README.md (table), `spec/{name}_spec.sh` |
| Modify config template | `templates/afc.config.template.md` | |
| Add a new agent | `agents/{name}.md` | |
| Modify pipeline flow | `commands/auto.md` | Related phase commands, `docs/phase-gate-protocol.md` |
| Change critic loop behavior | `docs/critic-loop-rules.md` | All commands that reference it |
| Update version | `package.json` + `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` |
| Change CLI installer | `bin/cli.mjs` | |

---

## 1. Adding a New Command

### Step 1: Create the command file

Create `commands/{name}.md` with required YAML frontmatter:

```yaml
---
name: afc:{name}
description: "Short description in English"
argument-hint: "[hint for arguments]"
model: haiku|sonnet          # haiku for mechanical, sonnet for design/analysis, omit for orchestrators
---
```

### Step 2: Choose invocation controls

| Control | Value | When to use |
|---------|-------|-------------|
| `user-invocable: false` | Hidden from `/` menu | Commands that should only be called by other commands (validate, clarify, tasks) |
| `context: fork` | Isolated subagent | Read-only analysis commands that should not affect main context (validate, analyze, architect, security) |

### Step 3: Choose allowed-tools (optional)

Only specify `allowed-tools` if the command should be restricted. Omit to allow all tools.

```yaml
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Task
```

### Step 4: Add hooks (optional)

Only if the command needs its own hooks (beyond the global hooks in hooks.json):

```yaml
hooks:
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/track-afc-changes.sh"
  Stop:
    - hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/afc-stop-gate.sh"
```

Note: Global hooks in `hooks/hooks.json` are always active. Command-level hooks in frontmatter should only be used when a command needs behavior that differs from the global hooks. Avoid duplicating global hooks in frontmatter (causes double execution).

### Step 5: Write the command body

Follow this structure:
```markdown
# /afc:{name} — {Title}

> One-line description of what this command does.

## Arguments
## Config Load (if needs project config)
## Execution Steps
### 1. {Step}
### 2. {Step}
### N. Final Output
## Notes
```

### Step 6: Update references

- **commands/auto.md**: If the new command is a pipeline phase, add it to the auto pipeline
- **Global CLAUDE.md all-for-claudecode block** (in `commands/init.md` template): Add to skill routing table if user-invocable
- **Tests**: Add test cases if the command involves hooks or scripts

### Naming conventions

- Command name: `afc:{kebab-case}` (e.g., `afc:code-gen`)
- File name: `commands/{kebab-case}.md` (e.g., `commands/code-gen.md`)
- Description: English, imperative or noun phrase

---

## 2. Adding a New Hook Script

### Step 1: Create the script

Create `scripts/{name}.sh` following the mandatory template:

```bash
#!/bin/bash
set -euo pipefail

cleanup() { :; }
trap cleanup EXIT

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Read stdin JSON
INPUT=$(cat)

# Parse with jq first, grep/sed fallback
if command -v jq &>/dev/null; then
    FIELD=$(printf '%s' "$INPUT" | jq -r '.field // empty')
else
    FIELD=$(printf '%s' "$INPUT" | grep -o '"field":"[^"]*"' | cut -d'"' -f4)
fi

# Your logic here

# Output response (varies by hook type)
printf '{"hookSpecificOutput":{"permissionDecision":"allow"}}\n'
```

### Step 2: Script conventions (mandatory)

1. `#!/bin/bash` + `set -euo pipefail`
2. `trap cleanup EXIT` with at minimum `:` placeholder
3. `${CLAUDE_PROJECT_DIR:-$(pwd)}` for project root
4. jq-first parsing with grep/sed fallback
5. Exit 0 on success; exit 2 for blocking hooks (Stop, TaskCompleted, ConfigChange, TeammateIdle)
6. `printf '%s\n' "$VAR"` instead of `echo "$VAR"` for external data
7. `# shellcheck disable=SCXXXX` for intentional suppressions

### Step 3: Response format by hook type

| Hook type | stdin | Response format |
|-----------|-------|-----------------|
| **PreToolUse** | `{ "tool_name": "...", "tool_input": {...} }` | `{"hookSpecificOutput":{"permissionDecision":"allow"}}` or `{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":"..."}}` |
| **PostToolUse** | `{ "tool_name": "...", "tool_input": {...}, "tool_output": "..." }` | `{"hookSpecificOutput":{"additionalContext":"..."}}` |
| **Stop** | `{}` | Exit 0 (allow) or exit 2 (block) |
| **TaskCompleted** | `{ "task_description": "..." }` | `{"ok":true}` or `{"ok":false,"reason":"..."}` |
| **UserPromptSubmit** | `{ "prompt": "..." }` | `{"hookSpecificOutput":{"additionalContext":"..."}}` |
| **PermissionRequest** | `{ "tool_name": "Bash", "command": "..." }` | `{"hookSpecificOutput":{"decision":{"behavior":"allow"}}}` |
| **SessionStart/End** | `{}` | stderr → user, stdout → Claude context |
| **Notification** | `{ "notification_type": "idle_prompt|permission_prompt", "message": "..." }` | OS notification (no stdout/stderr) |

### Step 4: Register in hooks.json

Add to `hooks/hooks.json` under the appropriate event:

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "pattern",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/{name}.sh\""
          }
        ]
      }
    ]
  }
}
```

- `matcher` is optional. Omit for universal hooks. Use regex for tool-specific hooks.
- `async: true` + `timeout: N` for non-blocking hooks (auto-format, notifications).
- Two handler types: `command` (shell), `prompt` (LLM single-turn).

### Step 5: Write tests

Create `spec/{name}_spec.sh` using ShellSpec BDD syntax:

```bash
#!/bin/bash
# shellcheck shell=bash


Describe "{name}.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when pipeline is inactive"
    It "exits 0 with no output"
      Data '{}'
      When run script scripts/{name}.sh
      The status should eq 0
    End
  End

  Context "when pipeline is active"
    setup() {
      setup_tmpdir TEST_DIR
      echo "feature-name" > "$TEST_DIR/.claude/.afc-active"
    }

    It "exits 0 and produces expected output"
      Data '{"key":"value"}'
      When run script scripts/{name}.sh
      The status should eq 0
      The output should include "expected"
    End
  End
End
```

Key testing patterns:
- `setup_tmpdir VAR_NAME` — creates isolated tmpdir, exports `CLAUDE_PROJECT_DIR` and `HOME` (named-variable pattern, NOT `VAR=$(setup_tmpdir)`)
- `setup_tmpdir_with_git VAR_NAME` — same + bare git repo
- `setup_config_fixture DIR [ci_cmd]` — writes minimal `afc.config.md` fixture
- `Data '{"json":"input"}'` — pipes stdin to the script under test
- `The path "$path" should be exist` — file/directory existence check
- `The contents of file "$path" should include "..."` — file content check
- ShellSpec handles non-zero exits automatically; use `The status should eq 2` for blocking hooks

---

## 3. Config Template

The config template at `templates/afc.config.template.md` uses free-form markdown with only CI Commands in fixed YAML format. The `/afc:init` command auto-analyzes the project structure and fills in sections dynamically — there is no preset/template selection system.

### Template structure

```markdown
# Project Configuration

## CI Commands

\`\`\`yaml
ci: "npm run ci"
gate: "npm run typecheck && npm run lint"
test: "npm test"
\`\`\`

## Architecture

(init analyzes your project and writes this section in free-form)

## Code Style

(init analyzes your project and writes this section in free-form)

## Project Context

(init analyzes your project and writes this section in free-form)
```

To modify the template, edit `templates/afc.config.template.md` directly. CI Commands keys (`ci`, `gate`, `test`) are parsed by scripts — keep their YAML format intact. All other sections are free-form markdown.

---

## 4. Adding a New Agent

### Step 1: Create the agent file

Create `agents/{name}.md`:

```yaml
---
name: afc-{name}
description: "Description of the agent's role and memory behavior"
tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Task
model: sonnet
memory: project
skills:
  - docs/critic-loop-rules.md
  - docs/phase-gate-protocol.md
---

# Agent body with instructions
```

Key properties:
- `memory: project` — persists memory across sessions in the project scope
- `isolation: worktree` — optional, runs in isolated worktree
- `skills` — reference shared docs that the agent should follow

### Step 2: Reference from a command

If the agent is used by a specific command:

```yaml
---
name: afc:{command}
context: fork
agent: afc-{name}
---
```

---

## 5. Modifying Pipeline Flow

The pipeline is `spec → plan → implement → review → clean` (tasks are auto-generated at implement start).

### Modifying a phase

1. Edit the standalone command in `commands/{phase}.md`
2. Mirror the changes in `commands/auto.md` (Phase N section)
3. If the phase gate behavior changed, update `docs/phase-gate-protocol.md`
4. If critic loop criteria changed, update `docs/critic-loop-rules.md`

### Adding a new phase

1. Create `commands/{phase}.md`
2. Update `commands/auto.md`:
   - Add the new phase section
   - Update phase numbering (e.g., `Phase N/7`)
   - Update the progress notification format
   - Add `afc-pipeline-manage.sh phase {name}` call
3. Update `scripts/afc-pipeline-manage.sh` to handle the new phase name
4. Update `CLAUDE.md` pipeline description
5. Update the all-for-claudecode block template in `commands/init.md`

### Modifying orchestration (implement phase)

The implement phase uses 3-tier orchestration:

| Mode | Trigger | Implementation |
|------|---------|----------------|
| Sequential | 0 [P] tasks | Direct execution |
| Parallel Batch | 1–5 [P] tasks | TaskCreate + addBlockedBy + parallel Task() calls |
| Swarm | 6+ [P] tasks | Orchestrator pre-assigns tasks to worker agents (no self-claiming) |

To modify:
- Batch/swarm thresholds: edit `commands/implement.md` Mode Selection table
- Worker behavior: edit the swarm worker prompt in `commands/implement.md`
- Auto pipeline integration: mirror changes in `commands/auto.md` Phase 3 (Implement)

---

## 6. Version Bump

Three files must always be in sync:

```
package.json                          → "version": "X.Y.Z"
.claude-plugin/plugin.json            → "version": "X.Y.Z"
.claude-plugin/marketplace.json       → "metadata.version": "X.Y.Z"
                                      → "plugins[0].version": "X.Y.Z"
```

Bump strategy:
- **Patch** (1.1.0 → 1.1.1): bug fixes, typo corrections, minor adjustments
- **Minor** (1.1.0 → 1.2.0): new commands, new hooks, new templates, behavior changes
- **Major** (1.1.0 → 2.0.0): breaking changes to command format, hook protocol, or config schema

After bumping, update `CHANGELOG.md`.

---

## 7. Plugin Cache Sync

After modifying source files, the plugin cache at `~/.claude/plugins/cache/all-for-claudecode/afc/{version}/` must be updated for changes to take effect in the current Claude Code session.

```bash
CACHE="$HOME/.claude/plugins/cache/all-for-claudecode/afc/$(jq -r .version package.json)"
SRC="$(pwd)"

# Sync specific files
cp "$SRC/commands/{file}.md" "$CACHE/commands/{file}.md"

# Or sync entire directories
cp -R "$SRC/commands/" "$CACHE/commands/"
cp -R "$SRC/scripts/" "$CACHE/scripts/"
cp -R "$SRC/hooks/" "$CACHE/hooks/"
cp "$SRC/CLAUDE.md" "$CACHE/CLAUDE.md"
```

**Important**: Cache sync is only needed during development. Users get fresh cache on install/update.

---

## 8. Testing

### Setup

```bash
npm run setup:test    # install ShellSpec 0.28.1 to vendor/shellspec/ (first-time only)
```

### Running tests

```bash
npm test              # ShellSpec BDD suite (vendor/shellspec/shellspec)
npm run lint          # shellcheck + schema validation + consistency check
npm run test:all      # lint + test combined
```

Single spec run: `vendor/shellspec/shellspec spec/afc-bash-guard_spec.sh`

### Test structure

Tests use [ShellSpec](https://shellspec.info/) BDD framework. Each script has a corresponding spec file in `spec/`:

```
spec/
  spec_helper.sh              # shared helpers (auto-loaded via .shellspec)
  afc-bash-guard_spec.sh      # spec for scripts/afc-bash-guard.sh
  afc-stop-gate_spec.sh       # spec for scripts/afc-stop-gate.sh
  ...
```

Shared helpers in `spec/spec_helper.sh`:
- `setup_tmpdir VAR_NAME` — creates isolated tmpdir, exports `CLAUDE_PROJECT_DIR` and `HOME`
- `setup_tmpdir_with_git VAR_NAME` — same + initializes bare git repo
- `setup_config_fixture DIR [ci_cmd]` — writes minimal `afc.config.md` fixture
- `cleanup_tmpdir "$VAR"` — removes tmpdir

### ShellSpec matchers reference

```bash
The status should eq 0                    # exit code check
The status should eq 2                    # blocking hook exit code
The output should include "text"          # stdout contains
The output should eq ""                   # stdout is empty
The stderr should include "text"          # stderr contains
The path "$path" should be exist          # file/dir exists
The path "$path" should not be exist      # file/dir does not exist
The contents of file "$path" should include "text"  # file content check
```

### Test requirements for new scripts

Every new script in `scripts/` must have a corresponding `spec/{name}_spec.sh` with:
1. At least 1 test for the happy path
2. At least 1 test for inactive pipeline (should be a no-op or passthrough)
3. At least 1 test for edge cases (empty stdin, missing files)
4. Explicit expectations for all stdout/stderr output (avoids ShellSpec warnings)

---

## 9. Documentation Rules

### Shared docs (`docs/`)

- `critic-loop-rules.md` — Referenced by all commands that run critic loops. Changes affect the entire pipeline.
- `phase-gate-protocol.md` — Referenced by `implement` and `auto`. Changes affect phase completion behavior.

**Rule**: Never duplicate these docs inline in commands. Always reference them with:
```markdown
> **Always** read `docs/critic-loop-rules.md` first and follow it.
```

### CLAUDE.md

- Describes project architecture for Claude Code sessions working on this repo
- Update whenever: new architectural pattern is introduced or layer structure changes
- Keep factual and concise — this is a reference, not a tutorial

### .claude/rules/

- `commands.md` — Rules for writing command files (frontmatter requirements)
- `shell-scripts.md` — Rules for writing shell scripts (conventions)
- `development.md` — General development rules (testing, version sync, etc.)
- These are auto-loaded by Claude Code and enforced during development

---

## 10. Common Pitfalls

### Forgetting cache sync
Source changes don't affect the running session until synced to `~/.claude/plugins/cache/`. Always sync after modifying commands, hooks, or scripts during development.

### hooks.json vs command-level hooks
- `hooks/hooks.json` — Global hooks, always active
- Command frontmatter `hooks:` — Only active when that specific command is running
- Don't duplicate the same hook in both places (causes double execution)

### Exit codes in hook scripts
- Exit 0 = success / allow
- Exit 2 = block the action (for Stop, TaskCompleted, ConfigChange, TeammateIdle)
- Exit 1 = error (treated as hook failure, not a block)

### Version mismatch
Plugin install fails silently if `plugin.json` version doesn't match `marketplace.json`. Always keep all 3 files in sync.

### Korean text in global project
This is a global open-source project. All user-facing text must be in English. Check before committing:
```bash
# Quick check for Korean characters in tracked files
git diff --cached --name-only | xargs grep -l '[가-힣]' 2>/dev/null
```

### Testing variable names
Use `setup_tmpdir TEST_DIR` (named-variable pattern), never `TEST_DIR=$(setup_tmpdir)` (subshell breaks `export` propagation). Never use `TMPDIR` as a variable name (conflicts with system environment variable).

### Destructive git commands during pipeline
The `afc-bash-guard.sh` hook blocks dangerous git commands (`push --force`, `reset --hard`, `clean -f`) when the pipeline is active. Rollback commands targeting `afc/pre-*` tags are whitelisted.

---

## 11. Release Checklist

1. All tests pass: `npm run test:all`
2. Version bumped in all 3 files (package.json, plugin.json, marketplace.json)
3. CHANGELOG.md updated
4. No Korean text in any tracked file
5. All command frontmatter follows conventions (model, description, controls)
6. New scripts have shellcheck passing
7. New scripts have ShellSpec coverage in spec/{name}_spec.sh
8. CLAUDE.md reflects current architecture
9. Commit and tag: `git tag v{X.Y.Z}`
10. Push: `git push origin main --tags`
