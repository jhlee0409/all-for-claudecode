---
name: afc:implement
description: "Execute code implementation"
argument-hint: "[task ID or phase specification]"
---

# /afc:implement — Execute Code Implementation

> Executes implementation phase by phase with dependency-aware scheduling.
> Generates tasks.md automatically from plan.md if absent. Swarm mode activates for >5 parallel tasks per phase.

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
"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" start {feature-name-from-plan.md}
"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase implement
```
This enables Stop Gate and CI Gate hooks during standalone implementation. Release on completion (Step 7) or failure rollback.

### 1. Load Context

1. **Current branch** → `BRANCH_NAME`
2. Load the following files from `.claude/afc/specs/{feature}/`:
   - **plan.md** (required) — abort if missing: "plan.md not found. Run `/afc:plan` first."
   - **spec.md** (for reference)
   - **research.md** (if present)
   - **tasks.md** (if present — may be generated in Step 1.3)
3. **Recent changes**: run `git log --oneline -20` to understand what changed recently (context for implementation)
4. **Smoke test**: run `{config.gate}` before starting implementation:
   - If it fails → diagnose before implementing (existing code is broken — fix first or report to user)
   - If it passes → baseline confirmed, proceed

### 1.3. Task List Generation (if tasks.md absent)

If `.claude/afc/specs/{feature}/tasks.md` does not exist, generate it from plan.md:

1. **Parse plan.md File Change Map**: extract files, actions, descriptions, `Depends On`, `Phase`
2. **Generate tasks.md**:
   - Convert each row to task format: `- [ ] T{NNN} {[P]} {description} \`{file}\` {depends: [TXXX]}`
   - Assign `[P]` to tasks in the same Phase with no file dependency overlap
   - Map `Depends On` column to `depends: [TXXX]` references
   - Include phase gate validation task per phase
   - Include coverage mapping at the bottom:
     - FR/NFR → tasks (every FR-*/NFR-* maps to at least one task)
     - Entity → tasks (every spec Key Entity maps to at least one task)
     - Constraint → tasks (every spec Constraint is addressed by at least one task)
