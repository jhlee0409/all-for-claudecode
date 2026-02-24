---
name: afc:auto
description: "Full auto pipeline"
argument-hint: "[feature description in natural language]"
---

# /afc:auto — Full Auto Pipeline

> Runs spec → plan → tasks → implement → review → clean fully automatically from a single feature description.
> No intermediate confirmation. clarify/analyze are skipped. Critic Loop is performed automatically at each phase.

## Arguments

- `$ARGUMENTS` — (required) Feature description in natural language

## Project Config (auto-loaded)

!`cat .claude/afc.config.md 2>/dev/null || echo "[CONFIG NOT FOUND] .claude/afc.config.md not found. Create it with /afc:init."`

## Config Load

**Always** read `.claude/afc.config.md` first (read manually if not auto-loaded above). Values defined in this file are referenced below as `{config.*}`:
- `{config.ci}` — full CI command
- `{config.gate}` — phase gate command
- `{config.architecture}` — architecture style and rules
- `{config.framework}` — framework characteristics (server/client boundary etc.)
- `{config.code_style}` — code style rules
- `{config.risks}` — project-specific risk patterns
- `{config.mini_review}` — Mini-Review checklist items

If config file is missing:
1. Ask the user: "`.claude/afc.config.md` not found. Run `/afc:init` to set up the project?"
2. If user accepts → run `/afc:init`, then **restart this command** with the original `$ARGUMENTS`
3. If user declines → **abort**

---

## Critic Loop Rules (common to all phases)

> **Always** read `${CLAUDE_PLUGIN_ROOT}/docs/critic-loop-rules.md` first and follow it.
> Core: minimum 1 concern per criterion + mandatory Adversarial failure scenario each pass + quantitative evidence required. "PASS" as a single word is prohibited. Uses convergence-based termination with 4 verdicts (PASS/FAIL/ESCALATE/DEFER). On ESCALATE: pause and present options to user even in auto mode.

---

## Execution Steps

### Phase 0: Preparation

1. If `$ARGUMENTS` is empty → print "Please enter a feature description." and abort
2. Check current branch → `BRANCH_NAME`
3. Determine feature name (2-3 keywords → kebab-case)
3.5. **Preflight Check**:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/afc-preflight-check.sh"
   ```
   - If exit 1 (hard failure) → print error and **abort**
   - If warnings only (exit 0) → print warnings and continue
4. **Activate Pipeline Flag** (hook integration):
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" start {feature}
   ```
   - Safety Snapshot created automatically (`afc/pre-auto` git tag)
   - Stop Gate Hook activated (blocks response termination on CI failure)
   - File change tracking started
   - Timeline log: `"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" log pipeline-start "Auto pipeline: {feature}"`
5. Create `.claude/afc/specs/{feature}/` directory → **record path as `PIPELINE_ARTIFACT_DIR`** (for Clean scope)
6. Start notification:
   ```
   Auto pipeline started: {feature}
   ├─ 1/6 Spec → 2/6 Plan → 3/6 Tasks → 4/6 Implement → 5/6 Review → 6/6 Clean
   └─ Running fully automatically (no intermediate confirmation)
   ```

### Phase 1: Spec (1/6)

`"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase spec`

Execute `/afc:spec` logic inline:

1. Explore codebase for related code (Glob, Grep) — explore by `{config.architecture}` layer
2. Create `.claude/afc/specs/{feature}/spec.md`
3. `[NEEDS CLARIFICATION]` items are **auto-resolved with best-guess** (clarify skipped)
   - Tag auto-resolved items with `[AUTO-RESOLVED]`
4. **Retrospective check**: if `.claude/afc/memory/retrospectives/` exists, load and check:
   - Were there previous `[AUTO-RESOLVED]` items that turned out wrong? Flag similar patterns.
   - Were there scope-related issues in past specs? Warn about similar ambiguities.
5. **Critic Loop until convergence** (safety cap: 5, follow Critic Loop rules):
   - COMPLETENESS: does every User Story have acceptance scenarios? Any missing requirements?
   - MEASURABILITY: are success criteria measurable, not subjective? **Is quantitative evidence provided for numerical targets?**
   - INDEPENDENCE: are implementation details (code, library names) absent from the spec?
   - EDGE_CASES: are at least 2 identified? Any missing boundary conditions?
   - FAIL → auto-fix and continue. ESCALATE → pause, present options, resume after response. DEFER → record reason, mark clean.
