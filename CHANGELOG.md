# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-02-20

### Added
- Skills frontmatter for all 16 commands (name, description, argument-hint, allowed-tools, model)
- Model routing for all 16 commands (haiku for simple tasks, sonnet for design/analysis)
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
- Invocation control: `user-invocable: false` (3 commands), `disable-model-invocation: true` (6 commands)
- 3 preset templates: react-spa, express-api, monorepo
- Hook script test framework (tests/test-hooks.sh) with 101 assertions
- 3 hook handler types: command (shell), prompt (LLM single-turn), agent (subagent with tools)
- plugin.json `agents` field for agent auto-discovery
- README.md, CHANGELOG.md documentation

### Changed
- package.json version 1.0.0 → 1.1.0
- plugin.json and marketplace.json version sync to 1.1.0
- Hook coverage expanded from 3 to 15 events (100%)
- auto-format and notify hooks converted to async
- auto.md and implement.md prompt reduction via docs/ references
- commands/architect.md and security.md use custom agents with persistent memory

## [1.0.0] - 2026-02-19

### Added
- Initial release
- Full Auto pipeline: spec → plan → tasks → implement → review → clean
- 16 slash commands for complete development cycle automation
- Critic Loop quality verification at each pipeline phase
- SessionStart hook for pipeline state restoration
- PreCompact hook for automatic checkpointing before context compression
- PostToolUse hook for change tracking
- Stop gate hook for CI enforcement
- Pipeline management script with safety snapshots
- 2 project presets (template, nextjs-fsd)
