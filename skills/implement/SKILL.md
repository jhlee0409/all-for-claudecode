---
name: afc:implement
description: "Execute code implementation — use when the user asks to implement a feature, execute a planned refactor, modify code from a plan, or build something"
argument-hint: "[task ID or phase specification]"
---

# /afc:implement — Execute Code Implementation

> Executes implementation phase by phase with dependency-aware scheduling.
> Generates tasks.md automatically from plan.md if absent. Swarm mode activates for high-parallelism phases.

## Arguments

- `$ARGUMENTS` — (optional) Specific task ID or phase to run (e.g., `T005`, `phase3`)

## Project Config (auto-loaded)

!`cat .claude/afc.config.md 2>/dev/null || echo "[CONFIG NOT FOUND] .claude/afc.config.md not found. Create it with /afc:init."`

## Config Load

**Always** read `.claude/afc.config.md` first (read manually if not auto-loaded above).

If config file is missing:
1. Ask the user: "`.claude/afc.config.md` not found. Run `/afc:init` to set up the project?"
2. If user accepts → run `/afc:init`, then **restart this command** with the original `$ARGUMENTS`
3. If user declines → **abort**

## Execution Steps

### 0. Safety Snapshot

Before starting implementation, create a **rollback point**:

```bash
git tag -f afc/pre-implement
```

- On failure: immediately rollback with `git reset --hard afc/pre-implement`
- Tag is automatically overwritten on the next `/afc:implement` run
- Skip if running inside `/afc:auto` pipeline (the `afc/pre-auto` tag already exists)

**Standalone safety activation** (skip if inside `/afc:auto`):
If no active pipeline state exists, activate it for the duration of this command:
```bash
"${CLAUDE_SKILL_DIR}/../../scripts/afc-pipeline-manage.sh" start {feature-name-from-plan.md}
"${CLAUDE_SKILL_DIR}/../../scripts/afc-pipeline-manage.sh" phase implement
```
This enables Stop Gate and CI Gate hooks during standalone implementation. Release on completion (Step 7) or failure rollback.

### 1. Load Context

1. **Current branch** → `BRANCH_NAME`
2. Load from `.claude/afc/specs/{feature}/`:
   - **plan.md** (required) — abort if missing: "plan.md not found. Run `/afc:plan` first."
   - **spec.md** (for reference)
   - **research.md** (if present)
   - **tasks.md** (if present — may be generated in Step 1.3)
3. **Recent changes**: run `git log --oneline -20`
4. **Smoke test**: run `{config.gate}` before starting:
   - Fails → diagnose before implementing (fix first or report to user)
5. **Baseline test** (if `{config.test}` is non-empty): run `{config.test}`:
   - Fails → ask user: "(1) Proceed anyway (2) Fix first (3) Abort"
   - Empty → skip

### 1.3. Task List Generation (if tasks.md absent)

1. **Parse plan.md File Change Map**: extract files, actions, descriptions, `Depends On`, `Phase`
2. **Generate tasks.md**:
   - Convert each row to: `- [ ] T{NNN} {[P]} {description} \`{file}\` {depends: [TXXX]}`
   - Assign `[P]` to tasks in the same Phase with no file dependency overlap
   - Map `Depends On` column to `depends: [TXXX]` references
   - Include phase gate validation task per phase
   - Include coverage mapping at bottom (FR/NFR → tasks, Entity → tasks, Constraint → tasks)
3. **Validate**:
   ```bash
   "${CLAUDE_SKILL_DIR}/../../scripts/afc-dag-validate.sh" .claude/afc/specs/{feature}/tasks.md
   "${CLAUDE_SKILL_DIR}/../../scripts/afc-parallel-validate.sh" .claude/afc/specs/{feature}/tasks.md
   ```
4. If validation fails → fix and re-validate (max 2 attempts)
5. Save to `.claude/afc/specs/{feature}/tasks.md`

If tasks.md already exists: use as-is, skip generation.

### 1.5. Parse Task List

1. Extract each task's ID, [P] marker, description, file paths, `depends:` list
2. Group by phase; build dependency graph (validate DAG — abort if circular)
3. Identify already-completed `[x]` tasks
4. Load **Implementation Context** section from plan.md (used in sub-agent prompts)

### 1.7. Retrospective Check

If `.claude/afc/memory/retrospectives/` exists, load the most recent 10 files and check for past patterns (file conflicts, unexpected dependencies, CI failures after parallel execution). Flag similar patterns. Skip gracefully if absent.

### 2. Check Progress

- If completed tasks exist, display:
  ```
  Progress: {completed}/{total} ({percent}%)
  Next: {first incomplete task ID} - {description}
  ```
- If a specific task/phase is specified via `$ARGUMENTS`, start from that item

### 3. Phase-by-Phase Execution

Execute each phase in order. Choose orchestration mode based on whether multi-agent coordination overhead is justified.

#### Mode Selection

