---
name: afc:tasks
description: "Task decomposition from plan with dependency tracking"
argument-hint: "[constraints/priority directives]"
user-invocable: false
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
model: sonnet
---
# /afc:tasks — Task Decomposition

> Generates an executable task list (tasks.md) from plan.md.
> Validates coverage with a convergence-based Critic Loop.
>
> **Note**: In `/afc:auto`, task generation runs automatically at implement start. Use this command only for standalone manual control.

## Arguments

- `$ARGUMENTS` — (optional) additional constraints or priority directives

## Config Load

Read `.claude/afc.config.md` first. If missing: print "`.claude/afc.config.md` not found. Run `/afc:init` first." then **abort**.

## Execution Steps

### 1. Load Context

From `.claude/afc/specs/{feature}/`:
- **plan.md** (required) — if missing: "Run /afc:plan first."
- **spec.md** (required), **research.md** (if present)

Extract from plan.md: phase breakdown, File Change Map, architecture decisions.

### 2. Decompose Tasks

#### Task Format

```markdown
- [ ] T{NNN} {[P]} {[US*]} {description} `{file path}` {depends: [TXXX, ...]}
```

| Component | Required | Description |
|-----------|----------|-------------|
| `T{NNN}` | Yes | 3-digit sequential ID |
| `[P]` | No | Mandatory parallel execution — no file overlap with other [P] tasks in same phase |
| `[US*]` | No | User Story label from spec.md |
| `description` | Yes | Verb-first clear description |
| `` `file path` `` | Yes | Primary target file |
| `depends:` | No | Blocking dependency list |

#### Phase Structure

```markdown
# Tasks: {feature name}
## Phase 1: Setup    — type definitions, configuration
## Phase 2: Core     — business logic, store, API
## Phase 3: UI       — components, interactions
## Phase 4: Integration & Polish — error handling, optimization
```

#### Decomposition Rules

1. **1 task = 1 file** (where possible)
2. Same file → sequential; different files → `[P]` candidate
3. **`[P]` is mandatory, not optional** — once marked, task MUST run in parallel
4. Validate `[P]` file overlaps: run `"${CLAUDE_SKILL_DIR}/../../scripts/afc-parallel-validate.sh" .claude/afc/specs/{feature}/tasks.md`
5. Validate DAG (no cycles): run `"${CLAUDE_SKILL_DIR}/../../scripts/afc-dag-validate.sh" .claude/afc/specs/{feature}/tasks.md` — abort if cycle detected
6. Include a verification task per testable unit
7. Add `{config.gate}` validation task at end of each Phase
8. **No over-decomposition**: skip separate tasks for single-line changes

### 3. Retrospective Check

If `.claude/afc/memory/retrospectives/` exists, load the 10 most recent files (sorted descending) and check for prior `[P]` conflict patterns or granularity issues.

### 4. Critic Loop

Read [`docs/critic-loop-rules.md`](../../docs/critic-loop-rules.md) first and follow all rules. Safety cap: 5 passes.

| Criterion | Validation |
|-----------|------------|
| **COVERAGE** | All files in plan.md File Change Map included? All FR-* in spec.md covered? |
| **DEPENDENCIES** | DAG valid? `[P]` tasks in same phase have no file overlaps? All `depends:` IDs exist? |

**Verdicts**: PASS / FAIL (auto-fix, continue) / ESCALATE (pause for user) / DEFER (record, continue)

On convergence: `✓ Critic converged ({N} passes, {M} fixes, {E} escalations)`
On safety cap: `⚠ Critic safety cap ({N} passes). Review recommended.`

### 5. Coverage Mapping

```markdown
## Coverage Mapping
| Requirement | Tasks |
|-------------|-------|
| FR-001 | T003, T007 |
| NFR-001 | T012 |
```

Every FR-*/NFR-* must map to at least one task.

### 5.5. Auto-Checkpoint (standalone only)

When not inside `/afc:auto`, write `.claude/afc/memory/checkpoint.md`:
- branch, last commit, feature name, phase (tasks complete), task count, next step (`/afc:implement`)

### 6. Final Output

Save to `.claude/afc/specs/{feature}/tasks.md`, then:

```
Tasks generated
├─ .claude/afc/specs/{feature}/tasks.md
├─ Tasks: {total} ({[P] count} parallelizable)
├─ Phases: {count}
├─ Coverage: FR {N}%, NFR {N}%
├─ Critic: converged ({N} passes, {M} fixes, {E} escalations)
└─ Next step: /afc:validate (optional) or /afc:implement
```

## Notes

- **Cross-phase `depends:` prohibited**: only reference tasks in same or previous phase
- **`addBlockedBy` auto-unblocking** is guaranteed in Agent Teams only; in sub-agent mode the orchestrator must poll manually
- **Accurate file paths**: use actual project structure — no guessing
