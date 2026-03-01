---
name: afc:resume
description: "Restore session"
argument-hint: "[no arguments]"
model: haiku
allowed-tools:
  - Read
  - Glob
  - Bash
---

# /afc:resume — Restore Session

> Restores the previous session state from .claude/afc/memory/checkpoint.md and resumes work.

## Arguments

- `$ARGUMENTS` — (optional) none

## Execution Steps

### 1. Load Checkpoint

Read `.claude/afc/memory/checkpoint.md`:
- If not found: check **auto-memory fallback** — read `~/.claude/projects/{ENCODED_PATH}/memory/checkpoint.md` (where `ENCODED_PATH` = project path with `/` replaced by `-`):
  - If fallback found: use it as the checkpoint source (auto-memory is written by `pre-compact-checkpoint.sh` during context compaction)
  - If fallback also not found: output "No saved checkpoint found. Use `/afc:checkpoint` to create one, or checkpoints are created automatically on context compaction." then **stop**
- If found: parse the full contents (extract branch, commit hash, pipeline feature, task progress, modified files)

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
