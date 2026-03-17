---
name: afc:resolve
description: "Analyze and address LLM review comments on PR — use when the user asks to resolve, fix, or respond to bot review comments (CodeRabbit, Copilot, Codex) on a pull request"
argument-hint: "<PR URL, owner/repo#number, #number, or number>"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Edit
  - Write
  - AskUserQuestion
model: sonnet
---

# /afc:resolve — LLM Review Comment Resolution

> Collects LLM bot review comments (CodeRabbit, Copilot, Codex, etc.) from a PR, classifies each as VALID/NOISE/DISCUSS, applies fixes for VALID items, and asks the user about DISCUSS items.
> Creates a single commit with all fixes and outputs a summary report.

## Arguments

- `$ARGUMENTS` — (required) One of:
  - PR number: `456` or `#456`
  - GitHub URL: `https://github.com/owner/repo/pull/456`
  - Cross-repo: `owner/repo#456`

## Execution Steps

### 1. Prerequisites Check

Verify `gh` CLI is available and authenticated:

```bash
gh --version >/dev/null 2>&1 && gh auth status >/dev/null 2>&1
```

If either check fails:
- Output: `[afc:resolve] Error: GitHub CLI (gh) is not installed or not authenticated. Install from https://cli.github.com/ and run 'gh auth login'.`
- **Abort immediately.**

### 2. Parse Input

Determine the input format and extract owner, repo, and PR number:

1. **GitHub URL** (`https://github.com/{owner}/{repo}/pull/{number}`):
   - Extract owner, repo, number from URL path segments
   - Set `GH_REPO_FLAG="--repo {owner}/{repo}"`

2. **Cross-repo** (`{owner}/{repo}#{number}`):
   - Split on `#` — left part is `owner/repo`, right part is number
   - Set `GH_REPO_FLAG="--repo {owner}/{repo}"`

3. **Local number** (`456` or `#456`):
   - Strip leading `#` if present
   - Set `GH_REPO_FLAG=""` (use current repo from git remote)

### 3. Collect Review Comments

Collect all review comments from the PR:

```bash
gh pr view {number} {GH_REPO_FLAG} --json reviews,comments,url,title,headRefName
```

Additionally, collect inline review comments:

```bash
gh api repos/{owner}/{repo}/pulls/{number}/comments --paginate
```

If `--repo` flag was not used, derive owner/repo from `gh repo view --json owner,name`.

If API call fails → output the error and **abort**.

### 4. Filter Bot Comments

Identify LLM bot comments by checking the comment author's login:

**Known bot patterns**:
- `coderabbitai[bot]` — CodeRabbit
- `copilot[bot]` or `github-copilot[bot]` — GitHub Copilot
- `codex[bot]` — Codex
- Any login ending with `[bot]` — generic bot detection

**Filter rules**:
- Keep only comments where the author matches a bot pattern
- Discard all human reviewer comments (MVP scope)
- If an inline comment is marked as `outdated` by GitHub → tag as `[OUTDATED]`

If 0 bot comments found:
- Output: `No LLM bot review comments found on PR #{number}.`
- **Exit gracefully** (success, not error).

### 5. Classify Each Comment

For each bot comment, analyze the content and classify:

| Classification | Criteria | Action |
|---------------|----------|--------|
| **VALID** | Real bug, security issue, clear improvement, correct suggestion with code context | Auto-fix |
| **NOISE** | Style preference difference, intentional design choice, false positive, already addressed | Skip |
| **DISCUSS** | Architecture decision needed, tradeoff exists, multiple valid approaches, no code `path`/`position` (non-code feedback) | Ask user |

**Classification guidelines**:
- If the comment points to a concrete bug (null check, off-by-one, resource leak) → **VALID**
- If the comment is about naming convention or style that differs from project rules → **NOISE**
- If the comment suggests a refactor with pros/cons → **DISCUSS**
- If multiple bots give conflicting advice on the same line → **DISCUSS**
- If the comment is on an `[OUTDATED]` diff → **NOISE** (code already changed)

Also collect from each comment:
- `file_path`: the file the comment targets
- `line`: the line number (if available)
- `suggestion`: the suggested change (if available)
- `body`: the full comment text

