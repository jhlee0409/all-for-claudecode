# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-02-20

### Added
- Model routing for all 16 commands (haiku for simple tasks, sonnet for design/analysis)
- docs/ shared reference files (critic-loop-rules.md, phase-gate-protocol.md)
- .claude/rules/ path-specific rules (shell-scripts.md, commands.md)
- UserPromptSubmit hook — pipeline Phase/Feature context injection per prompt
- PermissionRequest hook — auto-allow CI commands during implement/review
- 16 new test assertions for UserPromptSubmit and PermissionRequest hooks

### Changed
- package.json version 1.2.0 → 1.3.0
- plugin.json and marketplace.json version sync to 1.3.0
- auto-format and notify hooks converted to async (async: true in hooks.json)
- Removed disown workaround from auto-format and notify scripts
- auto.md and implement.md prompt reduction (~91 lines) via docs/ references
- architect.md model routing changed from haiku to sonnet
- Hook coverage expanded from 11/14 to 13/14 events (93%)

## [1.2.0] - 2026-02-20

### Added
- TaskCompleted hook — CI gate on task completion (blocks task completion if CI not passed)
- SubagentStop hook — tracks subagent completion/failure in pipeline log
- 14 new test assertions for TaskCompleted and SubagentStop hooks

### Changed
- package.json version 1.1.0 → 1.2.0
- plugin.json and marketplace.json version sync to 1.2.0
- Hook coverage expanded from 9/14 to 11/14 events (79%)

## [1.1.0] - 2026-02-20

### Added
- Skills frontmatter for all 16 commands (name, description, argument-hint, allowed-tools, model)
- PreToolUse Bash guard hook — blocks dangerous commands during pipeline (push --force, reset --hard, etc.)
- SubagentStart context injection — injects pipeline state into subagents
- Dynamic config injection via `!`command`` syntax in command prompts
- `context: fork` for read-only commands (analyze, architect, security)
- Invocation control: `user-invocable: false` (3 commands), `disable-model-invocation: true` (6 commands)
- PostToolUse auto-format hook — background formatting after Edit/Write (prettier, black, gofmt, rustfmt)
- 3 preset templates: react-spa, express-api, monorepo
- SessionEnd hook — warns on unfinished pipeline at session close
- PostToolUseFailure hook — provides diagnostic hints for known error patterns
- Notification hook — desktop alerts for idle_prompt and permission_prompt (macOS/Linux)
- Hook script test framework (tests/test-hooks.sh) with 46 scenarios
- README.md documentation
- CHANGELOG.md

### Changed
- package.json version 1.0.0 → 1.1.0
- plugin.json and marketplace.json version sync to 1.1.0
- Hook coverage expanded from 3/14 to 9/14 events (64%)

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
