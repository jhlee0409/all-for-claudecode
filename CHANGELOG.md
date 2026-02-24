# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-02-25

### Breaking Changes
- **Pipeline restructured from 6-phase to 5-phase**: tasks phase absorbed into implement (auto-generated from plan.md File Change Map)
- **State file consolidation**: 4 individual flag files (`.afc-active`, `.afc-phase`, `.afc-ci-passed`, `.afc-changes.log`) → single `.claude/.afc-state.json` with shared library (`scripts/afc-state.sh`)

### Added
- **Cross-artifact validation**: CROSS_CONSISTENCY criterion in Plan critic (spec↔plan 5-point checklist), SPEC_ALIGNMENT criterion in Review critic (spec↔implementation verification)
- **Specialist agent integration in Review**: afc-architect and afc-security agents invoked via parallel Task() calls for persistent-memory-aware architecture and security analysis
- **ADR recording via architect agent**: Plan phase records architecture decisions to architect agent's persistent memory for cross-session conflict detection
- **Research persistence**: Research findings saved to `.claude/afc/memory/research/` for cross-session reuse
- **Debug-based RCA on CI failure**: Replaces blind "retry 3 times" with `/afc:debug` logic (error trace → hypothesis → targeted fix)
- **Acceptance test generation**: Post-implementation auto-generation of test cases from spec GWT (Given/When/Then) acceptance scenarios
- **Implementation Context**: <500 word section in plan.md injected into every sub-agent prompt during implement
- **Session context preservation**: `save_session_context` at Plan, `load_session_context` at Implement for compaction resilience
- **Pre-implementation gates**: Auto-Clarify (Phase 0.5), TDD pre-gen (Step 3.2), Blast Radius analysis (Step 3.3)
- **Request Triage (Phase 0.3)**: Necessity, scope, and proportionality checks before pipeline investment
- **Fast-path detection (Phase 0.8)**: Trivial changes skip spec/plan phases
- **JSON Schema validation**: `schemas/` directory with hooks.schema.json, plugin.schema.json, marketplace.schema.json
- **Error message standardization**: All stderr uses `[afc:{context}]` prefix
- **Node.js validators**: `afc-dag-validate.mjs`, `afc-parallel-validate.mjs` (bash fallback retained)
- **Review expanded to 8 perspectives**: Added Reusability (F), Maintainability (G), Extensibility (H)
- **Quality report JSON**: Structured pipeline metrics in `.claude/afc/memory/quality-history/`
- **Orchestrator pre-assignment**: Swarm workers receive pre-assigned tasks (replaces self-claiming to avoid race conditions)
- **EARS notation**: Spec phase uses Event/Action/Response/State notation for requirements
- **Phase checkpoints**: Auto-checkpoint at each phase gate completion
- **Research Gate**: Spec phase mandatory research before writing requirements
- **Inline Clarification**: Spec phase auto-resolves ambiguities without separate clarify step

### Changed
- Pipeline phases: `spec → plan → tasks → implement → review → clean` → `spec → plan → implement → review → clean`
- Critic safety cap unified to 5 across all phases
- Swarm mode uses orchestrator pre-assignment instead of self-claiming (avoids TaskUpdate race conditions)
- Test suite: migrated from custom bash tests to ShellSpec 0.28.1 BDD framework (125 examples)
- Agent Pipeline Integration sections added to afc-architect and afc-security agent definitions
- Phase gate protocol updated with debug-based RCA reference
- MIGRATION.md updated for state file consolidation

## [2.0.0] - 2026-02-24

### Breaking Changes
- **Rebrand**: `selfish-pipeline` → `all-for-claudecode`
- All slash commands: `/selfish:*` → `/afc:*`
- Config files: `selfish.config.*.md` → `afc.config.*.md`
- State files: `.selfish-*` → `.afc-*`
- CLAUDE.md markers: `SELFISH:START/END` → `AFC:START/END`

### Added
- Legacy migration support in `/afc:doctor` and `/afc:init` commands
- Multi-ecosystem preflight check redesign
- Quality enhancement: directory consolidation + 4 prompt improvements

### Renamed
- Package: `selfish-pipeline` → `all-for-claudecode`
- Plugin: `selfish` → `afc`, prefix: `/selfish:*` → `/afc:*`
- Scripts: `selfish-*.sh` → `afc-*.sh`
- Agents: `selfish-architect` / `selfish-security` → `afc-architect` / `afc-security`
- Config: `selfish.config.*.md` → `afc.config.*.md`
- Git tags: `selfish/pre-*` → `afc/pre-*`
- Artifact dir: `.claude/selfish/` → `.claude/afc/`
- GitHub: `jhlee0409/selfish-pipeline` → `jhlee0409/all-for-claudecode`

### Fixed
- Review description and migration doc accuracy
- 5 functional bugs across 10 commands
- Hardcoded counts removed from docs to prevent staleness
- Doctor reads actual plugin version from package.json
- Dynamic version in CLAUDE.md block instead of hardcoded
- Restored hooks field in plugin.json dropped in v1.2.0

### Migration
See [MIGRATION.md](MIGRATION.md) for step-by-step upgrade guide from v1.x.

## [1.2.0] - 2026-02-23

### Added
- Convergence-based critic loop — replaces fixed-pass loops with dynamic termination across 8 commands
- 4 critic verdicts: PASS, FAIL, ESCALATE, DEFER with escalation triggers for ambiguous issues
- Safety caps (5 rounds default, 7 max) to prevent infinite critic loops
- Timeline logger script (`afc-timeline-log.sh`) — JSONL event logging with auto-rotation
- Parallel task validator script (`afc-parallel-validate.sh`) — detects file conflicts in `[P]` batches
- Preflight checker script (`afc-preflight-check.sh`) — validates environment before pipeline start
- Pipeline manage: `log`, `phase-tag`, `phase-tag-clean` subcommands
- Phase rollback support in auto.md pipeline orchestration
- Swarm recovery logic in implement.md for failed parallel tasks
- Report archiving in review.md
- Alternative design section in plan.md with retrospective loader
- NFR (Non-Functional Requirements) auto-suggest in spec.md
- `[P]` (parallel) marker validation in tasks.md
- `docs/nfr-templates.md` — project-type NFR suggestion templates
- `statusMessage` output on 11 hook handlers for UI progress indication
- `updatedInput` with safe alternatives in bash-guard (suggests safe commands instead of just blocking)
- Retrospective learning integration in spec, tasks, and review commands

### Changed
- Test suite expanded from 118 to 161 assertions (43 new tests)
- Critic loop rules doc significantly expanded with convergence protocol, verdict definitions, and escalation triggers
- hooks.json updated with statusMessage support across handlers
- CLAUDE.md updated: test count (161), docs list (nfr-templates.md)
- README.md: test badge updated (161)

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
- Version sync now includes `commands/init.md` all-for-claudecode block (4-file sync)

## [1.1.0] - 2026-02-20

### Added
- Skills frontmatter for all 18 commands (name, description, argument-hint, allowed-tools, model)
- Model routing for all 18 commands (haiku for simple tasks, sonnet for design/analysis)
- docs/ shared reference files (critic-loop-rules.md, phase-gate-protocol.md)
- .claude/rules/ path-specific rules (shell-scripts.md, commands.md)
- agents/ directory with persistent memory subagents (afc-architect, afc-security)
- `memory: project` for architect and security agents — learnings persist across sessions
- `isolation: worktree` for afc-security agent (isolated git worktree execution)
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
- `/afc:doctor` project health diagnosis command
- `/afc:test` test generation command
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
