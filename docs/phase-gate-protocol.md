# Phase Completion Gate (3 Steps)

After each Phase completes, perform **3-step verification** sequentially:

## Step 1. CI Gate

```bash
{config.gate}
```

- **Pass**: proceed to Step 2
- **Fail**:
  1. Analyze error messages
  2. Fix relevant task files
  3. Re-verify
  4. After 3 failures → report to user and **halt**

## Step 2. Mini-Review

Quantitatively inspect `{config.mini_review}` items for files changed within the Phase:
- List changed files and perform the inspection **for each file**
- Output format:
  ```
  Mini-Review ({N} files):
  - file1.tsx: ✓ all items passed
  - file2.tsx: ⚠ {item} violation → fix
  - Violations: {M} → fix then re-run CI gate
  ```
- If issues found → fix immediately, then re-run CI Gate (Step 1)
- If no issues → `✓ Phase {N} Mini-Review passed`

## Step 3. Auto-Checkpoint

After passing the Phase gate, automatically save session state:

```markdown
# .claude/selfish/memory/checkpoint.md auto-update
Current Phase: {N}/{total}
Completed tasks: {list of completed IDs}
Changed files: {file list}
Last CI: ✓
```

- Even if the session is interrupted, resume from this point with `/selfish:resume`