6. Progress: `✓ 1/6 Spec complete (US: {N}, FR: {N}, Critic: converged ({N} passes, {M} fixes, {E} escalations))`

### Phase 2: Plan (2/6)

`"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase plan`

Execute `/afc:plan` logic inline:

1. Load spec.md
2. If technical uncertainties exist → auto-resolve via WebSearch/code exploration → create research.md
3. **Memory loading** (skip gracefully if directories are empty or absent):
   - **Quality history**: if `.claude/afc/memory/quality-history/*.json` exists, load recent entries and display trend summary: "Last {N} pipelines: avg critic_fixes {X}, avg ci_failures {Y}, avg escalations {Z}". Use trends to inform plan risk assessment.
   - **Decisions**: if `.claude/afc/memory/decisions/` exists, load ADR entries and check for conflicts with the current feature's design direction. Flag any contradictions.
   - **Reviews**: if `.claude/afc/memory/reviews/` exists, scan for recurring finding patterns (same file/category appearing in 2+ reviews). Flag as known risk areas.
4. Create `.claude/afc/specs/{feature}/plan.md`
   - **If setting numerical targets (line counts etc.), include structure-analysis-based estimates** (e.g., "function A ~50 lines, component B ~80 lines → total ~130 lines")
5. **Critic Loop until convergence** (safety cap: 7, follow Critic Loop rules):
   - Criteria: COMPLETENESS, FEASIBILITY, ARCHITECTURE, RISK, PRINCIPLES
   - **RISK criterion mandatory checks**:
     - Enumerate **at least 3** `{config.ci}` failure scenarios and describe mitigation
     - Check each pattern in `{config.risks}` one by one
     - Consider `{config.framework}` characteristics (server/client boundary etc.)
   - **ARCHITECTURE criterion**: explicitly describe import paths for moved/created files and pre-validate against `{config.architecture}` rules
   - Each pass must **explicitly explore what was missed in the previous pass** ("Pass 2: {X} was missed in pass 1. Further review: ...")
   - FAIL → auto-fix and continue. ESCALATE → pause, present options, resume after response. DEFER → record reason, mark clean.
6. Progress: `✓ 2/6 Plan complete (Critic: converged ({N} passes, {M} fixes, {E} escalations), files: {N})`

### Phase 3: Tasks (3/6)

`"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase tasks`

Execute `/afc:tasks` logic inline:

1. Load plan.md
2. Decompose tasks by phase (T001, T002, ...)
3. **[P] marker and dependency rules**:
   - Assign `[P]` marker to independent tasks with no overlapping file paths
   - Use explicit `depends: [TXXX]` for cross-task dependencies (replaces informal `(after TXXX)`)
   - Validate dependency graph is a DAG (no circular references)
   - [P] tasks **must be executed in parallel** in Phase 4 (declaring [P] then running sequentially is prohibited)
4. Coverage mapping (FR → Task)
5. **Retrospective check**: if `.claude/afc/memory/retrospectives/` exists, load and check:
   - Were there previous parallel conflict issues ([P] file overlaps)? Flag similar file patterns.
   - Were there tasks that were over-decomposed or under-decomposed? Adjust granularity.
6. **Critic Loop until convergence** (safety cap: 5, follow Critic Loop rules):
   - COVERAGE: is every FR/NFR mapped to at least 1 task?
   - DEPENDENCIES: is the dependency graph a valid DAG? Do [P] tasks have no file overlaps?
   - FAIL → auto-fix and continue. ESCALATE → pause, present options, resume after response. DEFER → record reason, mark clean.
7. Create `.claude/afc/specs/{feature}/tasks.md`
8. Progress: `✓ 3/6 Tasks complete (tasks: {N}, parallel: {N}, Critic: converged ({N} passes, {M} fixes, {E} escalations))`

### Phase 4: Implement (4/6)

`"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase implement`

Execute `/afc:implement` logic inline with **dependency-aware orchestration**:

