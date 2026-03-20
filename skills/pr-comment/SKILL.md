---
name: afc:pr-comment
description: "Post PR review comments to GitHub — use when the user asks to comment on a PR, post review feedback, or submit structured PR review comments"
argument-hint: "<PR number> [--severity critical,warning,info]"
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - Task
model: sonnet
---

# /afc:pr-comment — Post PR Review to GitHub

> Analyzes a PR and posts a structured review comment to GitHub.
> Reuses existing triage reports when available. Asks for user confirmation before posting.

## Pre-fetch

!`gh pr view $0 --json number,title,headRefName,author,body,additions,deletions,changedFiles,labels,reviewDecision,state,url 2>/dev/null || echo "PR_FETCH_FAILED"`

## Arguments

- `$ARGUMENTS` — PR number (required), with optional severity filter
  - `42` — Analyze and post review for PR #42
  - `42 --severity critical,warning` — Only include Critical and Warning findings
  - `42 --severity critical` — Only include Critical findings

Parse:
1. Extract the PR number (first numeric argument)
2. Extract `--severity` filter if present (comma-separated: `critical`, `warning`, `info`)
3. If no PR number found, ask the user: "Which PR number should I review?"

## Execution Steps

### 1. Collect PR Information

Use the pre-fetched PR metadata. If the pre-fetch returned `PR_FETCH_FAILED`, output `[afc:pr-comment] Error: PR not found or gh not available.` and abort.

Fetch the diff:
```bash
gh pr diff {number}
```

Verify the PR is open. If closed/merged, inform the user and ask whether to proceed anyway.

### 2. Check for Existing Triage Report

```bash
ls -t .claude/afc/memory/triage/*.md 2>/dev/null | head -5
```

If a report from today contains `PR #{number}` analysis, reuse it as the review basis instead of re-analyzing from scratch.

### 3. Analyze PR (if no triage data available)

Review the diff using perspectives A–E from [review/perspectives.md](../review/perspectives.md):

- **A. Code Quality** — style compliance, naming, unnecessary complexity
- **B. Architecture** — layer violations, boundary crossings, structural concerns
- **C. Security** — XSS, injection, sensitive data exposure, auth issues
- **D. Performance** — latency concerns, unnecessary computation, resource leaks
- **E. Maintainability** — function/file size, naming clarity, readability

Classify each finding:
- **Critical (C)** — Must fix before merge: bugs affecting users, security vulnerabilities, data loss risks
- **Warning (W)** — Should fix: code quality issues, potential problems, maintainability concerns
- **Info (I)** — Nice to have: suggestions, minor improvements, style preferences

### 4. Apply Severity Filter

If `--severity` was specified, filter findings to only the listed levels. Default: include all.

### 5. Generate Review Comment

```markdown
## AFC Code Review — PR #{number}

### Summary

| Severity | Count |
|----------|-------|
| Critical | {N} |
| Warning  | {N} |
| Info     | {N} |

### Findings

#### C-{N}: {title}
- **File**: `{path}:{line}`
- **Issue**: {description}
- **Suggested fix**: {suggestion}

#### W-{N}: {title}
{same format}

#### I-{N}: {title}
{same format}

### Positives
- {1-2 things done well}

---
*Reviewed by [all-for-claudecode](https://github.com/anthropics/claude-code)*
```

If zero findings after filtering:
```markdown
## AFC Code Review — PR #{number}

No issues found. Code looks good!

---
*Reviewed by [all-for-claudecode](https://github.com/anthropics/claude-code)*
```

### 6. Preview and Confirm

Display the full review comment to the user.

Determine the review event:

| Event | When to use |
|-------|-------------|
| **REQUEST_CHANGES** | Critical findings in production code that pose genuine risk to users: bugs affecting functionality, security vulnerabilities, or architectural violations costly to fix post-merge. A Critical finding limited to test/docs/config alone does NOT qualify. |
| **COMMENT** | Findings are improvements the author should consider but don't block merging. Also when Critical findings are in non-production code, or the author has already acknowledged the concern in PR discussion. |
| **APPROVE** | No findings, or all findings are informational and code is ready to merge. |

Tell the user:
```
Review event: {APPROVE|COMMENT|REQUEST_CHANGES}
Findings: Critical {N} / Warning {N} / Info {N}
```

Ask for confirmation (AskUserQuestion):
1. **Post as-is** — Post the review comment to GitHub
2. **Edit first** — Let me modify the comment before posting
3. **Cancel** — Do not post anything

### 7. Post to GitHub

```bash
tmp_file=$(mktemp)
cat > "$tmp_file" << 'REVIEW_EOF'
{review comment content}
REVIEW_EOF
gh pr review {number} --body-file "$tmp_file" --event {COMMENT|REQUEST_CHANGES|APPROVE}
rm -f "$tmp_file"
```

### 8. Final Output

```
PR review posted
├─ PR: #{number} ({title})
├─ Event: {APPROVE|COMMENT|REQUEST_CHANGES}
├─ Findings: Critical {N} / Warning {N} / Info {N}
└─ URL: {PR URL}
```

## Notes

- **User confirmation required**: Never post to GitHub without explicit user approval.
- **Verify after posting**: After `gh pr review` completes, confirm success by checking the exit code. If it fails, report the error and suggest manual posting.
- **Idempotent**: Multiple runs create additional review comments (GitHub does not deduplicate).
- **Respects existing reviews**: Does not dismiss or override other reviewers' reviews.
- **Perspectives reference**: Full criteria for A–H in [review/perspectives.md](../review/perspectives.md). This skill uses A–E only (focused on PR-level review, not full pipeline review).
