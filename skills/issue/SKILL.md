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

## Arguments

- `$ARGUMENTS` — (required) One of:
  - Issue number: `123` or `#123`
  - GitHub URL: `https://github.com/owner/repo/issues/123`
  - Cross-repo: `owner/repo#123`

## Execution Steps

### 1. Prerequisites Check

Verify `gh` CLI is available and authenticated:

```bash
gh --version >/dev/null 2>&1 && gh auth status >/dev/null 2>&1
```

If either check fails:
- Output: `[afc:issue] Error: GitHub CLI (gh) is not installed or not authenticated. Install from https://cli.github.com/ and run 'gh auth login'.`
- **Abort immediately.**

### 2. Parse Input

Determine the input format and extract owner, repo, and issue number:

1. **GitHub URL** (`https://github.com/{owner}/{repo}/issues/{number}`):
   - Extract owner, repo, number from URL path segments
   - Set `GH_REPO_FLAG="--repo {owner}/{repo}"`

2. **Cross-repo** (`{owner}/{repo}#{number}`):
   - Split on `#` — left part is `owner/repo`, right part is number
   - Set `GH_REPO_FLAG="--repo {owner}/{repo}"`

3. **Local number** (`123` or `#123`):
   - Strip leading `#` if present
   - Set `GH_REPO_FLAG=""` (use current repo from git remote)

### 3. Collect Issue Data

```bash
gh issue view {number} {GH_REPO_FLAG} --json number,title,body,labels,author,comments,createdAt,state,url
```

If the command fails:
- `Issue #{number} not found` → output error and **abort**
- Other errors → output the gh error message and **abort**

Parse the JSON response and extract:
- `TITLE`, `BODY`, `LABELS`, `AUTHOR`, `COMMENTS`, `CREATED_AT`, `STATE`, `URL`

### 4. Analyze Attached Images

Extract image URLs from the issue body:
- Markdown images: `![alt]({url})`
- HTML images: `<img src="{url}">`
- **Skip** images inside code blocks (` ``` ` fences)

For each extracted image URL:
1. Attempt to fetch with WebFetch
2. If successful: analyze the image content (error messages, UI screenshots, console output, stack traces)
3. If fetch fails: record `[Image unavailable: {url}]`

Tag all image analysis results with `[Image Analysis]` to indicate AI interpretation.

If no images found: note `No attached media found.`

### 5. Analyze Comments

If comments exist:
- If more than 20 comments: analyze only the **most recent 20** and note `"Analyzed 20 of {N} comments (most recent)"`
- Extract additional context from comments: reproduction steps, error logs, workarounds, maintainer responses, related issue/PR references

### 6. Search Codebase

Extract keywords from the issue title, body, and comments:
- Error messages (quoted strings, stack trace patterns)
- Function/class/module names
- File paths mentioned
- Technical terms specific to the project

For each keyword, search the codebase using Grep and Glob:
- Record matching files with line numbers and relevance reason
- If no matches found: note `No related code found in current codebase.`

### 7. Classify Issue

Based on the analysis, classify the issue:

| Signal | Classification |
|--------|---------------|
| Error messages, stack traces, reproduction steps, "doesn't work", "broken" | **Bug Report** |
| "Add", "support", "new feature", "would be nice", "enhancement" | **Feature Request** |
| "How to", "is it possible", "what is", "documentation" | **Question** |
| "Improve", "refactor", "better", "optimize", existing feature modification | **Enhancement** |

Assess severity:
- **Critical**: Data loss, security vulnerability, crash, blocks usage
- **High**: Major functionality broken, no workaround
- **Medium**: Functionality issue with workaround, or significant UX problem
- **Low**: Minor issue, cosmetic, or nice-to-have improvement

Estimate scope:
- **Small** (1-2 files): Typo, config change, simple bug fix
- **Medium** (3-5 files): Feature addition, moderate refactor
- **Large** (6+ files): Cross-cutting concern, architectural change

### 8. Determine Next Step

Based on classification:

| Type | Suggested Next Step |
|------|-------------------|
| Bug Report | `/afc:debug "{issue title summary}"` |
| Feature Request | `/afc:spec "{feature description}"` or `/afc:auto "{feature description}"` |
| Question | `Reply to issue — provide answer or point to documentation` |
| Enhancement | `/afc:spec "{enhancement description}"` |
| Insufficient info | `Reply to issue — request: {specific missing information}` |

### 9. Save Analysis Document

Create directory if needed:
```bash
mkdir -p .claude/afc/issues
```

Check for existing analysis:
- If `.claude/afc/issues/{number}-*.md` exists → ask user: "Overwrite existing analysis for issue #{number}?"

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

{2-4 sentence summary of what the issue is about and what it requires.
Not just a restatement of the title — include context from body, comments, and images.}

## Attached Media Analysis

{If images exist:}
> [Image Analysis] Below is AI interpretation of attached media.

- **Image 1** ({filename or "screenshot"}): {description of what the image shows — error messages, UI state, console output}
- **Image 2**: ...

{If no images:}
No attached media found.

## Codebase Impact

{If related files found:}
- `{path}:{line}` — {why this file is related}
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

- **Read-only**: This skill does not modify any code. It only creates an analysis document.
- **Image analysis is best-effort**: AI interpretation of screenshots may not be 100% accurate. The `[Image Analysis]` tag makes this explicit.
- **Not part of auto pipeline**: This is a standalone skill invoked manually.
- **Relationship to triage**: `afc:triage` handles bulk PR/issue analysis. `afc:issue` handles deep individual issue analysis. They are complementary.
- **Comment limit**: Max 20 comments analyzed to keep context manageable. Most recent comments are prioritized as they often contain the most relevant information.
