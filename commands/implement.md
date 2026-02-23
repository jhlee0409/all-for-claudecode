---
name: selfish:implement
description: "Execute code implementation"
argument-hint: "[task ID or phase specification]"
---

# /selfish:implement — Execute Code Implementation

> Executes tasks from tasks.md phase by phase.
> Uses native task orchestration with dependency-aware scheduling. Swarm mode activates for >5 parallel tasks per phase.

## Arguments

- `$ARGUMENTS` — (optional) Specific task ID or phase to run (e.g., `T005`, `phase3`)

## Project Config (auto-loaded)

!`cat .claude/selfish.config.md 2>/dev/null || echo "[CONFIG NOT FOUND] .claude/selfish.config.md not found. Create it with /selfish:init."`

## Config Load

**Always** read `.claude/selfish.config.md` first (read manually if not auto-loaded above). Abort if config file is missing.

## Execution Steps

### 0. Safety Snapshot

Before starting implementation, create a **rollback point**:

```bash
git tag -f selfish/pre-implement
```

- On failure: immediately rollback with `git reset --hard selfish/pre-implement`
- Tag is automatically overwritten on the next `/selfish:implement` run
- Skip if running inside `/selfish:auto` pipeline (the `selfish/pre-auto` tag already exists)

### 1. Load Context

1. **Current branch** → `BRANCH_NAME`
2. Load the following files from `.claude/selfish/specs/{feature}/`:
   - **tasks.md** (required) — abort if missing: "tasks.md not found. Run `/selfish:tasks` first."
   - **plan.md** (required) — abort if missing
   - **spec.md** (for reference)
   - **research.md** (if present)
3. Parse tasks.md:
   - Extract each task's ID, [P] marker, [US*] label, description, file paths, `depends:` list
   - Group by phase
   - Build dependency graph (validate DAG — abort if circular)
   - Identify already-completed `[x]` tasks
4. **Recent changes**: run `git log --oneline -20` to understand what changed recently (context for implementation)
5. **Smoke test**: run `{config.gate}` before starting implementation:
   - If it fails → diagnose before implementing (existing code is broken — fix first or report to user)
   - If it passes → baseline confirmed, proceed to implementation

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
| 6+ | Swarm | Create task pool → spawn worker agents that self-organize |

#### Sequential Mode (no P marker)

- Execute one at a time in order
- On task start: `▶ {ID}: {description}`
- On completion: `✓ {ID} complete`

#### Parallel Batch Mode (1–5 [P] tasks)

- Verify **no file overlap** (downgrade to sequential if overlapping)
- Register all phase tasks via TaskCreate:
  ```
  TaskCreate({ subject: "T003: Create UserService", description: "..." })
  TaskCreate({ subject: "T004: Create AuthService", description: "..." })
  ```
- Set up dependencies via TaskUpdate:
  ```
  TaskUpdate({ taskId: "T004", addBlockedBy: ["T002"] })  // if T004 depends on T002
  ```
- Launch parallel sub-agents for unblocked [P] tasks in a **single message** (auto-parallel):
  ```
  Task("T003: Create UserService", subagent_type: "general-purpose",
    prompt: "Implement the following task:\n\n## Task\n{description}\n\n## Related Files\n{file paths}\n\n## Plan Context\n{relevant section from plan.md}\n\n## Rules\n- {config.code_style}\n- {config.architecture}\n- Follow CLAUDE.md and selfish.config.md")
  Task("T004: Create AuthService", subagent_type: "general-purpose", ...)
  ```
- Read each agent's returned output and verify completion
- Mark TaskUpdate(status: "completed") for each finished task
- Any newly-unblocked tasks from dependency resolution → launch next batch

#### Swarm Mode (6+ [P] tasks)

When a phase has more than 5 parallelizable tasks, use the **self-organizing swarm pattern**:

1. **Create task pool**: Register ALL phase tasks via TaskCreate with full descriptions
2. **Set up dependency graph**: Use TaskUpdate(addBlockedBy) for every `depends:` declaration
3. **Spawn N worker agents** (N = min(5, unblocked task count)):
   ```
   Task("Swarm Worker 1", subagent_type: "general-purpose",
     prompt: "You are a swarm worker. Your job:
     1. Call TaskList to find available tasks (status: pending, no blockedBy, no owner)
     2. Claim one by calling TaskUpdate(taskId, status: in_progress, owner: worker-1)
     3. Read TaskGet(taskId) for full description
     4. Implement the task following the plan and code style rules
     5. Mark complete: TaskUpdate(taskId, status: completed)
     6. Repeat from step 1 until no tasks remain
     7. Exit when TaskList shows no pending tasks

     ## Rules
     - {config.code_style} and {config.architecture}
     - Always read files before modifying
     - Follow CLAUDE.md and selfish.config.md")
   ```
4. **Wait for all workers to exit** — workers naturally terminate when the pool is empty
5. **Verify**: check TaskList for any incomplete tasks → re-spawn workers if needed

#### Swarm Worker Failure Recovery

When a worker agent exits with error (non-zero return or timeout):
1. Scan TaskList for tasks with status `in_progress` that have no active worker
2. Reset each orphaned task: `TaskUpdate(taskId, status: "pending", owner: "")`
3. Track retry count per task (max 2 retries)
4. If a task fails 3 times → mark as `failed`, report to user: `"T{ID} failed after 3 attempts: {last error}"`
5. Re-spawn replacement workers for remaining tasks

> Workers should wrap their implement-complete loop in error handling so a single task failure doesn't crash the entire worker.

> Swarm workers self-balance: fast workers claim more tasks. No batch boundaries needed.

#### Dependency Resolution

- Tasks with `depends: [T001, T002]` are registered via TaskUpdate(addBlockedBy: ["T001", "T002"])
- When a dependency completes, blocked tasks are automatically unblocked
- Phase order is always respected — all tasks in Phase N must complete before Phase N+1 begins

#### Phase Completion Gate (3 steps)

> **Always** read `${CLAUDE_PLUGIN_ROOT}/docs/phase-gate-protocol.md` first and perform the 3 steps (CI gate → Mini-Review → Auto-Checkpoint) in order.
> Cannot advance to the next phase without passing the gate. Abort and report to user after 3 consecutive CI failures.

After passing the gate, create a phase rollback point:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/selfish-pipeline-manage.sh" phase-tag {phase_number}
```
This enables granular rollback: `git reset --hard selfish/phase-{N}` restores state after Phase N completed.

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
- **Fail**: attempt to fix errors (max 3 attempts)

### 6. Final Output

```
Implementation complete
├─ Tasks: {completed}/{total}
├─ Phases: {phase count} complete
├─ CI: {config.ci} passed
├─ Changed files: {file count}
└─ Next step: /selfish:review (optional)
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
