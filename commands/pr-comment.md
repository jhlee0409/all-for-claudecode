---
name: afc:pr-comment
description: "Post PR review comments to GitHub"
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

## Arguments

- `$ARGUMENTS` — PR number (required), with optional severity filter
  - `42` — Analyze and post review for PR #42
  - `42 --severity critical,warning` — Only include Critical and Warning findings
  - `42 --severity critical` — Only include Critical findings

Parse the arguments:
1. Extract the PR number (first numeric argument)
2. Extract `--severity` filter if present (comma-separated list of: `critical`, `warning`, `info`)
3. If no PR number is found, ask the user: "Which PR number should I review?"

## Execution Steps

### 1. Collect PR Information

```bash
gh pr view {number} --json number,title,headRefName,author,body,additions,deletions,changedFiles,labels,reviewDecision,state
```

```bash
gh pr diff {number}
```

Verify the PR exists and is open. If closed/merged, inform the user and ask whether to proceed anyway.

### 2. Check for Existing Triage Report

Look for a recent triage report that covers this PR:

```bash
ls -t .claude/afc/memory/triage/*.md 2>/dev/null | head -5
```

If a report exists from today, search it for `PR #{number}` analysis. If found, reuse that analysis as the basis for the review instead of re-analyzing from scratch.

### 3. Analyze PR (if no triage data available)

If no existing triage report covers this PR, perform a focused review of the diff.

Examine the diff from the following perspectives (abbreviated from review.md):

#### A. Code Quality
- Style compliance, naming conventions, unnecessary complexity

#### B. Architecture
- Layer violations, boundary crossings, structural concerns

#### C. Security
- XSS, injection, sensitive data exposure, auth issues

#### D. Performance
- Latency concerns, unnecessary computation, resource leaks

#### E. Maintainability
- Function/file size, naming clarity, readability

Classify each finding with a severity:
- **Critical (C)** — Must fix before merge. Bugs, security vulnerabilities, data loss risks.
- **Warning (W)** — Should fix. Code quality issues, potential problems, maintainability concerns.
- **Info (I)** — Nice to have. Suggestions, minor improvements, style preferences.

### 4. Apply Severity Filter

If `--severity` was specified, filter findings to only include the specified severity levels.

Default (no filter): include all severity levels.

### 5. Generate Review Comment

Compose the review comment in this format:

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

If there are zero findings after filtering, the comment should be:

```markdown
## AFC Code Review — PR #{number}

No issues found. Code looks good!

---
*Reviewed by [all-for-claudecode](https://github.com/anthropics/claude-code)*
```

### 6. Preview and Confirm

Display the full review comment to the user in the console.

Then determine the review event type:
- **Critical findings exist** → `REQUEST_CHANGES`
- **Only Warning/Info findings** → `COMMENT`
- **No findings** → `APPROVE`

Tell the user:
```
Review event: {APPROVE|COMMENT|REQUEST_CHANGES}
Findings: Critical {N} / Warning {N} / Info {N}
```

Ask the user to confirm using AskUserQuestion with these options:
1. **Post as-is** — Post the review comment to GitHub
2. **Edit first** — Let me modify the comment before posting (user provides edits, then re-confirm)
3. **Cancel** — Do not post anything

### 7. Post to GitHub

On approval, write the review comment to a temp file and post via `--body-file` (avoids shell escaping issues with markdown):

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
└─ URL: {PR URL from gh pr view}
```

## Notes

- **User confirmation required**: Never post to GitHub without explicit user approval.
- **Idempotent**: Running multiple times on the same PR creates additional review comments (GitHub does not deduplicate).
- **Respects existing reviews**: This command does not dismiss or override other reviewers' reviews.
- **Rate limits**: Uses a single `gh pr review` call. No rate limit concerns for normal usage.
