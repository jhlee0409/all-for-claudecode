# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build / Lint / Test

```bash
npm run lint          # shellcheck + schema validation + consistency check
npm test              # ShellSpec BDD suite (vendor/shellspec/shellspec)
npm run test:all      # lint + test combined
npm run setup:test    # install ShellSpec to vendor/shellspec/ (first-time setup)
```

Single script lint: `shellcheck scripts/afc-bash-guard.sh`
Single spec run: `vendor/shellspec/shellspec spec/afc-bash-guard_spec.sh`

## Architecture

all-for-claudecode is a Claude Code plugin that automates the full development cycle (spec → plan → implement → review → clean) through markdown command prompts and bash hook scripts. Project config (`afc.config.md`) uses free-form markdown with only CI Commands in fixed YAML format; init auto-analyzes the project structure instead of using presets. Tasks are generated automatically at implement start from plan.md's File Change Map (no separate tasks phase). Implementation uses dependency-aware orchestration: sequential for simple tasks, parallel batch (≤5 tasks), or orchestrator-managed swarm (6+ tasks) with native TaskCreate/TaskUpdate primitives.

### Core Layers

- **commands/** — Markdown command prompts with YAML frontmatter (`name`, `description`, `argument-hint`, `allowed-tools`, `model`, `user-invocable`, `context`). Beyond the pipeline phases (spec, plan, implement, review, clean), includes standalone utilities (consult, debug, doctor, research, test, analyze, architect, security, triage, etc.) and deployment tools (ideate, launch, pr-comment, release-notes).
- **agents/** — Subagents: afc-architect, afc-security (persistent memory with `memory: project`, security uses `isolation: worktree`), afc-impl-worker (ephemeral parallel worker, orchestrator-managed worktree isolation), afc-pr-analyst (PR deep analysis worker, orchestrator-managed worktree isolation for triage), 8 expert consultation agents (afc-backend-expert, afc-infra-expert, afc-pm-expert, afc-design-expert, afc-marketing-expert, afc-legal-expert, afc-appsec-expert, afc-tech-advisor — persistent memory, routed via `consult` command)
- **hooks/hooks.json** — Hook event declarations with handler types: `command` (shell scripts), `prompt` (LLM single-turn). Some hooks use `async: true`. Includes ConfigChange (settings audit), TeammateIdle (Agent Teams gate), and WorktreeCreate/WorktreeRemove (worktree lifecycle)
- **schemas/** — JSON Schema definitions (hooks.schema.json, plugin.schema.json, marketplace.schema.json) validated during `npm run lint`
- **scripts/** — Bash hook/utility scripts (afc-*.sh + non-afc utilities) + Node.js ESM validators (.mjs) + shared state library (afc-state.sh). Includes `afc-consistency-check.sh` for cross-reference validation. Bash scripts follow: `set -euo pipefail` + `trap cleanup EXIT` + jq-first with grep/sed fallback
- **docs/** — Shared reference documents (critic-loop-rules.md, phase-gate-protocol.md, nfr-templates.md, expert-protocol.md) referenced by commands. Includes `domain-adapters/` subdirectory with industry-specific guardrails (fintech, ecommerce, healthcare)
- **templates/** — config template (`afc.config.template.md`) defining free-form markdown structure with fixed CI Commands YAML section
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
- **Stop (command)**: two `type: "command"` handlers — CI gate verification (`afc-stop-gate.sh`) and TODO/FIXME check in changed files (`afc-stop-todo-check.sh`)

Pipeline state is managed through a single JSON file `$CLAUDE_PROJECT_DIR/.claude/.afc-state.json`:
- All scripts source `scripts/afc-state.sh` for state access (afc_state_is_active, afc_state_read, afc_state_write)
- Fields: `feature`, `phase`, `ciPassedAt`, `changes[]`, `startedAt`
- When inactive: file does not exist
- jq-first with grep/sed fallback for jq-less environments

### Command Frontmatter Controls

- `user-invocable: false` — hidden from `/` menu, only model-callable (validate, clarify, tasks)
- `context: fork` — runs in isolated subagent, result returned to main context (validate, analyze, architect, security). architect and security use custom agents with `memory: project` for persistent learning
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
