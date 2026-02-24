---
name: afc:debug
description: "Bug diagnosis and fix"
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

## Config Load

**Always** read `.claude/afc.config.md` first.

If config file is missing:
1. Ask the user: "`.claude/afc.config.md` not found. Run `/afc:init` to set up the project?"
2. If user accepts → run `/afc:init`, then **restart this command** with the original `$ARGUMENTS`
3. If user declines → **abort**

## Execution Steps

### 1. Gather Information

1. Extract from `$ARGUMENTS`:
   - **Symptom**: what is going wrong?
   - **Reproduction conditions**: when does it occur?
   - **Error message**: full text if available
   - **Expected behavior**: what should happen?

2. Ask user for additional information if needed (max 2 questions)

### 2. Root Cause Analysis (RCA)

Proceed in order:

1. **Error trace**: extract file:line from error message/stack trace → read that code
2. **Data flow**: trace backwards from the problem point (where did the bad data come in?)
3. **State analysis**: check relevant {config.state_management} cache state
4. **Recent changes**: check recent changes with `git log --oneline -10 -- {related files}`
5. **Race conditions**: check for timing issues between async operations

### 3. Form Hypotheses

List possible causes as a **hypothesis list**:

```markdown
### Hypotheses
1. **[High probability]** {cause1}: {evidence}
2. **[Medium probability]** {cause2}: {evidence}
3. **[Low probability]** {cause3}: {evidence}
```

Verify starting from highest probability.

### 4. Implement Fix

1. **Minimal change principle**: change only the minimum code required to fix the bug
2. **Impact analysis**: verify what effect the fix has on other code
3. **Apply fix**

### 5. Critic Loop

> **Always** read `${CLAUDE_PLUGIN_ROOT}/docs/critic-loop-rules.md` first and follow it.

Run the critic loop until convergence. Safety cap: 5 passes.

| Criterion | Validation |
|-----------|------------|
| **SAFETY** | Does the fix break any other functionality? Any side effects? |
| **CORRECTNESS** | Does it actually resolve the root cause? Or just mask the symptom? |

**On FAIL**: auto-fix and continue to next pass.
**On ESCALATE**: pause, present options to user, apply choice, resume.
**On DEFER**: record reason, mark criterion clean, continue.
**On CONVERGE**: `✓ Critic converged ({N} passes, {M} fixes, {E} escalations)`
**On SAFETY CAP**: `⚠ Critic safety cap ({N} passes). Review recommended.`

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

```
Debug complete
├─ Root cause: {one-line summary}
├─ Fixed files: {file list}
├─ Critic: converged ({N} passes, {M} fixes, {E} escalations)
├─ Verified: typecheck + lint passed
└─ Impact scope: {affected components/features}
```

## Debugging Checklist (applied automatically)

Always check the Debugging Checklist from CLAUDE.md:
1. Race Conditions — contention between async operations
2. Stale State — stale state references
3. Missing Error Handling — missing Promise .catch()
4. Incorrect Ordering — operation order dependencies
5. Boundary Conditions — edge case handling

## Notes

- **No excessive changes**: change only what is needed to fix the bug. Do not refactor surrounding code.
- **Symptom vs cause**: find the root cause, not the surface symptom.
- **3-attempt limit**: if fix fails after 3 attempts, report the situation to the user.