1. Parse tasks.md — extract task IDs, [P] markers, `depends:` lists, file paths
2. Build dependency graph per phase (validate DAG)
3. **Orchestration mode selection** (per phase, automatic):

   | [P] tasks in phase | Mode | Strategy |
   |---------------------|------|----------|
   | 0 | Sequential | Execute tasks one by one |
   | 1–5 | Parallel Batch | Register tasks → set dependencies → launch Task() calls |
   | 6+ | Swarm | Task pool + self-organizing worker agents (max 5 workers) |

4. **Parallel Batch mode** (1–5 [P] tasks):
   ```
   TaskCreate({ subject: "T012: Move AudioFadeControl", ... })
   TaskCreate({ subject: "T013: Move AudioVolumeControl", ... })
   TaskUpdate({ taskId: "T013", addBlockedBy: ["T011"] })  // if dependency exists
   → launch unblocked tasks as parallel Task() calls in a single message
     (each with isolation: "worktree" and subagent_type: "afc-impl-worker")
   → read results → handle failures (see below) → launch newly-unblocked → repeat until phase complete
   ```

   **Batch Worker Failure Recovery**: When a parallel Task() call returns an error:
   1. Identify the failed task from the agent's return
   2. Reset the task: `TaskUpdate(taskId, status: "pending")`
   3. Track retry count per task via `TaskUpdate(taskId, metadata: { retryCount: N })`
   4. If retryCount < 3 → re-launch the failed task (in the next batch alongside newly-unblocked tasks)
   5. If retryCount >= 3 → mark as failed, report to user: `"T{ID} failed after 3 attempts: {last error}"`
   6. Continue with remaining tasks — a single failure does not block the entire phase

5. **Swarm mode** (6+ [P] tasks):
   ```
   // 1. Register all phase tasks via TaskCreate
   // 2. Set up dependencies via TaskUpdate(addBlockedBy)
   // 3. Spawn N worker agents (N = min(5, unblocked count))
   Task("Swarm Worker 1", subagent_type: "afc-impl-worker",
     isolation: "worktree",
     prompt: "Self-organizing worker: TaskList → claim → implement → complete → repeat until empty")
   Task("Swarm Worker 2", subagent_type: "afc-impl-worker", isolation: "worktree", ...)
   // 4. Workers self-balance — fast workers claim more tasks
   // 5. Read all worker results before proceeding to gate
   ```

   **Swarm Worker Failure Recovery**: When a worker agent exits with error:
   1. Scan TaskList for tasks with status `in_progress` that have no active worker
   2. Reset each orphaned task: `TaskUpdate(taskId, status: "pending", owner: "")`
   3. Track retry count per task via `TaskUpdate(taskId, metadata: { retryCount: N })` (max 2 retries)
   4. If retryCount >= 3 → mark as `failed`, report to user: `"T{ID} failed after 3 attempts: {last error}"`
   5. Re-spawn replacement workers for remaining tasks

6. Perform **3-step gate** on each Implementation Phase completion — **always** read `${CLAUDE_PLUGIN_ROOT}/docs/phase-gate-protocol.md` first. Cannot advance to next phase without passing the gate.
   - On gate pass: create phase rollback point `"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase-tag {phase_number}`
7. Real-time `[x]` updates in tasks.md
8. After full completion, run `{config.ci}` final verification
   - On pass: `"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" ci-pass` (releases Stop Gate)
9. **Implement Critic Loop until convergence** (safety cap: 3, follow Critic Loop rules):
   > **Always** read `${CLAUDE_PLUGIN_ROOT}/docs/critic-loop-rules.md` first and follow it.
   - **SCOPE_ADHERENCE**: Compare `git diff` changed files against plan.md File Change List. Flag any file modified that is NOT in the plan. Flag any planned file NOT modified. Provide "M of N files match" count.
   - **ARCHITECTURE**: Validate changed files against `{config.architecture}` rules (layer boundaries, naming conventions, import paths). Provide "N of M rules checked" count.
   - **CORRECTNESS**: Cross-check implemented changes against spec.md acceptance criteria (AC). Verify each AC has corresponding code. Provide "N of M AC verified" count.
   - **Adversarial 3-perspective** (mandatory each pass):
     - Skeptic: "Which implementation assumption is most likely wrong?"
     - Devil's Advocate: "How could this implementation be misused or fail unexpectedly?"
     - Edge-case Hunter: "What input would cause this implementation to fail silently?"
     - State one failure scenario per perspective. If realistic → FAIL + fix. If unrealistic → state quantitative rationale.
   - FAIL → auto-fix, re-run `{config.ci}`, and continue. ESCALATE → pause, present options, resume after response. DEFER → record reason, mark clean.
