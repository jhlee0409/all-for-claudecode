---
name: afc:debug
description: "Bug diagnosis and fix — root-cause analysis for errors, crashes, broken behavior"
argument-hint: "[bug description, error message, or reproduction steps]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
model: sonnet
---

# /afc:debug — Bug Diagnosis and Fix

> Analyzes the root cause of a bug and fixes it.
> Validates the safety and accuracy of the fix with convergence-based Critic Loop.

## Arguments

- `$ARGUMENTS` — (required) Bug description, error message, or reproduction steps

## Project Config (auto-loaded)

!`cat .claude/afc.config.md 2>/dev/null || echo "[CONFIG NOT FOUND] .claude/afc.config.md not found. Create it with /afc:init."`

## Execution Steps

### 1. Gather Information

1. Extract from `$ARGUMENTS`:
   - **Symptom**: what is going wrong?
   - **Reproduction conditions**: when does it occur?
   - **Error message**: full text if available
   - **Expected behavior**: what should happen?

2. Ask user for additional information if needed (max 2 questions)

### 2. Root Cause Analysis (RCA)

Proceed in order, applying **adaptive skipping** based on symptom type:

1. **Error trace**: extract file:line from error message/stack trace → read that code
2. **Data flow**: trace backwards from the problem point (where did the bad data come in?) — *skip if error trace already identifies root cause with high confidence*
3. **State analysis**: check relevant state management cache state (from Project Context) — *skip if bug is clearly a syntax/type/null-reference error with no state involvement*
4. **Recent changes**: check recent changes with `git log --oneline -10 -- {related files}` — *skip if bug is clearly pre-existing (user reports it "always" fails)*
5. **Race conditions**: check for timing issues between async operations — *skip if bug is deterministic (same input always fails, no async/concurrent context)*

When skipping a step, note: `"Skipped: {reason}"`. Do not skip steps 1 and 2 unless step 1 alone identifies the root cause.

### 3. Form Hypotheses

List possible causes as a **hypothesis list**:

```markdown
### Hypotheses
0. **[Not a Bug?]** {intended behavior explanation}: {evidence from docs/code/spec}
1. **[High probability]** {cause1}: {evidence}
2. **[Medium probability]** {cause2}: {evidence}
3. **[Low probability]** {cause3}: {evidence}
```

**Always evaluate hypothesis 0 first.** Check:
- Is this behavior documented or specified? (README, comments, spec, CLAUDE.md)
- Does the code explicitly handle this case? (intentional logic, not missing logic)
- Is the user's expectation based on a misunderstanding of the design?

If hypothesis 0 is confirmed (not a bug):
- Report: "This appears to be intended behavior: {explanation with evidence}."
- Do **not** modify code. Suggest documentation improvement if the behavior is non-obvious.
- Skip Steps 4-6. Go directly to Final Output with verdict: `"Not a bug — intended behavior."`

If hypothesis 0 is rejected: verify remaining hypotheses starting from highest probability.

### 4. Implement Fix

**Precondition**: Only proceed if a genuine bug was confirmed in Step 3 (hypothesis 0 rejected).

1. **Minimal change principle**: change only the minimum code required to fix the bug
2. **Impact analysis**: verify what effect the fix has on other code
3. **Apply fix**

### 5. Critic Loop

> **Always** read `${CLAUDE_SKILL_DIR}/../../docs/critic-loop-rules.md` first and follow it.

Run the critic loop until convergence. Safety cap: 5 passes.

**Fast-path**: If the fix is a single-line change (null guard, typo, missing import) with no behavioral side effects: run 1 pass with both criteria. If both PASS on the first pass, converge immediately without adversarial challenge.

| Criterion | Validation |
|-----------|------------|
| **SAFETY** | Does the fix break any other functionality? Any side effects? |
| **CORRECTNESS** | Does it actually resolve the root cause? Or just mask the symptom? |

Follow verdict handling and output format per `docs/critic-loop-rules.md`.

### 6. Verification

```bash
{config.gate}
```

Retry after fixing on failure (max 3 attempts).

### 7. Retrospective Entry (if new pattern found)

If this debug session reveals a pattern not previously documented in `.claude/afc/memory/retrospectives/`:

Append to `.claude/afc/memory/retrospectives/{YYYY-MM-DD}.md`:
```markdown
## Pattern: {category}
**What happened**: {concrete description}
**Root cause**: {why this bug occurred}
**Prevention rule**: {actionable rule — usable in future plan/implement phases}
**Severity**: Critical | Warning
```

Only write if the pattern is new and actionable. Generic observations are prohibited.

### 8. Final Output

**If bug confirmed and fixed:**
```
Debug complete
├─ Root cause: {one-line summary}
├─ Fixed files: {file list}
├─ Critic: converged ({N} passes, {M} fixes, {E} escalations)
├─ Verified: typecheck + lint passed
└─ Impact scope: {affected components/features}
```

**If not a bug (intended behavior):**
```
Debug complete
├─ Verdict: Not a bug — intended behavior
├─ Explanation: {why this behavior is correct}
├─ Evidence: {code path, documentation, or spec reference}
├─ Fixed files: none
└─ Suggestion: {documentation improvement if non-obvious, or "none"}
```

## Notes

- **Not every report is a bug**: Always evaluate "intended behavior" hypothesis first. Do not modify code to match incorrect expectations.
- **No excessive changes**: change only what is needed to fix the bug. Do not refactor surrounding code.
- **Symptom vs cause**: find the root cause, not the surface symptom.
- **3-attempt limit**: if fix fails after 3 attempts, report the situation to the user.
