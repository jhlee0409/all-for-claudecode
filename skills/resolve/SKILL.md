---
name: afc:resolve
description: "Analyze and address LLM review comments on PR — use when the user asks to resolve, fix, or respond to bot review comments (CodeRabbit, Copilot, Codex) on a pull request"
argument-hint: "<PR number or URL>"
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

Collects LLM bot review comments from a PR, classifies as VALID/NOISE/DISCUSS, fixes VALID items, resolves addressed threads on GitHub, and outputs a summary report.

## Arguments

- `$ARGUMENTS` — (required) Any format that identifies a PR (number, URL, cross-repo, etc.)

## PR Context

!`gh pr view $(echo "$ARGUMENTS" | grep -oE '[0-9]+' | head -1) --json url,title,headRefName,comments 2>/dev/null || echo "PR_FETCH_FAILED"`

## Execution Steps

### 1. Prerequisites

```bash
gh --version >/dev/null 2>&1 && gh auth status >/dev/null 2>&1
```

Fails → `[afc:resolve] Error: gh CLI not installed or not authenticated.` → **abort**.

### 2. Identify PR

Extract PR number from `$ARGUMENTS` by intent. If `owner/repo` info is included, use `--repo` flag. Otherwise derive via `gh repo view --json owner,name`.

If "PR Context" above shows `PR_FETCH_FAILED`, parse `$ARGUMENTS` manually and retry.

### 3. Collect Review Data

```bash
gh api repos/{owner}/{repo}/pulls/{number}/comments --paginate
```

Also fetch review threads for resolve (Step 8). See [graphql.md](graphql.md) for the query.

### 4. Filter Bot Comments

Keep only comments from authors whose login ends with `[bot]`. Tag `outdated` comments as `[OUTDATED]`.

0 bot comments → `No LLM bot review comments found on PR #{number}.` → **exit**.

### 5. Check Working Tree

```bash
git status --porcelain
```

Dirty → list files, ask user to confirm before proceeding.

### 6. Classify

Read each comment's target file (±10 lines context), then classify:

| Class | When | Action |
|-------|------|--------|
| **VALID** | Objectively verifiable bug, single fix approach, resolvable within existing code | Fix |
| **NOISE** | Style preference, intentional design, false positive, `[OUTDATED]` | Skip |
| **DISCUSS** | Requires judgment (new dependency, tradeoff, threshold, API change, etc.) | Ask |

**Key: when in doubt, classify as DISCUSS. Be conservative with VALID.**

### 7. Present Summary

**MUST output before any code changes:**

```
PR #{number}: {title}
Branch: {headRefName}
Bot comments: {total} ({bot_names})

VALID ({n}):  1. [{bot}] {file}:{line} — {summary}
NOISE ({n}):  1. [{bot}] {file}:{line} — {skip reason}
DISCUSS ({n}): 1. [{bot}] {file}:{line} — {question}
```

### 8. Handle DISCUSS

Each item → present comment, target code (5 lines), tradeoff → ask user:
1. Apply → move to VALID
2. Skip → move to NOISE
3. Defer → stays DISCUSS

### 9. Apply Fixes

For each VALID item:
1. Read target file
2. Apply minimal fix via Edit
3. Verify modified area

**Feedback loop**: after all fixes, run project tests if available. If tests fail → diagnose and fix → rerun. Repeat until pass or user decides to stop.

### 10. Resolve Threads on GitHub

See [graphql.md](graphql.md) for the mutation.

| Classification | Resolve? |
|---------------|----------|
| VALID (fixed) | Yes |
| NOISE | Yes (user decided to skip) |
| DISCUSS-Apply | Yes |
| DISCUSS-Skip | Yes |
| DISCUSS-Defer | **No** (revisit later) |
| Already resolved | Skip |

GraphQL failure → warn, **do not abort**.

### 11. Commit

No fixes applied → skip to Step 12.

Show summary + resolved thread count → **wait for user confirmation** (NFR-003).

```
resolve LLM review comments on #{number}

- fix: {description} ({bot_name})
- skip: {reason} (NOISE, {count} items)
```

Do **NOT** push.

### 12. Output Report

**MUST always output**, even if interrupted:

```
Resolve complete
├─ PR: #{number} — {title}
├─ Bot comments: {total} ({bot_names})
├─ VALID: {n} (applied)
├─ NOISE: {n} (skipped)
├─ DISCUSS: {n} (applied: {a}, skipped: {s}, deferred: {d})
├─ Tests: {pass}/{total} passed
├─ Threads resolved: {resolved}/{addressed}
├─ Commit: {hash} ({files} files, +{add}/-{del})
└─ Push: not pushed (run 'git push' when ready)
```

## Completion Guarantee

MUST reach Step 12 before returning control. If user sends unrelated request mid-flow → output partial report with `[INTERRUPTED]` → then address new request.

## Notes

- Human comments are ignored (use `afc:review`). No auto-push. Thread resolution needs `repo` scope.
- Idempotent: re-run skips already-addressed comments and resolved threads.
