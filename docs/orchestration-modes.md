# Orchestration Modes

> Reference document for `afc:implement`. Covers mode selection, execution patterns, failure recovery, and dependency resolution. Shared with `afc:auto` and `afc:review` where applicable.

## Mode Selection

**Default: main agent executes directly.** Delegation to impl-workers is the exception, not the rule.

| Condition | Mode | Strategy |
|-----------|------|----------|
| No [P] markers | Sequential | Main agent executes tasks one by one |
| [P] tasks but delegation criteria NOT met | Sequential | Main agent executes directly (preserves full context) |
| [P] tasks, ALL delegation criteria met, moderate parallelism | Parallel Batch | Launch Task() calls in a single message |
| [P] tasks, ALL delegation criteria met, high parallelism requiring multiple orchestrator rounds | Swarm | Orchestrator pre-assigns tasks to worker agents |

**Mode judgment**: Ask — "Given these N tasks with their complexity, file scope, and interdependencies, would spawning multiple agents and merging their results be faster and safer than executing sequentially?" If the answer is not clearly yes, default to Sequential.

**Parallel delegation criteria** (ALL must be satisfied for Parallel Batch or Swarm):
1. Tasks have **no `depends:` edges** between them in the DAG
2. **Enough parallelizable tasks** that multi-agent overhead is worth it
3. Each task is **self-contained** (does not require runtime results from other tasks in the same batch)
4. Each task's **target files do not overlap** with any other task in the batch

If ANY criterion fails → sequential execution.

---

## Sequential Mode

Execute one at a time in order.

- On task start: `▶ {ID}: {description}`
- On completion: `✓ {ID} complete`

---

## Parallel Batch Mode

For a moderate number of independent [P] tasks where a single round of Task() calls suffices.

### Step 1 — Register (phase-locked)

Create tasks for the current phase only. Never pre-register future phases.

```
TaskCreate({ subject: "T003: Create UserService", description: "..." })
TaskCreate({ subject: "T004: Create AuthService", description: "..." })
TaskUpdate({ taskId: "T004", addBlockedBy: ["T002"] })  // if T004 depends on T002
```

### Step 2 — Launch in a single message

Multiple Task() calls in a single message run concurrently (up to ~10):

