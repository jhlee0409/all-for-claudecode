---
name: selfish:review
description: "Code review (read-only)"
argument-hint: "[scope: file path, PR number, or staged]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Task
model: sonnet
---

# /selfish:review — Code Review

> Performs a comprehensive review of changed code (quality, security, performance, architecture compliance).
> Validates completeness of the review itself with convergence-based Critic Loop.

## Arguments

- `$ARGUMENTS` — (optional) Review scope (file path, PR number, or "staged")
  - If not specified: full `git diff` of current branch (unstaged + staged)

## Project Config (auto-loaded)

!`cat .claude/selfish.config.md 2>/dev/null || echo "[CONFIG NOT FOUND] .claude/selfish.config.md not found. Create it with /selfish:init."`

## Config Load

**Always** read `.claude/selfish.config.md` first (read manually if not auto-loaded above). Abort if config file is missing.

## Execution Steps

### 1. Collect Review Targets

1. **Determine scope**:
   - `$ARGUMENTS` = file path → that file only
   - `$ARGUMENTS` = PR number → run `gh pr diff {number}`
   - `$ARGUMENTS` = "staged" → `git diff --cached`
   - Not specified → `git diff HEAD` (all uncommitted changes)
2. Extract **list of changed files**
3. Read **full content** of each changed file (not just the diff — full context)

### 2. Parallel Review (scaled by file count)

Choose review orchestration based on the number of changed files:

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
Create a review task pool and spawn self-organizing review workers:
```
// 1. Register each file as a review task via TaskCreate
TaskCreate({ subject: "Review: src/auth/login.ts", description: "Review for quality, security, architecture, performance..." })
TaskCreate({ subject: "Review: src/auth/session.ts", ... })
// ... for all changed files

// 2. Spawn N review workers in a single message (N = min(5, file count / 2))
Task("Review Worker 1", subagent_type: "general-purpose",
  prompt: "You are a review worker. Loop: TaskList → claim pending → read file + diff → review → record findings → repeat until empty.
  Review criteria: {config.code_style}, {config.architecture}, security, performance.
  Output findings as: severity (Critical/Warning/Info), file:line, issue, suggested fix.")
```
Collect all worker outputs, then write consolidated review.

### 3. Perform Review

For each changed file, examine from the following perspectives:

#### A. Code Quality
- {config.code_style} compliance (any usage, missing types)
- Naming conventions (handleX, isX, UPPER_SNAKE)
- Duplicate code
- Unnecessary complexity

#### B. {config.architecture}
- Layer dependency direction violations (lower→upper imports)
- Segment rules (api/, model/, ui/, lib/)
- Appropriate layer placement

#### C. Security
- XSS vulnerabilities (dangerouslySetInnerHTML, unvalidated user input)
- Sensitive data exposure
- SQL/Command injection

#### D. Performance
- Unnecessary re-renders (missing useCallback/useMemo)
- Infinite loop potential (useEffect dependencies)
- Large data processing

#### E. Project Pattern Compliance
- {config.state_management} usage patterns
- Server/client state management patterns (see {config.state_management})
- Component structure (Props type location, hook order)

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

If `memory/retrospectives/` directory exists, load retrospective files and check:
- Were there recurring Critical finding categories in past reviews? Prioritize those perspectives.
- Were there false positives that wasted effort? Reduce sensitivity for those patterns.

### 6. Critic Loop

> **Always** read `docs/critic-loop-rules.md` first and follow it.

Run the critic loop until convergence. Safety cap: 5 passes.

| Criterion | Validation |
|-----------|------------|
| **COMPLETENESS** | Were all changed files reviewed? Are there any missed perspectives? |
| **PRECISION** | Are the findings actual issues, not false positives? |

**On FAIL**: auto-fix and continue to next pass.
**On ESCALATE**: pause, present options to user, apply choice, resume.
**On DEFER**: record reason, mark criterion clean, continue.
**On CONVERGE**: `✓ Critic converged ({N} passes, {M} fixes, {E} escalations)`
**On SAFETY CAP**: `⚠ Critic safety cap ({N} passes). Review recommended.`

### 7. Archive Review Report

When running inside a pipeline (specs/{feature}/ exists), persist the review results:

1. Write full review output (Summary table + Detailed Findings + Positives) to `specs/{feature}/review-report.md`
2. Include metadata header:
   ```markdown
   # Review Report: {feature name}
   > Date: {YYYY-MM-DD}
   > Files reviewed: {count}
   > Findings: Critical {N} / Warning {N} / Info {N}
   ```
3. This file survives Clean phase (copied to `memory/reviews/{feature}-{date}.md` before specs/ deletion)

When running standalone (no active pipeline), skip archiving — display results in console only.

### 8. Final Output

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
- **Respect patterns**: do not flag code simply because it differs from other patterns. Use CLAUDE.md and selfish.config.md as the standard.
- **NEVER use `run_in_background: true` on Task calls**: review agents must run in foreground so results are returned before consolidation.