| Condition | Mode |
|-----------|------|
| No [P] markers | Sequential |
| [P] tasks but delegation criteria NOT met | Sequential |
| [P] tasks, ALL criteria met, moderate parallelism | Parallel Batch |
| [P] tasks, ALL criteria met, high parallelism (multiple rounds needed) | Swarm |

**Default is direct execution**: main agent executes tasks directly unless all 4 parallel delegation criteria are met. See `docs/orchestration-modes.md` for full criteria, execution patterns, failure recovery, and dependency resolution.

#### Sequential Mode

Execute one at a time in order. On start: `▶ {ID}: {description}`. On complete: `✓ {ID} complete`.

#### Parallel Batch Mode

For moderate independent [P] tasks. Launch multiple Task() calls in a single message (concurrent). See `docs/orchestration-modes.md` for prompt template, verification steps, and failure recovery.

Key constraints:
- Pre-validate no file overlap before launching (downgrade to sequential if overlapping)
- After each batch: poll TaskList manually for newly-unblocked tasks (auto-unblocking not guaranteed in sub-agent mode)
- Verification failures → main agent fixes directly, no re-delegation
- `run_in_background: true` is **never** used on Task calls

#### Swarm Mode

For high-parallelism phases requiring multiple orchestrator rounds. Orchestrator pre-assigns tasks — workers never self-claim. Max 5 concurrent sub-agents (platform limit). See `docs/orchestration-modes.md` for full swarm protocol, worker prompt template, and failure recovery.

#### Phase Completion Gate

> **Always** read `${CLAUDE_SKILL_DIR}/../../docs/phase-gate-protocol.md` first and perform all steps in order.
> Cannot advance to the next phase without passing the gate. Abort and report after 3 consecutive CI failures.

After passing the gate:
```bash
"${CLAUDE_SKILL_DIR}/../../scripts/afc-pipeline-manage.sh" phase-tag {phase_number}
```

### 4. Task Execution Pattern

For each task:

1. **Read files**: always read before modifying
2. **TDD cycle** (when plan.md Test Strategy marks target file as "required"):
   - Red → Green → Refactor
   - If `{config.tdd}` is `strict` or `guide`: enforce order. If `off` or unset: recommended only.
3. **Implement**: write code following plan.md design
4. **Type/Lint check**: verify with `{config.gate}`
5. **Update tasks.md**: mark completed tasks as `[x]`

### 5. Final Verification

```bash
{config.ci}
```

- **Pass** → output final report
- **Fail** → Debug-based RCA:
  1. Execute `/afc:debug` logic inline with the CI error as input
  2. RCA: error trace → data flow → hypothesis → targeted fix
  3. Re-run `{config.ci}` after fix
  4. If debug-fix cycle fails 3 times → report to user with diagnosis details

### 6. Implement Critic Loop

After CI passes, run a convergence-based Critic Loop to verify design alignment.

> **Always** read `${CLAUDE_SKILL_DIR}/../../docs/critic-loop-rules.md` first and follow it.

**Critic Loop until convergence** (safety cap: 5):

- **SCOPE_ADHERENCE**: Compare `git diff` changed files against plan.md File Change Map. "M of N files match."
- **ARCHITECTURE**: Validate against `{config.architecture}` rules. "N of M rules checked."
- **CORRECTNESS**: Cross-check against spec.md acceptance criteria. "N of M AC verified."
- **SIDE_EFFECT_SAFETY**: Verify callee behavior compatibility for changed call order/error handling/state flow. "{M} of {N} behavioral changes verified."
- **Adversarial 3-perspective** (mandatory each pass): Skeptic, Devil's Advocate, Edge-case Hunter — one failure scenario each. Realistic → FAIL + fix. Unrealistic → quantitative rationale.
- FAIL → auto-fix + re-run `{config.ci}`. ESCALATE → pause for user. DEFER → record reason.

### 7. Final Output

**Standalone cleanup** (if pipeline was activated in Step 0):
```bash
"${CLAUDE_SKILL_DIR}/../../scripts/afc-pipeline-manage.sh" end
```

```
Implementation complete
├─ Tasks: {completed}/{total}
├─ Phases: {phase count} complete
├─ CI: {config.ci} passed
├─ Changed files: {file count}
└─ Next step: /afc:review (optional)
```

## Notes

- **Read existing code first**: always read file contents before modifying.
- **No over-modification**: do not refactor beyond what is in plan.md.
- **Architecture compliance**: follow `{config.architecture}` rules.
- **`{config.ci}` gate**: must pass on phase completion. Do not bypass.
- **File overlap**: strictly prohibited between parallel tasks.
- **Error classification**: stop on deterministic (same) errors; allow retries for transient (different) errors. Hard cap: 5 retries.
- **Real-time tasks.md updates**: mark checkbox on each task completion.
- **Orchestration modes reference**: `docs/orchestration-modes.md`
