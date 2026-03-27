---
name: afc:triage
description: "Parallel triage of open PRs and issues"
argument-hint: "[scope: --pr, --issue, --all (default), or specific numbers]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Task
  - Write
model: sonnet
---

# /afc:triage — PR & Issue Triage

> Collects open PRs and issues, analyzes them in parallel batch, and produces a priority-ranked triage report.
> Uses lightweight analysis first (no checkout), then selective deep analysis with worktree isolation for PRs that require build/test verification.

## Pre-fetched Context

!`gh pr list --json number,title,headRefName,author,labels,additions,deletions,changedFiles,createdAt,updatedAt,reviewDecision,isDraft --limit 50 2>/dev/null || echo "PR_FETCH_FAILED"`

!`gh issue list --json number,title,labels,author,createdAt,updatedAt,comments --limit 50 2>/dev/null || echo "ISSUE_FETCH_FAILED"`

## Arguments

- `$ARGUMENTS` — (optional) Triage scope
  - `--pr` — PRs only
  - `--issue` — Issues only
  - `--all` — Both PRs and issues (default)
  - Specific numbers (e.g., `#42 #43`) — Analyze only those items
  - `--deep` — Force deep analysis (worktree) for all PRs

## Execution Steps

### 1. Collect Targets

Use the pre-fetched context above. If fetch failed, fall back to:

```bash
"${CLAUDE_SKILL_DIR}/../../scripts/afc-triage.sh" "$ARGUMENTS"
```

Apply `$ARGUMENTS` filtering: skip irrelevant items based on `--pr`, `--issue`, or specific numbers.

**Empty backlog early-exit**: If both PR list and issue list are empty (zero open items after filtering), output a clean-backlog summary and exit:
```
Triage complete — backlog is clean
├─ Open PRs: 0
├─ Open issues: 0
└─ No items require attention
```
Skip all subsequent phases.

### 2. Phase 1 — Lightweight Parallel Batch (no checkout)

Spawn all agents in a **single message** (parallel batch, max 5 concurrent).

#### PR Analysis

See prompt template: [pr-analysis-prompt.md](./pr-analysis-prompt.md)

```
Task("Triage PR #{number}: {title}", subagent_type: "general-purpose",
  prompt: "<contents of pr-analysis-prompt.md with placeholders filled>")
```

#### Issue Analysis (batch of 5 per agent)

```
Task("Triage Issues #{n1}-#{n5}", subagent_type: "general-purpose",
  prompt: "Analyze these issues:
  {issue list with titles, labels, comment count}

  For each issue:
  1. gh issue view {number} --comments
  2. Classify:
     - Type: Bug|Feature|Enhancement|Question|Maintenance (adapt to project labels)
     - Priority: P0 (blocking/critical) | P1 (high impact) | P2 (normal) | P3 (low/nice-to-have)
     - Effort: Small|Medium|Large
     - Related PRs (if any mentioned)
  3. One-line summary

  Output per issue:
  ISSUE #{number}: {title}
  TYPE: ...
  PRIORITY: P0|P1|P2|P3
  EFFORT: Small|Medium|Large
  RELATED_PR: #N or none
  SUMMARY: ...")
```

### 3. Phase 2 — Selective Deep Analysis (worktree, optional)

From Phase 1, identify PRs where `NEEDS_DEEP: yes`.

For each, spawn a worktree-isolated agent (max 3 concurrent):

```
Task("Deep triage PR #{number}", subagent_type: "afc:afc-pr-analyst",
  isolation: "worktree",
  prompt: "Deep-analyze PR #{number} ({title}).

  Branch: {headRefName}
  Phase 1 concerns: {concerns from Phase 1}

  Steps:
  1. gh pr checkout {number}
  2. Run CI commands from .claude/afc.config.md or CLAUDE.md
  3. Check type errors, lint issues, test failures
  4. Report architectural impact

  Output:
  BUILD_STATUS: pass|fail|skip
  TEST_STATUS: pass|fail|skip (N passed, M failed)
  LINT_STATUS: pass|fail|skip
  DEEP_FINDINGS: ...
  RECOMMENDATION: merge|request-changes|needs-discussion")
```

If `--deep` flag specified, run Phase 2 for all PRs regardless of Phase 1 classification.

### 3.5. Cross-PR Coupling Detection

See: [coupling-detection.md](./coupling-detection.md)

### 4. Consolidate Triage Report

```markdown
# Triage Report

> Date: {YYYY-MM-DD}
> Repository: {owner/repo}
> Scope: {PRs: N, Issues: M}

## PRs ({count})

### Priority Actions

| # | Title | Risk | Complexity | Status | Action |
|---|-------|------|------------|--------|--------|
| {sorted: Critical first, then by staleness} |

### PR Details

#### PR #{number}: {title}
- **Author**: {author} | **Branch**: {branch}
- **Changes**: +{add}/-{del} across {files} files
- **Risk**: {risk} | **Complexity**: {complexity}
- **Summary**: {summary}
- **Concerns**: {concerns or "None"}
- **Deep analysis**: {findings if Phase 2 ran, otherwise "Skipped"}
- **Recommendation**: {recommendation}

## Issues ({count})

### By Priority

| Priority | # | Title | Type | Effort | Related PR |
|----------|---|-------|------|--------|------------|
| {sorted by priority, then creation date} |

## Summary

- **Immediate attention**: {Critical PRs and P0 issues}
- **Ready to merge**: {PRs with no concerns and passing checks}
- **Needs discussion**: {PRs/issues requiring team input}
- **Stale items**: {items with no meaningful activity relative to project cadence}
```

### 5. Save Report

```
.claude/afc/memory/triage/{YYYY-MM-DD}.md
```

Overwrite if a report for today already exists.

### 6. Final Output

```
Triage complete
├─ PRs analyzed: {N} (deep: {M})
├─ Issues analyzed: {N}
├─ Immediate attention: {count}
├─ Ready to merge: {count}
├─ Report: .claude/afc/memory/triage/{date}.md
└─ Duration: {elapsed}
```

## Notes

- **Read-only**: Does not modify code, merge PRs, or close issues.
- **Rate limits**: For repos with 50+ open items, use `--pr` or `--issue` to reduce scope.
- **Worktree cleanup**: Worktree agents auto-clean on completion. If left behind: `git worktree prune`.
- **NEVER use `run_in_background: true`** on Phase 1 or Phase 2 Task calls — results must be collected before consolidation.
- **Parallel limits**: Phase 1 — max 5 concurrent (parallel batch). Phase 2 — max 3 concurrent worktree agents.
