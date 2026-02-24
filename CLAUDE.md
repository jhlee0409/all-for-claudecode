# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build / Lint / Test

```bash
npm run lint          # shellcheck scripts/*.sh
npm test              # ShellSpec BDD suite (vendor/shellspec/shellspec)
npm run test:all      # lint + test combined
npm run setup:test    # install ShellSpec to vendor/shellspec/ (first-time setup)
```

Single script lint: `shellcheck scripts/afc-bash-guard.sh`
Single spec run: `vendor/shellspec/shellspec spec/afc-bash-guard_spec.sh`

## Architecture

all-for-claudecode is a Claude Code plugin that automates the full development cycle (spec → plan → tasks → implement → review → clean) through markdown command prompts, bash hook scripts, and project preset templates. Implementation uses dependency-aware orchestration: sequential for simple tasks, parallel batch (≤5 tasks), or self-organizing swarm (6+ tasks) with native TaskCreate/TaskUpdate primitives.

### Core Layers

- **commands/** — 18 markdown command prompts with YAML frontmatter (`name`, `description`, `argument-hint`, `allowed-tools`, `model`, `user-invocable`, `disable-model-invocation`, `context`)
- **agents/** — 3 subagents: afc-architect, afc-security (persistent memory with `memory: project`), afc-impl-worker (ephemeral parallel worker with worktree isolation)
- **hooks/hooks.json** — Declares 17 hook events with 3 handler types: `command` (shell scripts), `prompt` (LLM single-turn), `agent` (subagent with tools). 4 hooks use `async: true`. Includes ConfigChange (settings audit), TeammateIdle (Agent Teams gate), and WorktreeCreate/WorktreeRemove (worktree lifecycle)
- **schemas/** — JSON Schema definitions (hooks.schema.json, plugin.schema.json, marketplace.schema.json) validated during `npm run lint`
- **scripts/** — 25 bash scripts + 2 Node.js ESM validators (.mjs) + 1 shared state library (afc-state.sh). Bash scripts follow: `set -euo pipefail` + `trap cleanup EXIT` + jq-first with grep/sed fallback
- **docs/** — Shared reference documents (critic-loop-rules.md, phase-gate-protocol.md, nfr-templates.md) referenced by commands
- **templates/** — 5 project preset configs (nextjs-fsd, react-spa, express-api, monorepo, template)
- **bin/cli.mjs** — ESM CLI entry point (install helper)
- **.claude-plugin/** — Plugin manifest (`plugin.json`) and marketplace registration (`marketplace.json`)

### Hook System

Scripts receive stdin JSON from Claude Code and respond via stdout JSON or stderr. Key protocols:
- **PreToolUse**: stdin has `tool_input` → respond `{"hookSpecificOutput":{"permissionDecision":"allow"}}` or `{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":"..."}}`
- **PostToolUse/PostToolUseFailure**: respond with `{"hookSpecificOutput":{"additionalContext":"..."}}`
- **SessionEnd/Notification**: stderr shows to user, stdout goes to Claude context
- **UserPromptSubmit**: stdout `{"hookSpecificOutput":{"additionalContext":"..."}}` injects context per prompt
- **PermissionRequest**: stdout `{"hookSpecificOutput":{"decision":{"behavior":"allow"}}}` auto-allows whitelisted Bash commands
- **TaskCompleted (prompt)**: `type: "prompt"` with haiku — LLM verifies acceptance criteria (supplements command CI gate)
- **Stop (agent)**: `type: "agent"` with haiku — subagent checks TODO/FIXME in changed files (supplements command CI gate)

Pipeline state is managed through a single JSON file `$CLAUDE_PROJECT_DIR/.claude/.afc-state.json`:
- All scripts source `scripts/afc-state.sh` for state access (afc_state_is_active, afc_state_read, afc_state_write)
- Fields: `feature`, `phase`, `ciPassedAt`, `changes[]`, `startedAt`
- When inactive: file does not exist
- jq-first with grep/sed fallback for jq-less environments

### Command Frontmatter Controls

- `user-invocable: false` — hidden from `/` menu, only model-callable (3 commands: analyze, clarify, tasks)
- `disable-model-invocation: true` — user-only, prevents auto-calling (7 commands: init, doctor, principles, checkpoint, resume, architect, security)
- `context: fork` — runs in isolated subagent, result returned to main context (3 commands: analyze, architect, security). architect and security use custom agents with `memory: project` for persistent learning
- `model: haiku|sonnet` — model routing per command complexity (haiku for mechanical tasks, sonnet for design/analysis, omit for orchestrator inheritance)

## Shell Script Conventions

All scripts must:
1. Start with `#!/bin/bash` and `set -euo pipefail`
2. Include `trap cleanup EXIT` with at minimum a `:` placeholder
3. Use `${CLAUDE_PROJECT_DIR:-$(pwd)}` for project root
4. Parse stdin JSON with jq first, grep/sed fallback for jq-less environments
5. Exit 0 on success; exit 2 for Stop/TaskCompleted/ConfigChange/TeammateIdle hooks (blocks action)
6. Use `printf '%s\n' "$VAR"` instead of `echo "$VAR"` when piping external data (avoids `-n`/`-e` flag interpretation)
7. Use `# shellcheck disable=SCXXXX` for intentional suppressions

## Version Sync

Three files must have matching versions: `package.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (both `metadata.version` and `plugins[0].version`).

## Testing

Tests use ShellSpec 0.28.1 (pinned in `vendor/shellspec/`) with BDD-style specs in `spec/`. Each spec file covers one script. Shared helpers live in `spec/spec_helper.sh` (auto-loaded via `--require spec_helper` in `.shellspec`).

Key patterns:
- `setup_tmpdir VAR_NAME` — creates isolated tmpdir, exports `CLAUDE_PROJECT_DIR` and `HOME` (named-variable pattern avoids subshell export issues)
- `setup_tmpdir_with_git VAR_NAME` — same + initializes a bare git repo
- `setup_config_fixture DIR [ci_cmd]` — writes a minimal `afc.config.md` fixture
- `Data '{"key":"val"}'` — pipes JSON to script stdin
- `The path "$path" should be exist` — file/dir existence check
- `The contents of file "$path" should include "..."` — file content check
- Exit 2 scripts (stop-gate, config-change): ShellSpec handles non-zero exits automatically; add explicit `The status should eq 2`