### 6. Present Classification Summary

Before making any changes, present the classification to the user:

```
PR #{number}: {title}
Branch: {headRefName}

Bot comments: {total_count} ({bot_names})

VALID ({count}):
  1. [{bot}] {file}:{line} — {1-line summary of issue}
  2. [{bot}] {file}:{line} — {1-line summary of issue}

NOISE ({count}):
  1. [{bot}] {file}:{line} — {reason for skipping}

DISCUSS ({count}):
  1. [{bot}] {file}:{line} — {question for user}
```

### 7. Handle DISCUSS Items

For each DISCUSS item, present to the user:

```
[DISCUSS #{n}] {bot_name} on {file}:{line}

Comment:
> {original comment text, truncated to 500 chars}

Target code:
> {relevant code snippet, 5 lines context}

If applied: {description of what would change}
Tradeoff: {why this is not a clear-cut decision}

Options:
  1. Apply — treat as VALID, fix the code
  2. Skip — treat as NOISE, record skip reason
  3. Defer — skip for now, revisit later
```

Wait for user response. Reclassify based on choice:
- `Apply` → move to VALID list
- `Skip` → move to NOISE list with user's reason
- `Defer` → keep as DISCUSS in report

### 8. Apply VALID Fixes

For each VALID comment (including user-accepted DISCUSS items):

1. **Read the target file** before modifying
2. **Identify the exact location** from the comment's `file_path` and `line`
3. **Apply the fix** using Edit tool:
   - If the bot provided a specific code suggestion → apply it
   - If the bot described the issue without a suggestion → implement the fix based on the description
4. **Verify** the fix doesn't break the immediate surrounding code context

If the target file is in a dirty state (uncommitted changes unrelated to this PR):
- Warn user: `{file} has uncommitted changes not related to this PR. Proceed?`
- If user declines → skip this fix, note in report

If the target file was deleted in the PR branch:
- Skip, note `[FILE DELETED]` in report

### 9. Commit Changes

**Before committing**, show the user a summary of all changes:

```
Changes to commit:
  {file1}: {description of change}
  {file2}: {description of change}
  Total: {N} files changed

Proceed with commit? (y/n)
```

**Wait for user confirmation** before committing. This is a safety requirement.

**Commit strategy**:
- If VALID items ≤ 9: single commit
- If VALID items ≥ 10: group by file/module into 2-3 commits

**Commit message format** (single commit):
```
resolve LLM review comments on #{number}

- fix: {description} ({bot_name})
- fix: {description} ({bot_name})
- skip: {reason} (NOISE, {count} items)
```

Do **NOT** push automatically. The user decides when to push.

### 10. Output Report

```
Resolve complete
├─ PR: #{number} — {title}
├─ Bot comments: {total} ({bot_names})
├─ VALID: {count} (applied)
├─ NOISE: {count} (skipped)
├─ DISCUSS: {count} (applied: {n}, skipped: {n}, deferred: {n})
├─ Commit: {hash} ({files_changed} files, +{additions}/-{deletions})
└─ Push: not pushed (run 'git push' when ready)
```

If no VALID items were found (all NOISE/DISCUSS-skipped):
```
Resolve complete
├─ PR: #{number} — {title}
├─ Bot comments: {total} ({bot_names})
├─ VALID: 0
├─ NOISE: {count}
├─ DISCUSS: {count} (all skipped/deferred)
└─ No changes made
```

## Notes

- **MVP scope**: Only bot comments are analyzed. Human reviewer comments are ignored. Use `afc:review` for human-initiated code review.
- **No auto-push**: Changes are committed but never pushed automatically. The user controls when to push.
- **User confirmation required**: All code changes must be confirmed by the user before committing (NFR-003 safety requirement).
- **Not part of auto pipeline**: This is a standalone skill invoked manually.
- **Idempotency**: Re-running on the same PR will skip comments that have already been addressed (the code diff won't match the bot's original concern).
- **Relationship to other skills**: `afc:review` does full code review. `afc:pr-comment` posts review comments. `afc:resolve` addresses existing bot comments. They are complementary.
