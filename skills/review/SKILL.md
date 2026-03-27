---
name: afc:review
description: "Code review — review code, analyze PR diff, evaluate quality and correctness"
argument-hint: "[scope: file path, PR number, or staged]"
allowed-tools:
  - Read
  - Write
  - Grep
  - Glob
  - Bash
  - Task
  - LSP
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

**Always** read `.claude/afc.config.md` first — needed for CI Commands (YAML).
Architecture, Code Style, and Project Context are auto-loaded via `.claude/rules/afc-project.md`.

If config file is missing:
1. Ask: "`.claude/afc.config.md` not found. Run `/afc:init`?"
2. If user accepts → run `/afc:init`, then **restart** with original `$ARGUMENTS`
3. If user declines → **abort**

## Execution Steps

### 1. Collect Review Targets

1. **Determine scope**:
   - `$ARGUMENTS` = file path → that file only
   - `$ARGUMENTS` = PR number → `gh pr diff {number}`
   - `$ARGUMENTS` = "staged" → `git diff --cached`
   - Not specified → `git diff HEAD`
2. Extract changed file list; read **full content** of each file (not just the diff)
3. **Load spec context** (if available): `.claude/afc/specs/{feature}/context.md` and `spec.md`. If neither exists, skip SPEC_ALIGNMENT with note "no spec artifacts available"
4. **Build Impact Map** — see [Reverse Impact Analysis](perspectives.md#reverse-impact-analysis)

### 2. Parallel Review (scaled by file count)

Assess complexity holistically: total diff size, file complexity, change diversity, and whether changes are localized or cross-cutting.

**Pre-scan for parallel batch / swarm**: Before distributing files, collect cross-boundary context — outbound calls between changed files with function signature + 1-line side-effect summary. Include Impact Map. Provide each agent a `## Cross-File Context` block. Skip pre-scan for Direct mode.

| Mode | When to use | How |
|------|-------------|-----|
| **Direct** | Small diff, single module, fits in context | Review all files in current context |
| **Parallel batch** | Multiple files/modules, substantial diff | 2–3 files per agent, single message |
| **Swarm** | Large-scale, cross-cutting, mixed types | Pre-assigned workers (≤5), single message |

```
// Parallel batch example
Task("Review: {file1, file2}", subagent_type: "general-purpose")
Task("Review: {file3, file4}", subagent_type: "general-purpose")
```

> Note: Unlike implement swarm (prohibits self-claiming due to write conflicts), review workers use orchestrator pre-assignment. This is safe — review is read-only.

Collect all worker outputs, then write consolidated review.

### 2.5. Specialist Agent Delegation (optional, parallel)

When `afc-architect` and `afc-security` agents are available, delegate perspectives B and C in a **single message**:

```
Task("Architecture Review", subagent_type: "afc:afc-architect",
  prompt: "Review changed files for architecture compliance. Files: {list}. Rules: {config.architecture}. Return: severity, file:line, issue, fix.")

Task("Security Review", subagent_type: "afc:afc-security",
  prompt: "Scan changed files for security vulnerabilities. Files: {list}. Return: severity, file:line, issue, fix.")
```

Merge agent findings into the consolidated review (Step 4). If agents unavailable: fall back to direct review for B and C.

### 3. Perform Review

Review each changed file across all 8 perspectives. See [perspectives.md](perspectives.md) for full criteria.

| Perspective | Focus |
|-------------|-------|
| **A. Code Quality** | `{config.code_style}` compliance, naming, duplication, complexity |
| **B. Architecture** | Layer dependency direction, segment rules, placement (agent-enhanced) |
| **C. Security** | XSS, sensitive data exposure, injection (agent-enhanced) |
| **D. Performance** | Latency, redundant computation, resource management |
| **E. Project Pattern** | `{config.code_style}` + `{config.architecture}` conventions, framework idioms |
| **F. Reusability** | DRY adherence, extraction opportunities, abstraction level |
| **G. Maintainability** | Unit comprehensibility, naming clarity, self-contained files |
| **H. Extensibility** | Extension points, Open/Closed principle, future modification cost |

### 3.5. Cross-Boundary Verification (MANDATORY)

After reviews complete, the orchestrator MUST verify behavioral findings across file boundaries.
See [Cross-Boundary Verification](perspectives.md#cross-boundary-verification-mandatory) for the full procedure.

### 4. Review Output

```markdown
## Code Review Results

### Summary
| Severity | Count | Items |
|----------|-------|-------|
| Critical | {N} | {summary} |
| Warning  | {N} | {summary} |
| Info     | {N} | {summary} |

### Impact Analysis
| Changed File | Affected Files | Method |
|---|---|---|
| {path} | {affected file list} | LSP / Grep |

> ⚠ Dynamic dependencies (runtime dispatch, reflection, cross-language calls) require manual verification.

### Detailed Findings

#### C-{N}: {title}
- **File**: {path}:{line}
- **Issue**: {description}
- **Suggested fix**: {code example}

#### W-{N}: {title}  #### I-{N}: {title}
{same format}

### Positives
- {1-2 things done well}
```

### 5. Retrospective Check

If `.claude/afc/memory/retrospectives/` exists, load the most recent 10 files (sorted descending) and check:
- Recurring Critical categories from past reviews → prioritize those perspectives
- Past false positives → reduce sensitivity for those patterns

### 6. Critic Loop

> **Always** read `docs/critic-loop-rules.md` first and follow it. Safety cap: 5 passes.

| Criterion | Validation |
|-----------|------------|
| **COMPLETENESS** | All changed files reviewed? All perspectives A–H covered? |
| **SPEC_ALIGNMENT** | Every SC satisfied (`{M}/{N} SC verified`), every GWT scenario has a code path, no spec constraint violated |
| **SIDE_EFFECT_AWARENESS** | Behavioral findings (call order, error handling, state mutation) verified against callee implementations. Unverified Critical → auto-downgrade to Info with note. Report `{M}/{N} behavioral findings verified` |
| **PRECISION** | Findings are actual issues, not false positives |

**On FAIL**: auto-fix and continue. **On ESCALATE**: pause, present options, resume. **On DEFER**: record, mark clean. **On CONVERGE**: `✓ Critic converged ({N} passes, {M} fixes, {E} escalations)`. **On SAFETY CAP**: `⚠ Critic safety cap ({N} passes). Review recommended.`

### 7. Retrospective Entry (if new pattern found)

Append to `.claude/afc/memory/retrospectives/{YYYY-MM-DD}.md` only when a pattern is new and actionable:

```markdown
## Pattern: {category}
**What happened**: {concrete description}
**Root cause**: {why this keeps occurring}
**Prevention rule**: {actionable rule}
**Severity**: Critical | Warning
```

### 8. Archive Review Report

When inside a pipeline (`.claude/afc/specs/{feature}/` exists):
1. Write to `.claude/afc/specs/{feature}/review-report.md` with metadata header (date, files reviewed, finding counts)
2. This file survives Clean phase (copied to `.claude/afc/memory/reviews/{feature}-{date}.md`)

Standalone run: display results in console only.

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
- **Full context**: read the entire file, not just diff lines.
- **Avoid false positives**: classify uncertain issues as Info.
- **Respect patterns**: flag against `afc.config.md` standards, not personal preference.
- **NEVER use `run_in_background: true` on Task calls**: review agents must return results before consolidation.
