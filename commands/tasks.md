---
name: afc:tasks
description: "Task decomposition"
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

> Generates an executable task list (tasks.md) based on plan.md.
> Validates coverage with convergence-based Critic Loop.

## Arguments

- `$ARGUMENTS` — (optional) additional constraints or priority directives

## Config Load

**Must** read `.claude/afc.config.md` first. If the config file is not present, print "`.claude/afc.config.md` not found. Run `/afc:init` first." then **abort**.

## Execution Steps

### 1. Load Context

1. Load from `.claude/afc/specs/{feature}/`:
   - **plan.md** (required) — stop if missing: "Run /afc:plan first."
   - **spec.md** (required)
   - **research.md** (if present)
2. Extract from plan.md:
   - Phase breakdown
   - File Change Map
   - Architecture decisions

### 2. Decompose Tasks

Decompose tasks per Phase defined in plan.md.

#### Task Format (required)

```markdown
- [ ] T{NNN} {[P]} {[US*]} {description} `{file path}` {depends: [TXXX, TXXX]}
```

| Component | Required | Description |
|-----------|----------|-------------|
| `T{NNN}` | Yes | 3-digit sequential ID (T001, T002, ...) |
| `[P]` | No | Parallelizable — no file overlap with other [P] tasks in the same phase |
| `[US*]` | No | User Story label (US1, US2, ... from spec.md) |
| description | Yes | Clear task description (start with a verb) |
| file path | Yes | Primary target file (wrapped in backticks) |
| `depends:` | No | Explicit dependency list — task cannot start until all listed tasks complete |

#### Phase Structure

```markdown
# Tasks: {feature name}

## Phase 1: Setup
{type definitions, configuration, directory structure}

## Phase 2: Core
{core business logic, store, API}

## Phase 3: UI
{components, interactions}

## Phase 4: Integration & Polish
{integration, error handling, optimization}
```

#### Decomposition Principles

1. **1 task = 1 file** principle (where possible)
2. **Same file = sequential**, **different files = [P] candidate**
3. **Explicit dependencies**: Use `depends: [T001, T002]` to declare blocking dependencies. Tasks without `depends:` and with [P] marker are immediately parallelizable.
4. **[P] physical validation**: Before finalizing tasks.md, run `"${CLAUDE_PLUGIN_ROOT}/scripts/afc-parallel-validate.sh" .claude/afc/specs/{feature}/tasks.md` to verify no file path overlaps exist among [P] tasks within the same phase. Fix any conflicts before proceeding.
5. **Dependency graph must be a DAG**: no circular dependencies allowed. Validate before output.
6. **Test tasks**: Include a verification task for each testable unit
7. **Phase gate**: Add a `{config.gate}` validation task at the end of each Phase

### 3. Retrospective Check

If `.claude/afc/memory/retrospectives/` directory exists, load retrospective files and check:
- Were there previous parallel conflict issues ([P] file overlaps)? Flag similar file patterns.
- Were there tasks that were over-decomposed or under-decomposed? Adjust granularity.

### 4. Critic Loop

> **Always** read `${CLAUDE_PLUGIN_ROOT}/docs/critic-loop-rules.md` first and follow it.

Run the critic loop until convergence. Safety cap: 5 passes.

| Criterion | Validation |
|-----------|------------|
| **COVERAGE** | Are all files in plan.md's File Change Map included in tasks? Are all FR-* in spec.md covered? |
| **DEPENDENCIES** | Is the dependency graph a valid DAG? Do [P] tasks within the same phase have no file overlaps? Are all `depends:` targets valid task IDs? For physical validation of [P] file overlaps, reference the validation script: `"${CLAUDE_PLUGIN_ROOT}/scripts/afc-parallel-validate.sh"` can be called with the tasks.md path to verify no conflicts exist. |

**On FAIL**: auto-fix and continue to next pass.
**On ESCALATE**: pause, present options to user, apply choice, resume.
**On DEFER**: record reason, mark criterion clean, continue.
**On CONVERGE**: `✓ Critic converged ({N} passes, {M} fixes, {E} escalations)`
**On SAFETY CAP**: `⚠ Critic safety cap ({N} passes). Review recommended.`

### 5. Coverage Mapping

```markdown
## Coverage Mapping
| Requirement | Tasks |
|-------------|-------|
| FR-001 | T003, T007 |
| FR-002 | T005, T008 |
| NFR-001 | T012 |
```

Every FR-*/NFR-* must be mapped to at least one task.

### 6. Final Output

Save to `.claude/afc/specs/{feature}/tasks.md`, then:

```
Tasks generated
├─ .claude/afc/specs/{feature}/tasks.md
├─ Tasks: {total count} ({[P] count} parallelizable)
├─ Phases: {phase count}
├─ Coverage: FR {coverage}%, NFR {coverage}%
├─ Critic: converged ({N} passes, {M} fixes, {E} escalations)
└─ Next step: /afc:analyze (optional) or /afc:implement
```

## Notes

- **Do not write implementation code**: Write task descriptions only. Actual code is the responsibility of /afc:implement.
- **No over-decomposition**: Do not create separate tasks for single-line changes.
- **Accurate file paths**: Use paths based on the actual project structure (no guessing).
- **Use [P] sparingly**: Mark [P] only for truly independent tasks. When in doubt, keep sequential.
- **Dependencies unlock swarm**: explicit `depends:` enables /afc:implement to use native task orchestration with automatic dependency resolution. Tasks without dependencies can be claimed by parallel workers immediately.