3. **Validate** (script-based, no critic loop):
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/afc-dag-validate.sh" .claude/afc/specs/{feature}/tasks.md
   "${CLAUDE_PLUGIN_ROOT}/scripts/afc-parallel-validate.sh" .claude/afc/specs/{feature}/tasks.md
   ```
4. If validation fails → fix tasks.md and re-validate (max 2 attempts)
5. Save to `.claude/afc/specs/{feature}/tasks.md`

If tasks.md already exists (e.g., from standalone `/afc:tasks` run): use as-is, skip generation.

### 1.5. Parse Task List

1. Parse tasks.md:
   - Extract each task's ID, [P] marker, [US*] label, description, file paths, `depends:` list
   - Group by phase
   - Build dependency graph (validate DAG — abort if circular)
   - Identify already-completed `[x]` tasks
2. Load **Implementation Context** section from plan.md (used in sub-agent prompts)

### 1.7. Retrospective Check

If `.claude/afc/memory/retrospectives/` exists, load the **most recent 10 files** (sorted by filename descending) and check:
- Were there implementation issues in past pipelines (e.g., file conflicts, unexpected dependencies, CI failures after parallel execution)?
- Flag similar patterns in the current task list. Warn before implementation begins.
- Skip gracefully if directory is empty or absent.

### 2. Check Progress

- If completed tasks exist, display status:
  ```
  Progress: {completed}/{total} ({percent}%)
  Next: {first incomplete task ID} - {description}
  ```
- If a specific task/phase is specified via `$ARGUMENTS`, start from that item

### 3. Phase-by-Phase Execution

Execute each phase in order. Choose the orchestration mode based on the number of [P] tasks in the phase:

#### Mode Selection

| [P] tasks in phase | Mode | Strategy |
|---------------------|------|----------|
| 0 | Sequential | Execute tasks one by one |
| 1–5 | Parallel Batch | Launch Task() calls in parallel (current batch approach) |
| 6+ | Swarm | Create task pool → orchestrator pre-assigns tasks to worker agents |

#### Sequential Mode (no P marker)

- Execute one at a time in order
- On task start: `▶ {ID}: {description}`
- On completion: `✓ {ID} complete`

#### Parallel Batch Mode (1–5 [P] tasks)

**Pre-validation**: Verify no file overlap (downgrade to sequential if overlapping).

**Step 1 — Register**: Create tasks for the current phase only (phase-locked registration):
```
TaskCreate({ subject: "T003: Create UserService", description: "..." })
TaskCreate({ subject: "T004: Create AuthService", description: "..." })
TaskUpdate({ taskId: "T004", addBlockedBy: ["T002"] })  // if T004 depends on T002
```

**Step 2 — Launch unblocked [P] tasks in a single message** (Claude Code executes multiple Task() calls in a single message concurrently, up to ~10):
```
Task("T003: Create UserService", subagent_type: "afc:afc-impl-worker",
  isolation: "worktree",
  prompt: "Implement the following task:

  ## Task
  {task ID}: {description} — `{file path}`

  ## Implementation Context
  {paste full ## Implementation Context section from plan.md}

  ## Plan Context
  {relevant Phase section from plan.md for this task}

  ## Rules
  - {config.code_style} and {config.architecture}
  - Follow CLAUDE.md and afc.config.md

  ## Output
  Return a structured summary (max 2000 chars):
  - Files changed: {list}
  - Key decisions: {any design choices made}
  - Issues: {blockers or concerns, if any}
  - Verification: {config.gate} result")
Task("T004: Create AuthService", subagent_type: "afc:afc-impl-worker", isolation: "worktree", ...)
```

**Step 3 — Collect results and advance**: After all parallel agents return:
1. Read each agent's returned output and verify completion
2. Mark `TaskUpdate(status: "completed")` for each finished task
3. **Manually check for newly-unblocked tasks**: Call `TaskList`, inspect `blockedBy` lists — if all blockers are now completed, the task is unblockable. (Note: auto-unblocking is only guaranteed in Agent Teams mode; in sub-agent mode, the orchestrator must poll and check manually.)
4. If newly-unblockable tasks exist → launch next batch (repeat Step 2)
5. If no more pending tasks remain → phase complete

**Failure Recovery** (per-task, not per-batch):
1. Identify the failed task from the agent's error return
2. Reset: `TaskUpdate(taskId, status: "pending")`
3. Track: `TaskUpdate(taskId, metadata: { retryCount: N })`
4. If retryCount < 3 → re-launch in the next batch round (not immediately — wait for current batch to finish)
5. If retryCount >= 3 → mark as failed, report: `"T{ID} failed after 3 attempts: {last error}"`
6. Continue with remaining tasks — a single failure does not block the entire phase

#### Swarm Mode (6+ [P] tasks)

When a phase has more than 5 parallelizable tasks, use the **orchestrator-managed swarm pattern**.

> **Key constraint**: Claude Code's TaskUpdate uses **last-write-wins** with local file locking only. Multiple sub-agents calling TaskUpdate on the same task simultaneously can cause lost writes. The orchestrator must mediate task assignment to prevent collisions.

**Step 1 — Register current-phase tasks only** (phase-locked):
```
// Register ONLY this phase's tasks — never register future phases
TaskCreate({ subject: "T007: Create ComponentA", description: "..." })
TaskCreate({ subject: "T008: Create ComponentB", description: "..." })
// ... for all tasks in this phase
TaskUpdate({ taskId: "T008", addBlockedBy: ["T006"] })  // if dependency exists
```

**Step 2 — Orchestrator assigns tasks** (no self-claiming):
Instead of workers self-claiming (race-prone), the **orchestrator pre-assigns** tasks:
```
// Orchestrator assigns: each worker gets a unique, non-overlapping task set
Task("Worker 1: T007, T009, T011", subagent_type: "afc:afc-impl-worker",
  isolation: "worktree",
  prompt: "Implement these tasks in order:
  1. T007: {description} — `{file path}`
  2. T009: {description} — `{file path}`
  3. T011: {description} — `{file path}`

  ## Implementation Context
  {paste full ## Implementation Context section from plan.md}

  For each task:
  - Read the target file before modifying
  - Implement following plan.md design
  - Verify with {config.gate} after each task

  ## Rules
  - {config.code_style} and {config.architecture}
  - Follow CLAUDE.md and afc.config.md

  ## Output
  Return a structured summary per task (max 2000 chars total):
  - Files changed, key decisions, issues encountered per task.")

Task("Worker 2: T008, T010, T012", subagent_type: "afc:afc-impl-worker", isolation: "worktree", ...)
```

**Step 3 — Collect and reconcile**:
1. Wait for all workers to return (foreground execution)
2. Read results, mark `TaskUpdate(status: "completed")` for each finished task
3. Call `TaskList` to check for remaining pending/blocked tasks
4. If unblocked tasks remain → assign to new worker batch (repeat Step 2)
5. If all tasks complete → phase done

**Worker count**: N = min(5, unblocked task count). Max 5 concurrent sub-agents per phase.

**Task assignment strategy**: Round-robin by file path — each worker gets tasks targeting different files to maximize isolation. If a worker has multiple tasks, order them by `depends:` topology.

#### Swarm Failure Recovery

When a worker agent returns an error:
1. Identify which tasks the worker was assigned (from the pre-assigned list)
2. Check which tasks the worker actually completed (from its result summary)
3. Reset uncompleted tasks: `TaskUpdate(taskId, status: "pending")`
4. Track retry count: `TaskUpdate(taskId, metadata: { retryCount: N })`
5. If retryCount < 3 → reassign to next worker batch
6. If retryCount >= 3 → mark as failed, report: `"T{ID} failed after 3 attempts: {last error}"`
7. Continue with remaining tasks

> Single task failure does not block the phase. The orchestrator reassigns failed tasks to subsequent batches.

#### Dependency Resolution

- Tasks with `depends: [T001, T002]` are registered via `TaskUpdate(addBlockedBy: ["T001", "T002"])`
- **Auto-unblocking is NOT guaranteed in sub-agent mode**. The orchestrator must:
  1. After each batch completes, call `TaskList` to get current state
  2. For each pending task, check if all `blockedBy` tasks are now completed
  3. If all blockers resolved → task is eligible for the next batch
- **Phase-locked registration**: Only register tasks for the current phase. Never register Phase N+1 tasks until Phase N is fully complete and its gate has passed. This prevents workers from claiming future-phase tasks.
- **Cross-phase dependencies**: A Phase 2 task may `depends:` on a Phase 1 task. Since Phase 1 must complete before Phase 2 begins, this is always satisfied. Within the same phase, `depends:` creates intra-phase ordering.

#### Phase Completion Gate (3 steps)

> **Always** read `${CLAUDE_PLUGIN_ROOT}/docs/phase-gate-protocol.md` first and perform the 3 steps (CI gate → Mini-Review → Auto-Checkpoint) in order.
> Cannot advance to the next phase without passing the gate. Abort and report to user after 3 consecutive CI failures.

After passing the gate, create a phase rollback point:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase-tag {phase_number}
```
This enables granular rollback: `git reset --hard afc/phase-{N}` restores state after Phase N completed.

### 4. Task Execution Pattern

For each task:

1. **Read files**: always read files before modifying them
2. **Implement**: write code following the design in plan.md
3. **Type/Lint check**: verify new code passes `{config.gate}`
4. **Update tasks.md**: mark completed tasks as `[x]`
   ```markdown
   - [x] T001 {description}  ← complete
   - [ ] T002 {description}  ← incomplete
   ```

### 5. Final Verification

After all tasks are complete:

```bash
{config.ci}
```

- **Pass**: output final report
- **Fail**: **Debug-based RCA** (replaces blind retry):
  1. Execute `/afc:debug` logic inline with the CI error output as input
  2. Debug performs RCA: error trace → data flow → hypothesis → targeted fix
  3. Re-run `{config.ci}` after fix
  4. If debug-fix cycle fails 3 times → report to user with diagnosis details (not a simple fix)
  5. This produces targeted fixes instead of blind retries

### 6. Implement Critic Loop

After CI passes, run a convergence-based Critic Loop to verify design alignment before reporting completion.

> **Always** read `${CLAUDE_PLUGIN_ROOT}/docs/critic-loop-rules.md` first and follow it.

**Critic Loop until convergence** (safety cap: 5):

- **SCOPE_ADHERENCE**: Compare `git diff` changed files against plan.md File Change List. Flag any file modified that is NOT in the plan. Flag any planned file NOT modified. Provide "M of N files match" count.
- **ARCHITECTURE**: Validate changed files against `{config.architecture}` rules (layer boundaries, naming conventions, import paths). Provide "N of M rules checked" count.
- **CORRECTNESS**: Cross-check implemented changes against spec.md acceptance criteria (AC). Verify each AC has corresponding code. Provide "N of M AC verified" count.
- **Adversarial 3-perspective** (mandatory each pass):
  - Skeptic: "Which implementation assumption is most likely wrong?"
  - Devil's Advocate: "How could this implementation be misused or fail unexpectedly?"
  - Edge-case Hunter: "What input would cause this implementation to fail silently?"
  - State one failure scenario per perspective. If realistic → FAIL + fix. If unrealistic → state quantitative rationale.
- FAIL → auto-fix, re-run `{config.ci}`, and continue. ESCALATE → pause, present options, resume after response. DEFER → record reason, mark clean.

### 7. Final Output

**Standalone cleanup** (if pipeline was activated in Step 0):
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" end
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

- **Read existing code first**: always read file contents before modifying. Do not blindly generate code.
- **No over-modification**: do not refactor or improve beyond what is in plan.md.
- **Architecture compliance**: follow {config.architecture} rules.
- **{config.ci} gate**: must pass on phase completion. Do not bypass.
- **Swarm workers**: max 5 concurrent. File overlap is strictly prohibited between parallel tasks.
- **On error**: prevent infinite loops. Report to user after 3 attempts.
- **Real-time tasks.md updates**: mark checkbox on each task completion.
- **Mode selection is automatic**: do not manually override. Sequential for non-[P], batch for ≤5, swarm for 6+.
- **NEVER use `run_in_background: true` on Task calls**: agents must run in foreground so results are returned before the next step.
- **No worker self-claiming**: In swarm mode, the orchestrator pre-assigns tasks to workers. Workers do NOT call TaskList/TaskUpdate to claim tasks — this avoids last-write-wins race conditions on TaskUpdate.
- **Phase-locked registration**: Only register (TaskCreate) the current phase's tasks. Never pre-register future phases. This is the primary mechanism for phase boundary enforcement.
- **Orchestrator polls for unblocking**: After each batch, the orchestrator calls TaskList and manually checks blockedBy status. Do not rely on automatic unblocking outside Agent Teams mode.
