# Phase Completion Gate (3–4 Steps)

After each Phase completes, perform **3–4 step verification** sequentially (Step 2.5 is conditional):

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

## Step 2.5. Integration/E2E Gate (conditional)

When the phase contains **behavioral changes** (call order modifications, error handling changes, state mutation changes — not pure additions or style fixes):

1. Check if `{config.test}` includes integration or E2E tests
2. If yes → run `{config.test}` and verify pass
3. If fail → debug-based RCA (same protocol as Step 1)
4. If `{config.test}` is empty or has no E2E coverage → skip with note: `⚠ No E2E test configured — behavioral changes not integration-tested`

This gate is skipped for phases with only additive changes (new files, new functions with no existing callers).

## Step 3. Auto-Checkpoint

After passing the Phase gate, automatically save session state:

1. Create `.claude/afc/memory/` directory if it does not exist
2. Write/update `.claude/afc/memory/checkpoint.md` **and** `~/.claude/projects/{ENCODED_PATH}/memory/checkpoint.md` (dual-write for compaction resilience — `ENCODED_PATH` = project path with `/` replaced by `-`):

```markdown
# Phase Gate Checkpoint
> Auto-generated: {YYYY-MM-DD HH:mm:ss}
> Trigger: phase gate

## Git Status
- Branch: {current branch}
- Commit: {short hash} — {commit message}

## Pipeline Status
- Active: Yes ({feature name})
- Current Phase: {N}/{total}
- Completed tasks: {list of completed IDs}
- Changed files: {file list}
- Last CI: ✓
```

- Even if the session is interrupted, resume from this point with `/afc:resume`