```
Task("T003: Create UserService", subagent_type: "afc:afc-impl-worker",
  isolation: "worktree",
  prompt: "Implement the following task:

  ## Task
  {task ID}: {description} — `{file path}`

  ## Implementation Context
  {paste full ## Implementation Context section from plan.md}

  ## Relevant Acceptance Criteria
  {extract FR/AC items from spec.md that relate to this task — NOT the full spec}
  {e.g., FR-001, FR-003, SC-002 — with their full text from spec.md}

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

### Step 3 — Collect and verify

1. Read each agent's returned output and verify completion
2. **Post-task individual verification** (per worker):
   a. If `{config.gate}` is non-empty: run it against the worker's changed files only. If empty: skip (log "no gate configured, skipping")
   b. Check `git diff` to confirm changes stay within the task's declared file scope
   c. If verification fails → main agent fixes directly (do NOT re-delegate)
3. Mark `TaskUpdate(status: "completed")` for each verified task
4. **Poll for unblocked tasks**: Call `TaskList`, check `blockedBy` lists manually. Auto-unblocking is only guaranteed in Agent Teams mode; orchestrator must poll.
5. If newly-unblockable tasks exist → launch next batch (repeat Step 2)
6. If no more pending tasks remain → phase complete

### Failure Recovery (Parallel Batch)

1. Identify the failed task from the agent's error return
2. Capture the `agentId` from the failed agent's result
3. Reset: `TaskUpdate(taskId, status: "pending")`
4. Track: `TaskUpdate(taskId, metadata: { retryCount: N, lastAgentId: agentId })`
5. **Error classification before retry**:
   - **First failure** (no `metadata.lastError`): store error, classify as transient, proceed with retry
   - **Subsequent failures** (`metadata.lastError` exists):
     - Same error → stop immediately, mark as failed (deterministic failure — retrying wastes cycles)
     - Different error → re-launch with `resume: lastAgentId` (transient/flaky — resumed agent retains prior context)
   - **Worktree caveat**: if worker made no file changes, its worktree is auto-cleaned; `resume` will fail → use fresh launch (omit `resume`)
   - Update `metadata.lastError` on each attempt
6. If `retryCount >= 5` → mark as failed, report: `"T{ID} failed after {retryCount} attempts: {last error}"`
7. Continue with remaining tasks — a single failure does not block the entire phase

---

## Swarm Mode

For a high number of independent [P] tasks that would saturate the concurrent agent limit in a single batch, requiring multiple orchestrator rounds.

> **Key constraint**: `TaskUpdate` uses last-write-wins with local file locking only. Multiple sub-agents calling `TaskUpdate` on the same task simultaneously can cause lost writes. The orchestrator must mediate task assignment to prevent collisions.

### Step 1 — Register (phase-locked)

```
// Register ONLY this phase's tasks — never register future phases
TaskCreate({ subject: "T007: Create ComponentA", description: "..." })
TaskCreate({ subject: "T008: Create ComponentB", description: "..." })
// ... for all tasks in this phase
TaskUpdate({ taskId: "T008", addBlockedBy: ["T006"] })  // if dependency exists
```

### Step 2 — Orchestrator pre-assigns tasks (no self-claiming)

Workers do NOT call TaskList/TaskUpdate to claim tasks — this avoids last-write-wins race conditions.

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

  ## Relevant Acceptance Criteria
  {extract FR/AC items from spec.md that relate to these tasks — NOT the full spec}

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

**Worker count**: N = min(5, unblocked task count). Max 5 concurrent sub-agents per phase (platform limit).

**Task assignment strategy**: Round-robin by file path — each worker gets tasks targeting different files to maximize isolation. If a worker has multiple tasks, order them by `depends:` topology.

### Step 3 — Collect and verify

1. Wait for all workers to return (foreground — never use `run_in_background: true` on Task calls)
2. **Post-task individual verification** (per worker):
   a. If `{config.gate}` is non-empty: run it against each worker's changed files. If empty: skip
   b. Check `git diff` to confirm changes stay within declared file scope
   c. If verification fails → main agent fixes directly (no re-delegation)
3. Read results, mark `TaskUpdate(status: "completed")` for each verified task
4. Call `TaskList` to check remaining pending/blocked tasks
5. If unblocked tasks remain → assign to new worker batch (repeat Step 2)
6. If all tasks complete → phase done

### Failure Recovery (Swarm)

1. Identify which tasks the worker was assigned (from the pre-assigned list)
2. Check which tasks the worker actually completed (from its result summary)
3. Capture the `agentId` from the failed worker's result
4. Reset uncompleted tasks: `TaskUpdate(taskId, status: "pending")`
5. Track retry count: `TaskUpdate(taskId, metadata: { retryCount: N, lastAgentId: agentId })`
6. **Error classification** (same rules as Parallel Batch above):
   - First failure → classify as transient, retry
   - Same error → stop, mark as failed
   - Different error → re-launch with `resume: lastAgentId`
   - Worktree caveat applies: no changes made → auto-cleaned → fresh launch
7. If `retryCount >= 5` → mark as failed, report: `"T{ID} failed after {retryCount} attempts: {last error}"`
8. Continue with remaining tasks

> Single task failure does not block the phase. The orchestrator reassigns failed tasks to subsequent batches.

---

## Dependency Resolution

- Tasks with `depends: [T001, T002]` are registered via `TaskUpdate(addBlockedBy: ["T001", "T002"])`
- **Auto-unblocking is NOT guaranteed in sub-agent mode**. After each batch, the orchestrator:
  1. Calls `TaskList` to get current state
  2. For each pending task, checks if all `blockedBy` tasks are completed
  3. If all blockers resolved → task is eligible for the next batch
- **Phase-locked registration**: Only register tasks for the current phase. Never register Phase N+1 tasks until Phase N is complete and its gate has passed. This prevents workers from claiming future-phase tasks.
- **Cross-phase dependencies**: Phase 2 tasks may `depends:` on Phase 1 tasks. Since Phase 1 must complete before Phase 2 begins, this is always satisfied. Within the same phase, `depends:` creates intra-phase ordering.
