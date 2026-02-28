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

> Collects open PRs and issues, analyzes them in parallel, and produces a priority-ranked triage report.
> Uses lightweight analysis first (no checkout), then selective deep analysis with worktree isolation for PRs that require build/test verification.

## Arguments

- `$ARGUMENTS` — (optional) Triage scope
  - `--pr` — PRs only
  - `--issue` — Issues only
  - `--all` — Both PRs and issues (default)
  - Specific numbers (e.g., `#42 #43`) — Analyze only those items
  - `--deep` — Force deep analysis (worktree) for all PRs

## Execution Steps

### 1. Collect Targets

Run the metadata collection script:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/afc-triage.sh" "$ARGUMENTS"
```

This returns JSON with PR/issue metadata. If the script is not available, fall back to direct `gh` commands:

```bash
# PRs
gh pr list --json number,title,headRefName,author,labels,additions,deletions,changedFiles,createdAt,updatedAt,reviewDecision,isDraft --limit 50

# Issues
gh issue list --json number,title,labels,author,createdAt,updatedAt,comments --limit 50
```

### 2. Phase 1 — Lightweight Parallel Analysis (no checkout)

For each PR/issue, gather analysis data **without** checking out branches:

#### PR Analysis (parallel — one agent per PR, max 5 concurrent)

Spawn parallel agents in a **single message**:

```
Task("Triage PR #{number}: {title}", subagent_type: "general-purpose",
  prompt: "Analyze this PR without checking out the branch.

  PR #{number}: {title}
  Author: {author}
  Branch: {headRefName}
  Changed files: {changedFiles}, +{additions}/-{deletions}
  Labels: {labels}
  Review status: {reviewDecision}
  Draft: {isDraft}

  Steps:
  1. Run: gh pr diff {number}
  2. Run: gh pr view {number} --comments
  3. Analyze the diff for:
     - What the PR does (1-2 sentence summary)
     - Risk level: Critical (core logic, auth, data) / Medium (features, UI) / Low (docs, config, tests)
     - Complexity: High (>10 files or cross-cutting) / Medium (3-10 files) / Low (<3 files)
     - Whether build/test verification is needed (yes/no + reason)
     - Potential issues or concerns (max 3)
     - Suggested reviewers or labels if obvious

  Output as structured text:
  SUMMARY: ...
  RISK: Critical|Medium|Low
  COMPLEXITY: High|Medium|Low
  NEEDS_DEEP: yes|no
  DEEP_REASON: ... (if yes)
  CONCERNS: ...
  SUGGESTION: ...")
```

#### Issue Analysis (parallel — one agent per batch of 5 issues)

```
Task("Triage Issues #{n1}-#{n5}", subagent_type: "general-purpose",
  prompt: "Analyze these issues:
  {issue list with titles, labels, comment count}

  For each issue:
  1. Read issue body and comments: gh issue view {number} --comments
  2. Classify:
     - Type: Bug / Feature / Enhancement / Question / Maintenance
     - Priority: P0 (blocking) / P1 (important) / P2 (nice-to-have) / P3 (backlog)
     - Estimated effort: Small (< 1 day) / Medium (1-3 days) / Large (3+ days)
     - Related PRs (if any mentioned)
  3. One-line summary

  Output as structured text per issue:
  ISSUE #{number}: {title}
  TYPE: ...
  PRIORITY: P0|P1|P2|P3
  EFFORT: Small|Medium|Large
  RELATED_PR: #N or none
  SUMMARY: ...")
```

### 3. Phase 2 — Selective Deep Analysis (worktree, optional)

From Phase 1 results, identify PRs where `NEEDS_DEEP: yes`.

For each deep-analysis PR, spawn a **worktree-isolated agent**:

```
Task("Deep triage PR #{number}", subagent_type: "afc:afc-pr-analyst",
  isolation: "worktree",
  prompt: "Deep-analyze PR #{number} ({title}).

  Branch: {headRefName}
  Phase 1 concerns: {concerns from Phase 1}

  Steps:
  1. Checkout the PR branch: gh pr checkout {number}
  2. Run project CI/test commands if available (from .claude/afc.config.md or CLAUDE.md)
  3. Check for type errors, lint issues, test failures
  4. Analyze architectural impact
  5. Report findings

  Output:
  BUILD_STATUS: pass|fail|skip
  TEST_STATUS: pass|fail|skip (N passed, M failed)
  LINT_STATUS: pass|fail|skip
  DEEP_FINDINGS: ...
  RECOMMENDATION: merge|request-changes|needs-discussion")
```

**Important**: Launch at most 3 worktree agents concurrently to avoid resource contention.

If `--deep` flag was specified, run Phase 2 for **all** PRs regardless of Phase 1 classification.

### 4. Consolidate Triage Report

Merge Phase 1 and Phase 2 results into a single report:

```markdown
# Triage Report

> Date: {YYYY-MM-DD}
> Repository: {owner/repo}
> Scope: {PRs: N, Issues: M}

## PRs ({count})

### Priority Actions

| # | Title | Risk | Complexity | Status | Action |
|---|-------|------|------------|--------|--------|
| {sorted by: Critical first, then by staleness} |

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
| {sorted by priority, then by creation date} |

## Summary

- **Immediate attention**: {list of Critical PRs and P0 issues}
- **Ready to merge**: {PRs with no concerns and passing checks}
- **Needs discussion**: {PRs/issues requiring team input}
- **Stale items**: {PRs/issues with no activity > 14 days}
```

### 5. Save Report

Save the triage report:

```
.claude/afc/memory/triage/{YYYY-MM-DD}.md
```

If a previous triage report exists for today, overwrite it.

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

- **Read-only**: Triage does not modify any code, merge PRs, or close issues.
- **Rate limits**: `gh` API calls are rate-limited. For repos with 50+ open items, consider using `--pr` or `--issue` to reduce scope.
- **Worktree cleanup**: Worktree agents auto-clean on completion. If a worktree is left behind, use `git worktree prune`.
- **NEVER use `run_in_background: true` on Phase 1 Task calls**: agents must run in foreground so results are collected before consolidation. Phase 2 worktree agents also run in foreground.
- **Parallel limits**: Phase 1 — max 5 concurrent agents. Phase 2 — max 3 concurrent worktree agents.
