---
name: afc:validate
description: "Validate spec/plan/task artifact consistency"
argument-hint: "[validation scope: spec-plan, tasks-only]"
user-invocable: false
context: fork
allowed-tools:
  - Read
  - Grep
  - Glob
model: sonnet
---

# /afc:validate — Artifact Consistency Validation

> Validates consistency across spec.md, plan.md, and tasks.md. **Read-only** — does not modify files.

## Project Config (auto-loaded)
!`cat .claude/afc.config.md 2>/dev/null || echo "[CONFIG NOT FOUND — run /afc:init first]"`

## Arguments

- `$ARGUMENTS` — (optional) limit validation scope (`spec-plan`, `tasks-only`)

## Execution Steps

### 1. Load Artifacts

From `.claude/afc/specs/{feature}/`:
- **spec.md** (required), **plan.md** (required)
- **tasks.md**, **research.md**, **context.md** (load if present)

Warn about missing files but proceed with what is available.
If config is missing: use `CLAUDE.md` for architecture info; assume "Layered Architecture" as fallback.

**No artifacts early-exit**: If both spec.md and plan.md are missing (no feature directory exists or directory is empty), output:
```
Validation skipped — no pipeline artifacts found
├─ spec.md: not found
├─ plan.md: not found
└─ Run /afc:spec followed by /afc:plan to generate artifacts for validation
```
Exit without running validation categories. Do not produce a degenerate report with empty coverage data.

### 2. Run Validation

Run all 6 categories defined in [`validation-categories.md`](./validation-categories.md).

If `$ARGUMENTS` specifies a scope (e.g., `spec-plan`), run only the relevant categories.

### 3. Output Results

```markdown
## Consistency Analysis Results: {feature name}

### Findings
| ID | Category | Severity | Location | Summary | Recommended Action |
|----|----------|----------|----------|---------|-------------------|
| A-001 | COVERAGE | HIGH | spec FR-003 | No mapping in tasks | Add task |

### Coverage Summary
| Mapping | Coverage |
|---------|----------|
| spec → plan | {N}% |
| plan → tasks | {N}% |
| spec → tasks | {N}% |

### Metrics
- Total requirements: {N} / Total tasks: {N}
- Issues: CRITICAL {N} / HIGH {N} / MEDIUM {N} / LOW {N}

### Next Steps
{Concrete action proposals for CRITICAL/HIGH issues}
```

### 4. After Validation Fails

If CRITICAL or HIGH issues are found:
1. Return the findings table to the calling skill (spec/plan/tasks/implement)
2. The calling skill is responsible for fixing the reported issues before proceeding
3. To re-validate after fixes: re-invoke `/afc:validate` with the same scope

If only MEDIUM/LOW issues: proceed is safe; issues are advisory.

### 5. Final Output

```
Analysis complete
├─ Found: CRITICAL {N} / HIGH {N} / MEDIUM {N} / LOW {N}
├─ Coverage: spec→plan {N}%, plan→tasks {N}%, spec→tasks {N}%
└─ Recommended: {next action}
```

## Notes

- **Read-only**: Report only, no file writes.
- **Avoid false positives**: Do not over-flag ambiguity — consider context.
- **Optional in pipeline**: Not required. Can proceed plan → implement directly.
