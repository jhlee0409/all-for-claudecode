---
name: afc:resume
description: "Restore previous session state"
argument-hint: "[no arguments]"
model: sonnet
allowed-tools:
  - Read
  - Glob
  - Bash
---

# /afc:resume — Restore Session

> Restores the previous session state from .claude/afc/memory/checkpoint.md and resumes work.

## Arguments

- `$ARGUMENTS` — (optional) none

## Checkpoint State (auto-loaded)

!`cat .claude/afc/memory/checkpoint.md 2>/dev/null || echo "[NO_CHECKPOINT]"`

## Execution Steps

### 1. Load Checkpoint

Use the pre-fetched checkpoint above. If it shows `[NO_CHECKPOINT]`:
- Check auto-memory fallback: read `~/.claude/projects/{ENCODED_PATH}/memory/checkpoint.md`
- If fallback also not found: output "No saved checkpoint found." then **stop**

If checkpoint data was pre-fetched successfully:
parse the full contents (extract branch, commit hash, pipeline feature, task progress, modified files).

### 2. Validate Environment

Compare the checkpoint state against the current environment:

1. **Branch check**: Does the checkpoint branch match the current branch?
   - If different: warn + suggest switching
2. **File state**: Have any files changed since the checkpoint?
   - First verify HEAD exists: `git rev-parse --verify HEAD 2>/dev/null`
     - If HEAD does not exist (empty repo / no commits): report "No commits yet — cannot check changes since checkpoint." and skip this check
   - If checkpoint hash is present and non-empty: `git log {checkpoint hash}..HEAD --oneline`
   - If checkpoint hash is empty or missing: report "Checkpoint has no git reference — cannot diff." and skip this check
3. **Feature directory**: Does .claude/afc/specs/{feature}/ still exist?

### 3. Report State

```markdown
## Session Restore

### Previous Checkpoint
- **Saved at**: {time}
- **Message**: {checkpoint message}
- **Branch**: {branch} {(matches current ✓ / differs ⚠)}

### Active Features
| Feature | Status | Progress |
|---------|--------|----------|
| {name} | {status} | {progress} |

### Changes Since Checkpoint
{list of new commits if any, or "No changes"}

### Incomplete Work
{incomplete work list from checkpoint.md}

### Recommended Next Steps
{recommended commands based on state}
- Tasks in progress → resume `/afc:implement`
- Plan complete → `/afc:implement` (tasks generated automatically at start)
- Spec only → `/afc:plan`
```

### 4. Final Output

```
Session restored
├─ Checkpoint: {time}
├─ Feature: {name} ({status})
├─ Progress: {completed}/{total}
└─ Recommended: {next command}
```

## Notes

- **Read-only**: Does not modify the environment (branch switching is suggested only; user must confirm).
- **Mismatch warning**: Clearly warn if checkpoint and current environment differ.
- **Context restore**: Always display the "Context Notes" from the checkpoint to aid memory.
