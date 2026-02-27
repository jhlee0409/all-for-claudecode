# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.4.0] - 2026-02-28

### Added
- **Expert consultation system**: 8 domain specialist agents (backend, infra, PM, design, marketing, legal, security, tech-advisor) with persistent memory, routed via `/afc:consult` command
- **Consult router command**: Auto-detects domain from question keywords, supports explicit domain selection, exploratory Socratic mode, and depth hints (brief/deep/auto)
- **Expert protocol**: Shared consultation protocol with Progressive Disclosure response format, Anti-Sycophancy rules, and Overengineering Guard
- **Domain adapters**: Industry-specific guardrails for fintech, ecommerce, and healthcare projects (auto-loaded from project profile)
- **Project profile template**: `.claude/afc/project-profile.md` generated during init for expert context
- **Spec guard hook**: PreToolUse hook blocking spec.md writes during implement/review/clean phases (spec immutability enforcement)
- **Drift detection**: Per-phase prompt counter with checkpoint injection every 50 prompts during implement/review — reminds agents to re-read plan constraints
- **Baseline test step**: `{config.test}` verification before implementation starts, reports pre-existing failures with proceed/fix/abort options
- **`afc_state_increment`**: Read-modify-write numeric field helper in afc-state.sh with validation
- **`AFC_DRIFT_THRESHOLD`**: SSOT constant for drift checkpoint interval

### Fixed
- **Spec guard path traversal bypass**: Normalize `../` sequences and support relative paths — prevents spec immutability circumvention
- **Spec guard MultiEdit gap**: Added MultiEdit to PreToolUse matcher (was only Edit|Write|NotebookEdit)
- **JSON injection in user-prompt-submit**: Use jq for safe JSON encoding with manual escaping fallback
- **Expert agent Write/Edit tools missing**: Added Write and Edit tools to all 8 experts + tech-advisor (enables memory updates and project-profile creation)
- **Consult duplicate registration**: Removed from user-only section in init.md (kept in auto-trigger routing table)
- **expert-protocol.md agent list**: Removed incomplete enumeration from description line
- **Numeric fallback regex**: Fixed `[0-9]*` → `[0-9][0-9]*` in afc_state_read (prevented matching empty strings)

### Changed
- **Domain adapters standardized**: Unified section structure across fintech/ecommerce/healthcare (6 common sections: Compliance, Data Handling, Domain-Specific, Security, Testing, Scale)
- **Drift threshold extracted**: Moved hardcoded `DRIFT_THRESHOLD=50` to afc-state.sh SSOT constant
- **promptCount reset**: Phase changes now reset per-phase prompt counter to 0, preserving pipeline-wide totalPromptCount
- **Quality metrics**: Added totalPromptCount to auto.md quality report

### Tests
- 191 → 194 examples, 0 failures
- New: afc-spec-guard_spec.sh (13 cases including path traversal and relative path bypass)
- New: afc_state_increment tests (5 cases: missing file, new counter, existing counter, non-numeric, consecutive)
- New: drift checkpoint tests (4 cases: threshold trigger, below threshold, second threshold, non-implement phase)
- New: promptCount phase reset test

## [2.3.0] - 2026-02-26

### Added
- **Memory Health diagnostics**: New Category 6 in `/afc:doctor` with 7 checks — monitors memory subdirectory file counts and agent MEMORY.md sizes against defined thresholds
- **Memory rotation in Clean phase**: Auto-prunes oldest files in memory subdirectories when exceeding thresholds (quality-history: 30, reviews: 40, retrospectives: 30, research: 50, decisions: 60)
- **Agent memory size limits**: afc-architect and afc-security MEMORY.md files capped at 100 lines with prioritized self-pruning rules
- **Agent memory enforcement in Clean phase**: Auto-invokes agents to self-prune when MEMORY.md exceeds 100 lines
- **Checkpoint dual-write**: Phase gate checkpoints written to both `.claude/afc/memory/` and auto-memory location for compaction resilience
- **Checkpoint dual-delete**: Clean phase clears checkpoint from both locations to prevent stale state
- **Resume auto-memory fallback**: `/afc:resume` checks auto-memory checkpoint when primary location is empty
- **`/afc:validate` command**: Separated from analyze — artifact consistency validation (user-invocable: false, haiku)
- **`/afc:analyze` command**: Rewritten as general-purpose code analysis (user-invocable: true, sonnet, context: fork)

