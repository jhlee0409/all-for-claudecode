---
name: afc:review
description: "Code review — use when the user asks to review code, analyze a PR diff, do a code review, or evaluate code quality and correctness"
argument-hint: "[scope: file path, PR number, or staged]"
allowed-tools:
  - Read
  - Write
  - Grep
  - Glob
  - Bash
  - Task
model: sonnet
---

# /afc:review — Code Review

> Performs a comprehensive review of changed code (quality, security, performance, architecture compliance).
> Validates completeness of the review itself with convergence-based Critic Loop.

## Arguments

- `$ARGUMENTS` — (optional) Review scope (file path, PR number, or "staged")
  - If not specified: full `git diff` of current branch (unstaged + staged)

## Project Config (auto-loaded)

!`cat .claude/afc.config.md 2>/dev/null || echo "[CONFIG NOT FOUND] .claude/afc.config.md not found. Create it with /afc:init."`

## Config Load

**Always** read `.claude/afc.config.md` first (read manually if not auto-loaded above).

If config file is missing:
1. Ask the user: "`.claude/afc.config.md` not found. Run `/afc:init` to set up the project?"
2. If user accepts → run `/afc:init`, then **restart this command** with the original `$ARGUMENTS`
3. If user declines → **abort**

## Execution Steps

### 1. Collect Review Targets

1. **Determine scope**:
   - `$ARGUMENTS` = file path → that file only
   - `$ARGUMENTS` = PR number → run `gh pr diff {number}`
   - `$ARGUMENTS` = "staged" → `git diff --cached`
   - Not specified → `git diff HEAD` (all uncommitted changes)
2. Extract **list of changed files**
3. Read **full content** of each changed file (not just the diff — full context)
4. **Load spec context** (if available): Check for `.claude/afc/specs/{feature}/context.md` and `.claude/afc/specs/{feature}/spec.md`. If found, load them for SPEC_ALIGNMENT validation in the Critic Loop. If neither exists, SPEC_ALIGNMENT criterion is skipped with note "no spec artifacts available"

### 2. Parallel Review (scaled by file count)

Choose review orchestration based on the number of changed files:

**Pre-scan: Call Chain Context** (for Parallel Batch and Review Swarm modes only):

Before distributing files to review agents, collect cross-boundary context:

1. For each changed file, identify **outbound calls** to other changed files (imports + function calls)
2. For each outbound call target, extract: function signature + 1-line side-effect summary (e.g., "mutates playlist state", "triggers async cascade")
3. Include this context in each review agent's prompt:
   ```
   ## Cross-File Context
   This file calls:
   - `deleteVideo()` in api/videos.ts → internally auto-advances to next video if current is deleted
   - `getNextVideo()` in api/playlist.ts → pops pending keyword queue first, falls back to normal next
   Review findings should account for these behaviors.
   ```

For Direct review mode (≤5 files): skip pre-scan — orchestrator already has full context.

#### 5 or fewer files: Direct review
Review all files directly in the current context (no delegation).

#### 6–10 files: Parallel Batch
Distribute to parallel review agents (2–3 files per agent) in a **single message**:
```
Task("Review: {file1, file2}", subagent_type: "general-purpose")
Task("Review: {file3, file4}", subagent_type: "general-purpose")
```
Read each agent's returned output, then write consolidated review.

#### 11+ files: Review Swarm
Create a review task pool and spawn pre-assigned review workers:

> **Note**: Unlike implement swarm (which prohibits self-claiming due to write conflicts), review workers use orchestrator pre-assignment by file group. This is safe because review is read-only — no write race conditions.

```
// 1. Group files into batches (2-3 files per worker)
// 2. Spawn N review workers in a single message (N = min(5, file count / 2))
Task("Review Worker 1: src/auth/login.ts, src/auth/session.ts", subagent_type: "general-purpose",
  prompt: "Review the following files for quality, security, architecture, performance.
  Files: src/auth/login.ts, src/auth/session.ts
  Review criteria: {config.code_style}, {config.architecture}, security, performance.
  Output findings as: severity (Critical/Warning/Info), file:line, issue, suggested fix.")
Task("Review Worker 2: src/api/routes.ts, src/api/middleware.ts", subagent_type: "general-purpose", ...)
```
Collect all worker outputs, then write consolidated review.

### 2.5. Specialist Agent Delegation (optional, parallel)

When the `afc-architect` and `afc-security` agents are available, delegate perspectives B and C for deeper analysis:

```
Task("Architecture Review", subagent_type: "afc:afc-architect",
  prompt: "Review changed files for architecture compliance.
  Files: {changed file list}
  Rules: {config.architecture}
  Return findings as: severity, file:line, issue, suggested fix.")

Task("Security Review", subagent_type: "afc:afc-security",
  prompt: "Scan changed files for security vulnerabilities.
  Files: {changed file list}
  Return findings as: severity, file:line, issue, suggested fix.")
```

- Launch both in a **single message** (parallel execution)
- Merge agent findings into the consolidated review (Step 4)
- Agents update their persistent memory automatically (ADR patterns, vulnerability patterns, false positives)
- If agents are unavailable (e.g., standalone mode without plugin): fall back to direct review for B and C

### 3. Perform Review

For each changed file, examine from the following perspectives:

#### A. Code Quality
- {config.code_style} compliance (any usage, missing types)
- Naming conventions (handleX, isX, UPPER_SNAKE)
- Duplicate code
- Unnecessary complexity

#### B. {config.architecture} (agent-enhanced when available)
- Layer dependency direction violations (lower→upper imports)
- Segment rules (api/, model/, ui/, lib/)
- Appropriate layer placement
- **Agent bonus**: ADR conflict detection, cross-session pattern recognition

#### C. Security (agent-enhanced when available)
- XSS vulnerabilities (dangerouslySetInnerHTML, unvalidated user input)
- Sensitive data exposure
- SQL/Command injection
- **Agent bonus**: false positive filtering, known vulnerability pattern matching

#### D. Performance
- Startup/response latency concerns
- Unnecessary computation or redundant operations
- Resource management (memory, file handles, connections, subprocesses)
- Framework-specific performance patterns (from Project Context)

#### E. Project Pattern Compliance
- {config.code_style} naming and structure conventions
- {config.architecture} layer rules and boundaries
- Framework-specific idioms and best practices (from Project Context)

#### F. Reusability
- Duplicate or near-duplicate logic across files
- Opportunities to extract shared utilities or helpers
- DRY principle adherence (same logic repeated in multiple places)
- Appropriate abstraction level (not premature, not missing)

#### G. Maintainability
- Function/file size — can a developer or LLM understand each unit in isolation?
- Naming clarity — do names reveal intent without requiring surrounding context?
- Self-contained files — minimal cross-file dependencies for comprehension
- Comments where logic is non-obvious (present where needed, absent where redundant)

#### H. Extensibility
- Can new variants or features be added without modifying existing code?
- Are there clear extension points (configuration, plugin hooks, strategy patterns)?
- Open/Closed principle adherence where applicable
- Future modification cost — would a reasonable feature request require rewriting or only extending?

### 3.5. Cross-Boundary Verification (MANDATORY)

After individual/parallel reviews complete, the **orchestrator** MUST perform a cross-boundary check. This is a required step, not optional — skipping it is a review defect.

**For 11+ file reviews**: This is especially critical because individual review agents cannot see cross-file interactions. The orchestrator MUST read callee implementations directly.

1. **Filter**: From all collected findings, select those involving:
   - Call order changes (function A now calls B before C)
   - Error handling modifications (try/catch scope changes, error propagation changes)
   - State mutation changes (new writes to shared state, removed cleanup)

2. **Verify**: For each behavioral finding rated Critical or Warning:
   - **Read the callee's implementation** (the function/method being called) — this read is mandatory, not optional
   - **Skip external dependencies**: If the callee is in `node_modules/`, `vendor/`, or other third-party directories, do NOT read the source (it may be minified/compiled). Instead, verify against the dependency's type definitions or documented API contract. Note: "verified against types/docs, not source"
   - Check: does the callee's internal behavior (side effects, state changes, return values) actually conflict with the change?
   - If no conflict → downgrade: Critical → Info, Warning → Info (append "verified: no cross-boundary impact")
   - If confirmed conflict → keep severity, enrich description with callee behavior details

3. **False positive reference** (security-related findings only): For behavioral findings involving security concerns (injection, auth bypass, data exposure), check `afc-security` agent's MEMORY.md (at `.claude/agent-memory/afc-security/MEMORY.md`) `## False Positives` section if the file exists. Known false positive patterns should be noted in findings to avoid recurring false alarms.

4. **Output**: Append verification summary before Review Output:
   ```
   Cross-Boundary Check: {N} behavioral findings verified
   ├─ Confirmed: {M} (severity kept)
   ├─ Downgraded: {K} (false positive — callee compatible)
   └─ Skipped: {J} (no behavioral change)
   ```

