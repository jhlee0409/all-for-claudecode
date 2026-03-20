---
name: afc:issue
description: "Analyze GitHub issue and create actionable document — use when the user asks to analyze a GitHub issue, understand an issue, or inspect a specific issue number"
argument-hint: "<GitHub issue URL, owner/repo#number, #number, or number>"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - WebFetch
  - Write
model: sonnet
---

# /afc:issue — GitHub Issue Analysis

> Analyzes a single GitHub issue (title, body, labels, comments, attached images) and produces a structured analysis document.
> Searches the codebase for related files and suggests the appropriate next afc skill (debug, spec, or auto).

## Pre-fetch

!`gh --version >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && echo "GH_OK" || echo "GH_UNAVAILABLE"`

## Arguments

- `$ARGUMENTS` — (required) One of:
  - Issue number: `123` or `#123`
  - GitHub URL: `https://github.com/owner/repo/issues/123`
  - Cross-repo: `owner/repo#123`

## Execution Steps

### 1. Prerequisites Check

If the pre-fetch returned `GH_UNAVAILABLE`:
- Output: `[afc:issue] Error: GitHub CLI (gh) is not installed or not authenticated. Install from https://cli.github.com/ and run 'gh auth login'.`
- **Abort immediately.**

### 2. Parse Input

Determine the input format and extract owner, repo, and issue number:

1. **GitHub URL** (`https://github.com/{owner}/{repo}/issues/{number}`): extract from path, set `GH_REPO_FLAG="--repo {owner}/{repo}"`
2. **Cross-repo** (`{owner}/{repo}#{number}`): split on `#`, set `GH_REPO_FLAG="--repo {owner}/{repo}"`
3. **Local number** (`123` or `#123`): strip leading `#`, set `GH_REPO_FLAG=""` (use current repo from git remote)

### 3. Collect Issue Data

```bash
gh issue view {number} {GH_REPO_FLAG} --json number,title,body,labels,author,comments,createdAt,state,url
```

If the command fails → output error and **abort**.

Parse and extract: `TITLE`, `BODY`, `LABELS`, `AUTHOR`, `COMMENTS`, `CREATED_AT`, `STATE`, `URL`.

### 4. Analyze Attached Images

Extract image URLs from the issue body (skip images inside code block fences):
- Markdown: `![alt]({url})`
- HTML: `<img src="{url}">`

For each URL: fetch with WebFetch, analyze content (error messages, UI screenshots, console output, stack traces), tag results with `[Image Analysis]`. Record failures as `[Image unavailable: {url}]`.

If no images: note `No attached media found.`

### 5. Analyze Comments

If more than 20 comments: analyze only the **most recent 20** and note `"Analyzed 20 of {N} comments (most recent)"`.

Extract: reproduction steps, error logs, workarounds, maintainer responses, related issue/PR references.

### 6. Search Codebase

Extract keywords from title, body, and comments:
- Error messages (quoted strings, stack trace patterns)
- Function/class/module names, file paths, project-specific technical terms

Search with Grep and Glob. Record matching files with line numbers and relevance reason. If no matches: `No related code found in current codebase.`

### 7. Classify Issue

**Type** — choose the strongest matching signal:

| Signal | Type |
|--------|------|
| Error messages, stack traces, "broken", "doesn't work", reproduction steps | **Bug Report** |
| "Add", "support", "new feature", "would be nice", "enhancement" | **Feature Request** |
| "How to", "is it possible", "what is", "documentation" | **Question** |
| "Improve", "refactor", "better", "optimize", existing feature modification | **Enhancement** |

**Severity** — based on production impact, not code location:

| Level | Criteria |
|-------|---------|
| **Critical** | Data loss, security vulnerability, application crash, or complete feature unavailability with no workaround |
| **High** | Core functionality broken; workaround exists but is painful or undocumented |
| **Medium** | Non-critical functionality impacted; reasonable workaround available, or significant UX degradation |
| **Low** | Cosmetic issue, minor UX friction, or improvement with no functional impact |

**Estimated Scope:**

| Level | Criteria |
|-------|---------|
| **Small** | 1–2 files — typo, config change, isolated bug fix |
| **Medium** | 3–5 files — feature addition, moderate refactor |
| **Large** | 6+ files — cross-cutting concern, architectural change |

### 8. Determine Next Step

| Type | Suggested Next Step |
|------|-------------------|
| Bug Report | `/afc:debug "{issue title summary}"` |
| Feature Request | `/afc:spec "{feature description}"` or `/afc:auto "{feature description}"` |
| Question | Reply to issue — provide answer or point to documentation |
| Enhancement | `/afc:spec "{enhancement description}"` |
| Insufficient info | Reply to issue — request: {specific missing information} |

### 9. Save Analysis Document

```bash
mkdir -p .claude/afc/issues
```

If `.claude/afc/issues/{number}-*.md` exists → ask user: "Overwrite existing analysis for issue #{number}?"

Generate slug from title: lowercase, replace non-alphanumeric with `-`, truncate to 40 chars.

Write to `.claude/afc/issues/{number}-{slug}.md`:

```markdown
# Issue #{number}: {title}

> Analyzed: {YYYY-MM-DD}
> Source: {url}
> Labels: {labels, comma-separated}
> Author: {author}
> State: {Open/Closed}

## Summary

{2-4 sentence summary including context from body, comments, and images — not just a restatement of the title.}

## Attached Media Analysis

{If images exist:}
> [Image Analysis] Below is AI interpretation of attached media.

- **Image 1** ({filename or "screenshot"}): {description}

{If no images:}
No attached media found.

## Codebase Impact

- `{path}:{line}` — {why this file is related}

{If no related files:}
No related code found in current codebase.

## Classification

- **Type**: {Bug Report | Feature Request | Question | Enhancement}
- **Severity**: {Critical | High | Medium | Low}
- **Estimated Scope**: {Small (1-2 files) | Medium (3-5) | Large (6+)}

## Suggested Next Step

- [ ] {Primary suggestion with full command} — {reason}
- [ ] {Secondary suggestion if applicable} — {reason}
```

### 10. Output Summary

```
Issue analyzed
├─ Issue: #{number} — {title}
├─ Type: {classification}
├─ Severity: {severity}
├─ Related files: {count}
├─ Document: .claude/afc/issues/{number}-{slug}.md
└─ Next step: {primary suggestion}
```

## Notes

- **Read-only**: Does not modify any code. Only creates an analysis document.
- **Image analysis is best-effort**: AI interpretation of screenshots may be imprecise — `[Image Analysis]` tag makes this explicit.
- **Not part of auto pipeline**: Standalone skill, invoked manually.
- **Relationship to triage**: `afc:triage` handles bulk analysis; `afc:issue` handles deep individual analysis.
- **Comment limit**: Max 20 comments analyzed (most recent prioritized).
