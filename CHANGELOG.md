# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2026-02-21

### Fixed
- PreToolUse hook migrated to `hookSpecificOutput.permissionDecision` format (deprecated top-level `decision` removed)
- SubagentStart hook outputs `hookSpecificOutput` JSON instead of plain text (context injection now works)
- All 17 hook scripts consume stdin to prevent pipe breaks
- All jq calls wrapped with `|| true` to prevent crash under `pipefail`
- All `echo` with external data replaced with `printf '%s\n'` (flag interpretation safety)
- All flag file reads use `head -1 | tr -d '\n\r'` (multi-line safety)
- Stop gate: `stop_hook_active` check with grep/sed fallback for jq-less environments
- Pipeline manage: feature name sanitization (newline, path traversal, length limit)
- Permission request: redirect operators (`>`, `<`) added to chaining filter
- Task completed gate: stdin consumption + stale CI detection safety
- Notification hook: `$` and backtick escaping to prevent command injection via AppleScript
- Failure hint hook: jq output `|| true` + echo→printf for external data
- Session end hook: stdin consumed before early exit path
- Config change hook: consistent exit code preservation in cleanup trap

### Changed
- Test suite expanded from 101 to 118 assertions (17 new edge case tests)
- CLAUDE.md updated: PreToolUse protocol docs, command counts, test count
- CONTRIBUTING.md updated: hook protocol table, script template, quick reference
- README.md: test badge anchor fix, badge count update
- `.claude/rules/commands.md`: model assignment lists updated (doctor, test added)
- Version sync now includes `commands/init.md` SELFISH block (4-file sync)

## [1.1.0] - 2026-02-20

### Added
- Skills frontmatter for all 18 commands (name, description, argument-hint, allowed-tools, model)
- Model routing for all 18 commands (haiku for simple tasks, sonnet for design/analysis)
- docs/ shared reference files (critic-loop-rules.md, phase-gate-protocol.md)
- .claude/rules/ path-specific rules (shell-scripts.md, commands.md)
- agents/ directory with persistent memory subagents (selfish-architect, selfish-security)
- `memory: project` for architect and security agents — learnings persist across sessions
- `isolation: worktree` for selfish-security agent (isolated git worktree execution)
- `skills` field for both agents (pre-loads critic-loop-rules and phase-gate-protocol)
- PreToolUse Bash guard hook — blocks dangerous commands during pipeline
- SubagentStart context injection — injects pipeline state into subagents
- PostToolUse auto-format hook — background formatting after Edit/Write (async)
- SessionEnd hook — warns on unfinished pipeline at session close
- PostToolUseFailure hook — provides diagnostic hints for known error patterns
- Notification hook — desktop alerts for idle_prompt and permission_prompt (async)
- TaskCompleted hook — CI gate (command) + LLM acceptance criteria verification (prompt)
- SubagentStop hook — tracks subagent completion/failure in pipeline log
- UserPromptSubmit hook — pipeline Phase/Feature context injection per prompt
- PermissionRequest hook — auto-allow CI commands during implement/review
- ConfigChange hook — settings file change audit/block during active pipeline
- TeammateIdle hook — prevents Agent Teams teammate idle during implement/review phases
- Stop hook enhanced with agent handler for code completeness verification
- Dynamic config injection via `!`command`` syntax in command prompts
- `context: fork` for read-only commands (analyze, architect, security)
- Invocation control: `user-invocable: false` (3 commands), `disable-model-invocation: true` (7 commands)
- `/selfish:doctor` project health diagnosis command
- `/selfish:test` test generation command
- 3 preset templates: react-spa, express-api, monorepo
- `.claude/rules/development.md` general development rules
- Hook script test framework (tests/test-hooks.sh) with 118 assertions
- 3 hook handler types: command (shell), prompt (LLM single-turn), agent (subagent with tools)
- Agents auto-discovery via `agents/` directory
- README.md, CHANGELOG.md documentation

### Changed
- package.json version 1.0.0 → 1.1.0
- plugin.json and marketplace.json version sync to 1.1.0
- Hook coverage expanded from 4 to 15 events (100%)
- auto-format and notify hooks converted to async
- auto.md and implement.md prompt reduction via docs/ references
- commands/architect.md and security.md use custom agents with persistent memory

## [1.0.0] - 2026-02-19

### Added
- Initial release
- Full Auto pipeline: spec → plan → tasks → implement → review → clean
- 16 initial slash commands for complete development cycle automation
- Critic Loop quality verification at each pipeline phase
- SessionStart hook for pipeline state restoration
- PreCompact hook for automatic checkpointing before context compression
- PostToolUse hook for change tracking
- Stop gate hook for CI enforcement
- Pipeline management script with safety snapshots
- 2 project presets (template, nextjs-fsd)