This step runs in the orchestrator context (not delegated), as it requires reading code across file boundaries that individual review agents cannot see.

### 4. Review Output

```markdown
## Code Review Results

### Summary
| Severity | Count | Items |
|----------|-------|-------|
| Critical | {N} | {summary} |
| Warning | {N} | {summary} |
| Info | {N} | {summary} |

### Detailed Findings

#### C-{N}: {title}
- **File**: {path}:{line}
- **Issue**: {description}
- **Suggested fix**: {code example}

#### W-{N}: {title}
{same format}

#### I-{N}: {title}
{same format}

### Positives
- {1-2 things done well}
```

### 5. Retrospective Check

If `.claude/afc/memory/retrospectives/` directory exists, load the **most recent 10 files** (sorted by filename descending) and check:
- Were there recurring Critical finding categories in past reviews? Prioritize those perspectives.
- Were there false positives that wasted effort? Reduce sensitivity for those patterns.

### 6. Critic Loop

> **Always** read `${CLAUDE_PLUGIN_ROOT}/docs/critic-loop-rules.md` first and follow it.

Run the critic loop until convergence. Safety cap: 5 passes.

| Criterion | Validation |
|-----------|------------|
| **COMPLETENESS** | Were all changed files reviewed? Are there any missed perspectives (A through H)? |
| **SPEC_ALIGNMENT** | Cross-check implementation against spec.md: (1) every SC (success criterion) is satisfied — provide `{M}/{N} SC verified` count, (2) every acceptance scenario (GWT) has corresponding code path, (3) no spec constraint is violated by the implementation |
| **SIDE_EFFECT_AWARENESS** | For findings involving call order changes, error handling modifications, or state mutation changes: did the reviewer verify the callee's internal behavior? If a Critical finding assumes a side effect without reading the target implementation → auto-downgrade to Info with note "cross-boundary unverified". Provide "{M} of {N} behavioral findings verified" count. |
| **PRECISION** | Are the findings actual issues, not false positives? |

**On FAIL**: auto-fix and continue to next pass.
**On ESCALATE**: pause, present options to user, apply choice, resume.
**On DEFER**: record reason, mark criterion clean, continue.
**On CONVERGE**: `✓ Critic converged ({N} passes, {M} fixes, {E} escalations)`
**On SAFETY CAP**: `⚠ Critic safety cap ({N} passes). Review recommended.`

### 7. Retrospective Entry (if new pattern found)

If this review reveals a recurring pattern not previously documented in `.claude/afc/memory/retrospectives/`:

Append to `.claude/afc/memory/retrospectives/{YYYY-MM-DD}.md`:
```markdown
## Pattern: {category}
**What happened**: {concrete description}
**Root cause**: {why this keeps occurring}
**Prevention rule**: {actionable rule — usable in future plan/implement phases}
**Severity**: Critical | Warning
```

Only write if the pattern is new and actionable. Generic observations are prohibited.

### 8. Archive Review Report

When running inside a pipeline (.claude/afc/specs/{feature}/ exists), persist the review results:

1. Write full review output (Summary table + Detailed Findings + Positives) to `.claude/afc/specs/{feature}/review-report.md`
2. Include metadata header:
   ```markdown
   # Review Report: {feature name}
   > Date: {YYYY-MM-DD}
   > Files reviewed: {count}
   > Findings: Critical {N} / Warning {N} / Info {N}
   ```
3. This file survives Clean phase (copied to `.claude/afc/memory/reviews/{feature}-{date}.md` before .claude/afc/specs/ deletion)

When running standalone (no active pipeline), skip archiving — display results in console only.

### 9. Final Output

```
Review complete
├─ Files: {changed file count}
├─ Found: Critical {N} / Warning {N} / Info {N}
├─ Critic: converged ({N} passes, {M} fixes, {E} escalations)
└─ Conclusion: {one-line summary}
```

## Notes

- **Read-only**: do not modify code. Report findings only.
- **Full context**: read the entire file, not just the diff lines, to understand context before reviewing.
- **Avoid false positives**: classify uncertain issues as Info.
- **Respect patterns**: do not flag code simply because it differs from other patterns. Use CLAUDE.md and afc.config.md as the standard.
- **NEVER use `run_in_background: true` on Task calls**: review agents must run in foreground so results are returned before consolidation.
