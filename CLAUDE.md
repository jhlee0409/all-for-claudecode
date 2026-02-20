# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build / Lint / Test

```bash
npm run lint          # shellcheck scripts/*.sh
npm test              # bash tests/test-hooks.sh (77 assertions)
npm run test:all      # lint + test combined
```

Single script lint: `shellcheck scripts/selfish-bash-guard.sh`

## Architecture

Selfish Pipeline is a Claude Code plugin that automates the full development cycle (spec → plan → tasks → implement → review → clean) through markdown command prompts, bash hook scripts, and project preset templates.

### Core Layers

- **commands/** — 16 markdown files, each a slash command prompt with YAML frontmatter (`name`, `description`, `argument-hint`, `allowed-tools`, `model`, `user-invocable`, `disable-model-invocation`, `context`)
- **hooks/hooks.json** — Declares 13 hook events mapping to scripts via `${CLAUDE_PLUGIN_ROOT}/scripts/...` paths (2 hooks use `async: true`)
- **scripts/** — 15 bash scripts implementing hook logic. All follow the pattern: `set -euo pipefail` + `trap cleanup EXIT` + jq-first with grep/sed fallback
- **docs/** — Shared reference documents (critic-loop-rules.md, phase-gate-protocol.md) referenced by commands
- **templates/** — 5 project preset configs (nextjs-fsd, react-spa, express-api, monorepo, template)
- **bin/cli.mjs** — ESM CLI entry point (install helper)
- **.claude-plugin/** — Plugin manifest (`plugin.json`) and marketplace registration (`marketplace.json`)

### Hook System

Scripts receive stdin JSON from Claude Code and respond via stdout JSON or stderr. Key protocols:
- **PreToolUse**: stdin has `tool_input` → respond `{"decision":"allow"}` or `{"decision":"deny","reason":"..."}`
- **PostToolUse/PostToolUseFailure**: respond with `{"hookSpecificOutput":{"additionalContext":"..."}}`
- **SessionEnd/Notification**: stderr shows to user, stdout goes to Claude context
- **UserPromptSubmit**: stdout `{"hookSpecificOutput":{"additionalContext":"..."}}` injects context per prompt
- **PermissionRequest**: stdout `{"hookSpecificOutput":{"decision":{"behavior":"allow"}}}` auto-allows whitelisted Bash commands

Pipeline state is managed through flag files in `$CLAUDE_PROJECT_DIR/.claude/`:
- `.selfish-active` — contains feature name
- `.selfish-phase` — current phase (spec/plan/tasks/implement/review/clean)
- `.selfish-ci-passed` — CI pass timestamp
- `.selfish-changes.log` — tracked file changes

### Command Frontmatter Controls

- `user-invocable: false` — hidden from `/` menu, only model-callable (3 commands: analyze, clarify, tasks)
- `disable-model-invocation: true` — user-only, prevents auto-calling (6 commands: init, principles, checkpoint, resume, architect, security)
- `context: fork` — runs in isolated subagent, result returned to main context (3 commands: analyze, architect, security)
- `model: haiku|sonnet` — model routing per command complexity (haiku for mechanical tasks, sonnet for design/analysis, omit for orchestrator inheritance)

## Shell Script Conventions

All scripts must:
1. Start with `#!/bin/bash` and `set -euo pipefail`
2. Include `trap cleanup EXIT` with at minimum a `:` placeholder
3. Use `${CLAUDE_PROJECT_DIR:-$(pwd)}` for project root
4. Parse stdin JSON with jq first, grep/sed fallback for jq-less environments
5. Exit 0 on success; exit 2 for Stop/TaskCompleted hooks (blocks Claude response/task completion)
6. Use `printf '%s\n' "$VAR"` instead of `echo "$VAR"` when piping external data (avoids `-n`/`-e` flag interpretation)
7. Use `# shellcheck disable=SCXXXX` for intentional suppressions

## Version Sync

Three files must have matching versions: `package.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (both `metadata.version` and `plugins[0].version`).

## Testing

Tests use tmpdir isolation — each scenario creates `$(mktemp -d)` with `.claude/` subdirectory, sets `CLAUDE_PROJECT_DIR` to it, and cleans up after. Variable name `TEST_DIR` (not `TMPDIR` to avoid system env conflict). Use `set +e` / `set -e` around scripts that exit non-zero (e.g., stop-gate exit 2).