### Changed
- **Memory loading limits**: All memory directory reads now load only the most recent N files (sorted by filename descending) instead of loading everything — prevents unbounded growth from degrading performance
- **Doctor categories renumbered**: Hook Health → Category 7, Version Sync → Category 8 (Memory Health inserted as Category 6)
- **Task-completed gate**: Fixed blocking behavior during implement phase task updates

### Fixed
- **Documentation inaccuracies**: Fixed inconsistencies found by consistency scan across multiple command files
- **Hardcoded version**: Fixed version reference in launch.md example

## [2.2.1] - 2026-02-26

### Changed
- **Phase checkpoints**: Auto-checkpoint recorded at each phase gate with timestamp in state JSON
- **SSOT validation**: `afc-consistency-check.sh` now validates phase constants, command-to-phase mapping, and subagent prefix conventions
- **Dead code removal**: Removed unused helper functions and redundant flag file references
- **README**: Added walkthrough, usage examples, and expanded FAQ

### Fixed
- **afc-stop-todo-check**: Handle absolute paths from Claude's `tool_input` (was silently skipping files)
- **afc-pipeline-manage**: `phase` and `ci-pass` commands now fail fast when no pipeline is active (was corrupting state)
- **afc-state**: `afc_state_remove` now has sed fallback for jq-less environments (was silently no-op)
- **afc-notify**: Eliminated AppleScript injection via positional `argv` pattern (was using string interpolation)
- **afc-dag-validate / afc-parallel-validate**: Replaced string-based trap with function-based trap (prevented code injection via temp path)
- **afc-permission-request**: Added symlink resolution for `chmod +x`, path traversal block for `PLUGIN_ROOT`, single-quoted and unquoted YAML config parsing
- **afc-consistency-check**: Context-aware awk extraction for `marketplace.json` version fields (was position-dependent)
- **Documentation**: Fixed handler type descriptions, step numbering in auto.md and implement.md, documented critic safety cap rationale
- **Test coverage**: Added 27 tests for `afc-state.sh` public API (171 total, 0 failures)

## [2.2.0] - 2026-02-25

### Added
- **Standalone commands**: `/afc:ideate` (divergent idea generation) and `/afc:launch` (deployment readiness check) — independent of the main pipeline
- **SSOT phase constants**: Centralized phase list in `afc-state.sh`; scripts use helpers instead of hardcoded phase lists
- **Cross-reference consistency check**: `afc-consistency-check.sh` validates config placeholders, agent names, hook scripts, test coverage, version sync, and phase SSOT — runs as part of `npm run lint`

### Changed
- **Config format**: `afc.config.md` converted to free-form markdown with only CI Commands in fixed YAML format; init auto-analyzes the project structure instead of selecting presets
- **Presets removed**: `react-spa`, `express-api`, `monorepo`, `nextjs-fsd` preset templates deleted — replaced by auto-detection in `/afc:init`
- **Config template**: `afc.config.template.md` simplified to match free-form structure
- **Fork commands** (analyze, architect, security): Now read `afc.config.md` directly instead of relying on injected config
- **Model invocation**: `disable-model-invocation` removed from 7 commands for flexibility
- **Docs**: Hardcoded counts removed from CLAUDE.md, README.md, CONTRIBUTING.md, package.json to prevent staleness
- **README**: Rewritten for clarity, SEO/AEO optimization, added project image
- **Plugin description**: Added to plugin.json for marketplace display

### Fixed
- Fork commands failed when config was not pre-injected into context

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
- Invocation control: `user-invocable: false` (3 commands)
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