10. **Implement retrospective**: if unexpected problems arose that weren't predicted in Plan, record in `.claude/afc/specs/{feature}/retrospective.md` (for memory update in Clean)
11. Progress: `✓ 4/6 Implement complete ({completed}/{total} tasks, CI: ✓, Critic: converged ({N} passes, {M} fixes, {E} escalations), Checkpoint: ✓)`

### Phase 5: Review (5/6)

`"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase review`

Execute `/afc:review` logic inline:

1. Review implemented changed files (`git diff HEAD`)
2. Check code quality, `{config.architecture}` rules, security, performance, `{config.code_style}` pattern compliance
3. **Past reviews check**: if `.claude/afc/memory/reviews/` exists, scan for recurring finding patterns across past review reports. Identify files/categories that appear in 2+ reviews — prioritize those areas in current review.
4. **Retrospective check**: if `.claude/afc/memory/retrospectives/` exists, load and check:
   - Were there recurring Critical finding categories in past reviews? Prioritize those perspectives.
   - Were there false positives that wasted effort? Reduce sensitivity for those patterns.
5. **Critic Loop until convergence** (safety cap: 5, follow Critic Loop rules):
   - COMPLETENESS: cross-check every SC (success criterion) from spec.md one by one. Provide specific metrics if falling short.
   - PRECISION: are there unnecessary changes? Are there out-of-scope modifications?
   - FAIL → auto-fix and continue. ESCALATE → pause, present options, resume after response. DEFER → record reason, mark clean.
6. **Handling SC shortfalls**:
   - Fixable → attempt auto-fix → re-run `{config.ci}` verification
   - Not fixable → state in final report with reason (no post-hoc rationalization; record as Plan-phase target-setting error)
7. Progress: `✓ 5/6 Review complete (Critical:{N} Warning:{N} Info:{N}, SC shortfalls: {N})`

### Phase 6: Clean (6/6)

`"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase clean`

Artifact cleanup and codebase hygiene check after implementation and review:

1. **Artifact cleanup** (scope-limited):
   - **Delete only the `.claude/afc/specs/{feature}/` directory created by the current pipeline**
   - If other `.claude/afc/specs/` subdirectories exist, **do not delete them** (only inform the user of their existence)
   - Do not leave pipeline intermediate artifacts in the codebase
2. **Dead code scan**:
   - Detect unused imports from the implementation process (check with `{config.ci}`)
   - Remove empty directories from moved/deleted files
   - Detect unused exports (re-exports of moved code from original locations etc.)
3. **Final CI gate**:
   - Run `{config.ci}` final execution
   - Auto-fix on failure (max 2 attempts)
4. **Memory update** (if applicable):
   - Reusable patterns found during pipeline → record in `.claude/afc/memory/`
   - If there were `[AUTO-RESOLVED]` items → record decisions in `.claude/afc/memory/decisions/`
   - **If retrospective.md exists** → record as patterns missed by the Plan phase Critic Loop in `.claude/afc/memory/retrospectives/` (reuse as RISK checklist items in future runs)
   - **If review-report.md exists** → copy to `.claude/afc/memory/reviews/{feature}-{date}.md` before .claude/afc/specs/ deletion
