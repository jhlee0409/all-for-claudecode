# Phase Completion Gate (3 Steps)

After each Phase completes, perform **3-step verification** sequentially:

## Step 1. CI Gate

```bash
{config.gate}
```

- **Pass**: proceed to Step 2
- **Fail** — use debug-based RCA (not blind retry):
  1. Execute `/afc:debug` logic with the CI error output as input
  2. Debug performs RCA: error trace → data flow → hypothesis → targeted fix
  3. Re-run `{config.gate}` after fix
  4. After 3 debug-fix cycles → report to user with diagnosis details and **halt**

## Step 2. Mini-Review

Quantitatively inspect changed files within the Phase against `{config.code_style}` and `{config.architecture}` rules:
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
# .claude/afc/memory/checkpoint.md auto-update
Current Phase: {N}/{total}
Completed tasks: {list of completed IDs}
Changed files: {file list}
Last CI: ✓
```

- Even if the session is interrupted, resume from this point with `/afc:resume`
