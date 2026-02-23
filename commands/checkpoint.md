---
name: selfish:checkpoint
description: "Save session state"
argument-hint: "[checkpoint message]"
disable-model-invocation: true
model: haiku
allowed-tools:
  - Read
  - Write
  - Glob
  - Bash
---

# /selfish:checkpoint — Save Session State

> Saves the current work state to .claude/selfish/memory/checkpoint.md.
> Preserves progress even if the session is interrupted.

## Arguments

- `$ARGUMENTS` — (optional) checkpoint message (e.g., "Phase 2 complete, before starting UI implementation")

## Execution Steps

### 1. Collect Current State

Collect automatically:

1. **Git status**:
   - Current branch
   - Last commit hash + message
   - List of changed files (`git status --short`)
2. **Active Features**:
   - Check subdirectories under `specs/`
   - Progress state of each feature (spec only? through plan? through tasks? implementing?)
3. **Tasks Progress**:
   - If tasks.md exists, count `[x]`/`[ ]` items
4. **Current Work Context**:
   - `$ARGUMENTS` message
   - Recently modified files (`git diff --name-only`)

### 2. Save Checkpoint

**Overwrite** `.claude/selfish/memory/checkpoint.md` (keep only the latest state):

````markdown
# Session Checkpoint

> Saved: {YYYY-MM-DD HH:mm}
> Branch: {branch name}
> Commit: {hash} — {message}

## Message
{$ARGUMENTS or "automatic checkpoint"}

## Active Features
| Feature | Status | Progress |
|---------|--------|----------|
| {name} | {spec/plan/tasks/implementing/done} | {N/M tasks} |

## Incomplete Work
{concrete next steps}

## Changed Files
```
{git status --short output}
```

## Context Notes
{things to remember about the current work}
````

### 3. Final Output

```
Checkpoint saved
├─ Time: {HH:mm}
├─ Branch: {branch name}
├─ Active features: {count}
├─ Progress: {completed tasks}/{total tasks}
└─ Restore: /selfish:resume
```

## Notes

- **Overwrite**: Always keep only the latest state. Git handles history.
- **Auto-collect**: Collect information automatically as much as possible. Minimize user input.
- **Keep it concise**: Exclude unnecessary details. Only what is needed to restore.