5. **Quality report** (structured pipeline metrics):
   - Generate `.claude/afc/memory/quality-history/{feature}-{date}.json` with the following structure:
     ```json
     {
       "feature": "{feature}",
       "date": "{YYYY-MM-DD}",
       "phases": {
         "spec": { "user_stories": N, "requirements": { "FR": N, "NFR": N }, "auto_resolved": N, "critic_passes": N, "critic_fixes": N, "escalations": N },
         "plan": { "files_planned": N, "critic_passes": N, "critic_fixes": N, "escalations": N },
         "tasks": { "total": N, "parallel": N, "phases": N, "critic_passes": N, "critic_fixes": N, "escalations": N },
         "implement": { "completed": N, "total": N, "ci_passes": N, "ci_failures": N },
         "review": { "critical": N, "warning": N, "info": N, "sc_shortfalls": N, "critic_passes": N, "critic_fixes": N, "escalations": N }
       },
       "totals": { "changed_files": N, "auto_resolved": N, "escalations": N }
     }
     ```
   - Create `.claude/afc/memory/quality-history/` directory if it does not exist
6. **Checkpoint reset**:
   - Clear `.claude/afc/memory/checkpoint.md` (pipeline complete = session goal achieved)
7. **Timeline finalize**:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" log pipeline-end "Pipeline complete: {feature}"
   ```
8. **Release Pipeline Flag** (hook integration):
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" end
   ```
   - Stop Gate Hook deactivated
   - Change tracking log deleted
   - Safety tag removed (successful completion)
   - Phase rollback tags removed (handled automatically by pipeline end)
9. Progress: `✓ 6/6 Clean complete (deleted: {N}, dead code: {N}, CI: ✓)`

### Final Output

```
Auto pipeline complete: {feature}
├─ Spec: US {N}, FR {N}
├─ Plan: Critic converged ({N} passes, {M} fixes, {E} escalations), research {present/absent}
├─ Tasks: {total} (parallel {N})
├─ Implement: {completed}/{total} tasks, CI ✓, Checkpoint ✓
├─ Review: Critical:{N} Warning:{N} Info:{N}, SC shortfalls: {N}
├─ Clean: {N} artifacts deleted, {N} dead code removed
├─ Changed files: {N}
├─ Auto-resolved: {N} (review recommended)
├─ Retrospective: {present/absent}
└─ .claude/afc/specs/{feature}/ cleaned up
```

## Abort Conditions

**Abort** the pipeline and report to user in these situations:

1. `{config.ci}` fails 3 consecutive times
2. File conflict during implementation (overlaps with changes from another branch)
3. Critical security issue found (cannot auto-fix)

On abort:
```
Pipeline aborted (Phase {N}/6)
├─ Reason: {abort cause}
├─ Completed phases: {completed list}
├─ Rollback: git reset --hard afc/pre-auto (restores state before implementation)
├─ Checkpoint: .claude/afc/memory/checkpoint.md (last phase gate passed)
├─ Artifacts: .claude/afc/specs/{feature}/ (partial completion, manual deletion needed if Clean did not run)
└─ Resume: /afc:resume → /afc:implement (checkpoint-based)
```

## Notes

- **Full auto**: runs to completion without intermediate confirmation. Fast but direction cannot be changed mid-run.
- **Review auto-resolved items**: items tagged `[AUTO-RESOLVED]` are estimates; review after the fact is recommended.
- **Large feature warning**: warn before starting if more than 5 User Stories are expected.
- **Read existing code first**: always read existing files before modifying. Do not blindly generate code.
- **Follow project rules**: project rules in `afc.config.md` and `CLAUDE.md` take priority.
- **Critic Loop is not a ritual**: a single "PASS" line is equivalent to not running Critic at all. Always follow the format in the Critic Loop rules section. Critic uses convergence-based termination — it may finish in 1 pass or take several, depending on the output quality.
- **ESCALATE pauses auto mode**: when a Critic finds an ambiguous issue requiring user judgment, the pipeline pauses and presents options via AskUserQuestion. Auto mode automates clear decisions but escalates ambiguous ones.
- **[P] parallel is mandatory**: if a [P] marker is assigned in tasks.md, it must be executed in parallel. Orchestration mode (batch vs swarm) is selected automatically based on task count. Sequential substitution is prohibited.
- **Swarm mode is automatic**: when a phase has 6+ [P] tasks, swarm workers self-organize via TaskList/TaskUpdate. Do not manually batch.
- **No out-of-scope deletion**: do not delete files/directories in Clean that were not created by the current pipeline.
- **NEVER use `run_in_background: true` on Task calls**: agents must run in foreground so results are returned before the next step.
