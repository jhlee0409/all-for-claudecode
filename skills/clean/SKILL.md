---
name: afc:clean
description: "Pipeline artifact cleanup and codebase hygiene — use when the user asks to clean up artifacts, remove pipeline files, or finalize after implementation"
argument-hint: "[feature name — defaults to current pipeline feature]"
model: sonnet
---

# /afc:clean — Pipeline Cleanup

> Runs the clean phase independently: artifact cleanup, dead code scan, CI verification, memory update, and pipeline flag release.
> Equivalent to Phase 5 of `/afc:auto`. Use after manually running spec/plan/implement/review phases.

## Arguments

- `$ARGUMENTS` — (optional) Feature name to clean up. Defaults to the currently active pipeline feature.

## Prerequisites

- Pipeline must be active (`afc_state_is_active`) OR a feature name must be provided
- If pipeline is active, the current phase should be `review` or later

## Execution Steps

### 1. Resolve Feature

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase clean
```

- If pipeline is active: read feature from state
- If `$ARGUMENTS` provides a feature name: use that (for manual cleanup without active pipeline)
- If neither: exit with error — `"No active pipeline and no feature specified. Usage: /afc:clean [feature-name]"`

Set `PIPELINE_ARTIFACT_DIR` = `.claude/afc/specs/{feature}/`

### 2. Artifact Cleanup (scope-limited)

- **Delete only the `.claude/afc/specs/{feature}/` directory created by the current pipeline**
- If other `.claude/afc/specs/` subdirectories exist, **do not delete them** (only inform the user of their existence)
- Do not leave pipeline intermediate artifacts in the codebase

### 3. Dead Code Scan

**Prefer external tooling over LLM judgment** for dead code detection:
- Run `{config.gate}` / `{config.ci}` — most linters detect unused imports/variables automatically
- If the project has dedicated dead code tools (e.g., `eslint --rule 'no-unused-vars'`, `ts-prune`, `knip`), use them first
- Only fall back to LLM-based scan for detection that static tools cannot cover (e.g., unused exports across module boundaries)
- Remove empty directories from moved/deleted files
- Detect unused exports (re-exports of moved code from original locations etc.)

### 4. Final CI Gate

- Run `{config.ci}` final execution
- Auto-fix on failure (max 2 attempts)

### 5. Memory Update

- Reusable patterns found during pipeline -> record in `.claude/afc/memory/`
- If there were `[AUTO-RESOLVED]` items -> record decisions in `.claude/afc/memory/decisions/`
- **If retrospective.md exists** -> record as patterns missed by the Plan phase Critic Loop in `.claude/afc/memory/retrospectives/` (reuse as RISK checklist items in future runs)
- **If review-report.md exists** -> copy to `.claude/afc/memory/reviews/{feature}-{date}.md` before .claude/afc/specs/ deletion
- **If research.md exists** and was not already persisted in Plan phase -> copy to `.claude/afc/memory/research/{feature}.md`
- **Agent memory consolidation**: Check each agent's MEMORY.md for bloat — if it contains redundant, obsolete, or superseded entries that reduce signal-to-noise ratio, invoke the agent to self-prune:
  ```
  Task("Memory cleanup: afc-architect", subagent_type: "afc:afc-architect",
    prompt: "Review your MEMORY.md. Read it, identify and prune old/redundant/obsolete entries, and rewrite it keeping only entries that are still relevant and non-overlapping.")
  ```
  Use semantic assessment (are entries still relevant? do entries overlap?) rather than a line-count threshold. (Same pattern for afc-security if needed.)
- **Memory rotation**: For each memory subdirectory, assess whether the oldest files still provide value. Prune files that are superseded by newer entries, reference features/code that no longer exists, or overlap with other files. As a practical guideline, keep the most recent and relevant entries — if a directory has grown large enough that scanning it would be slow (roughly 30+ files), prioritize pruning the least relevant entries:
  | Directory | Pruning Intent | Soft Guideline |
  |-----------|---------------|----------------|
  | `quality-history/` | Remove superseded or redundant quality records | ~30 files |
  | `reviews/` | Remove reviews for features no longer in the codebase | ~40 files |
  | `retrospectives/` | Remove retrospectives whose learnings are already captured elsewhere | ~30 files |
  | `research/` | Remove research for libraries/patterns no longer used | ~50 files |
  | `decisions/` | Remove decisions that have been reversed or are no longer relevant | ~60 files |
  - These numbers are soft guidelines, not hard cutoffs — use judgment based on relevance
  - Sort by filename ascending (oldest first) when pruning by recency
  - Log: `"Memory rotation: {dir} pruned {N} files"`
  - Skip directories that do not exist or clearly do not need pruning

### 6. Quality Report

Generate `.claude/afc/memory/quality-history/{feature}-{date}.json` with pipeline metrics (if pipeline was active):
```json
{
  "feature": "{feature}",
  "date": "{YYYY-MM-DD}",
  "totals": { "changed_files": N }
}
```
Create `.claude/afc/memory/quality-history/` directory if it does not exist.

### 7. Checkpoint Reset

Clear `.claude/afc/memory/checkpoint.md` **and** `~/.claude/projects/{ENCODED_PATH}/memory/checkpoint.md` (pipeline complete = session goal achieved; `ENCODED_PATH` = project path with `/` replaced by `-`).

### 8. Timeline Finalize

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" log pipeline-end "Pipeline complete: {feature}"
```

### 9. Release Pipeline Flag

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" end
```

- Stop Gate Hook deactivated
- Change tracking log deleted
- Safety tag removed (successful completion)
- Phase rollback tags removed (handled automatically by pipeline end)

### 10. Output Summary

```
Clean complete: {feature}
├─ Artifacts: {N} files deleted from .claude/afc/specs/{feature}/
├─ Dead code: {N} items removed
├─ CI: PASSED
├─ Memory: {N} files persisted, {N} rotated
└─ Pipeline flag: released
```

## Notes

- This command is safe to run multiple times (idempotent -- skips already-deleted artifacts)
- If no pipeline is active and no feature is specified, the command exits with an informative error
- When run standalone (not as part of auto), the quality report captures only the information available at clean time
