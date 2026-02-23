# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build / Lint / Test

```bash
npm run lint          # shellcheck scripts/*.sh
npm test              # bash tests/test-hooks.sh (161 assertions)
npm run test:all      # lint + test combined
```

Single script lint: `shellcheck scripts/selfish-bash-guard.sh`

## Architecture

Selfish Pipeline is a Claude Code plugin that automates the full development cycle (spec → plan → tasks → implement → review → clean) through markdown command prompts, bash hook scripts, and project preset templates. Implementation uses dependency-aware orchestration: sequential for simple tasks, parallel batch (≤5 tasks), or self-organizing swarm (6+ tasks) with native TaskCreate/TaskUpdate primitives.

### Core Layers

- **commands/** — 18 markdown command prompts with YAML frontmatter (`name`, `description`, `argument-hint`, `allowed-tools`, `model`, `user-invocable`, `disable-model-invocation`, `context`)
- **agents/** — 2 persistent memory subagents (selfish-architect, selfish-security) with `memory: project` for cross-session learning
- **hooks/hooks.json** — Declares 15 hook events with 3 handler types: `command` (shell scripts), `prompt` (LLM single-turn), `agent` (subagent with tools). 2 hooks use `async: true`. Includes ConfigChange (settings audit) and TeammateIdle (Agent Teams gate)
- **scripts/** — 20 bash scripts implementing hook logic. All follow the pattern: `set -euo pipefail` + `trap cleanup EXIT` + jq-first with grep/sed fallback
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

Pipeline state is managed through flag files in `$CLAUDE_PROJECT_DIR/.claude/`:
- `.selfish-active` — contains feature name
- `.selfish-phase` — current phase (spec/plan/tasks/implement/review/clean)
- `.selfish-ci-passed` — CI pass timestamp
- `.selfish-changes.log` — tracked file changes

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

Tests use tmpdir isolation — each scenario creates `$(mktemp -d)` with `.claude/` subdirectory, sets `CLAUDE_PROJECT_DIR` to it, and cleans up after. Variable name `TEST_DIR` (not `TMPDIR` to avoid system env conflict). Use `set +e` / `set -e` around scripts that exit non-zero (e.g., stop-gate exit 2).
