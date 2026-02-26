---
name: afc:auto
description: "Full auto pipeline"
argument-hint: "[feature description in natural language]"
---

# /afc:auto — Full Auto Pipeline

> Runs clarify? → spec → plan → implement → review → clean fully automatically from a single feature description.
> Tasks are generated automatically at implement start (no separate tasks phase).
> Critic Loop runs at each phase with unified safety cap (5). Convergence terminates early when quality is sufficient.
> Pre-implementation gates (clarify, TDD pre-gen, blast-radius) run conditionally within the implement phase.

## Arguments

- `$ARGUMENTS` — (required) Feature description in natural language

## Project Config (auto-loaded)

!`cat .claude/afc.config.md 2>/dev/null || echo "[CONFIG NOT FOUND] .claude/afc.config.md not found. Create it with /afc:init."`

## Config Load

**Always** read `.claude/afc.config.md` first (read manually if not auto-loaded above). Values defined in this file are referenced below as `{config.*}`:
- `{config.ci}` — full CI command (from `## CI Commands` YAML)
- `{config.gate}` — phase gate command (from `## CI Commands` YAML)
- `{config.test}` — test command (from `## CI Commands` YAML)
- `{config.architecture}` — architecture style and rules (from `## Architecture` section)
- `{config.code_style}` — code style rules (from `## Code Style` section)

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
   ├─ Clarify? → 1/5 Spec → 2/5 Plan → 3/5 Implement → 4/5 Review → 5/5 Clean
   └─ Running fully automatically (tasks auto-generated, pre-implementation gates conditional)
   ```

### Phase 0.3: Request Triage

Before investing pipeline resources, evaluate whether the request warrants execution:

1. **Necessity check**: Explore codebase for existing implementations related to `$ARGUMENTS`.
   - If the feature substantially exists → ask user via AskUserQuestion:
     - "This feature appears to already exist at {path}. (1) Enhance existing (2) Replace entirely (3) Abort"
   - If user chooses abort → release pipeline flag (`"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" end`), end with: `"Pipeline aborted — feature already exists."`

2. **Scope check**: Estimate the scope of `$ARGUMENTS`:
   - If description implies 10+ files or multiple unrelated concerns → warn:
     - "This request spans multiple concerns: {list}. Recommended: split into {N} separate pipeline runs."
   - Ask: "(1) Proceed as single pipeline (2) Reduce scope to {suggestion} (3) Abort"

3. **Proportionality check**: If the request is trivially small (single file, single-line change, config edit):
   - Suggest: "This change is small enough to implement directly. Skip full pipeline?"
   - If user agrees → execute fast-path directly, skip spec/plan/tasks

If all checks pass, proceed to Phase 0.8.

### Phase 0.8: Size-Based Fast-Path Detection (conditional)

**Trigger condition**: Evaluate `$ARGUMENTS` against ALL 3 criteria. Fast-path activates only when ALL are met:

| Criterion | Check | Example |
|-----------|-------|---------|
| Trivial scope | Description explicitly mentions 1-2 specific files or a single-line fix | "fix typo in README", "update version in package.json" |
| No script impact | Description does not reference `.sh` scripts, hooks, or pipeline logic | NOT: "fix the hook script" |
| Low ambiguity | Clarify gate score < 2 (very clear, specific request) | "change 'foo' to 'bar' in config.md" |

**If ALL 3 criteria met** (fast-path):
1. Print: `⚡ Fast path detected — skipping spec/plan phases`
2. Jump directly to **Fast-Path Execution** (see below)
3. Skip Phases 0.5 through 3.3 entirely

**If ANY criterion fails**: proceed to Phase 0.5 (full pipeline).

**Fast-Path Execution** (implement → review → clean):
1. Implement the change directly (no tasks.md, no plan.md)
2. Run `{config.ci}` verification
   - On fail: **abort fast-path**, restart with full pipeline: `⚠ Fast-path aborted — change is more complex than expected. Running full pipeline.`
3. If change touches > 2 files OR modifies any `.sh` script: **abort fast-path**, restart with full pipeline
4. **Checkpoint**:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase fast-path
   "${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" ci-pass
   ```
5. Run `/afc:review` logic inline (mini-review only — single Critic pass)
6. Run Phase 5 Clean logic (artifact cleanup, CI gate, pipeline flag release)
7. Final output:
   ```
   Fast path complete: {feature}
   ├─ Mode: ⚡ Fast path (spec/plan skipped)
   ├─ Changed files: {N}
   ├─ CI: ✓
   └─ Review: mini-review passed
   ```

### Phase 0.5: Auto-Clarify Gate (conditional)

`"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase clarify`

**Trigger condition**: Score `$ARGUMENTS` on 5 ambiguity signals. If score >= 3, trigger clarification.

| Signal | Detection | Example |
|--------|-----------|---------|
| Vague scope | No specific file, component, or module mentioned | "add caching" |
| Missing quantifiers | No numbers, sizes, limits, or thresholds | "improve performance" |
| Undefined entities | References to concepts not in the codebase | "integrate the new service" |
| Unclear boundaries | No start/end conditions or scope limits | "refactor the system" |
| Multiple interpretations | Ambiguous verbs or overloaded terms | "fix the pipeline" (which one?) |

**If score >= 3** (ambiguous):
1. Generate at most 3 clarification questions targeting the highest-signal areas
2. Present via AskUserQuestion with multiple-choice options
3. Apply answers to refine `$ARGUMENTS` before proceeding to Spec
4. If in full-auto mode and user prefers no interruption: auto-resolve with best-guess, tag with `[AUTO-RESOLVED: clarify]`, emit warning
5. Progress: `✓ Clarify gate triggered ({N} questions, {M} auto-resolved)`

**If score < 3** (clear): skip silently, proceed to Phase 1.

### Phase 1: Spec (1/5)

`"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase spec`

Execute `/afc:spec` logic inline:

1. Explore codebase for related code (Glob, Grep) — explore by `{config.architecture}` layer
2. **Research Gate** (conditional):
   - Scan `$ARGUMENTS` for external library/API/technology references not present in the codebase
   - If external references found: run focused WebSearch for each (latest stable version, key constraints, compatibility)
   - Optionally use Context7 for library-specific documentation
   - Use research findings to inform spec writing (accurate requirements instead of guesses)
   - Tag researched items with `[RESEARCHED]` in spec
   - If no external references: skip (all internal → no research needed)
3. Create `.claude/afc/specs/{feature}/spec.md`
4. `[NEEDS CLARIFICATION]` items: **research first, then auto-resolve remaining** (clarify skipped if Phase 0.5 already ran)
   - Items answerable via research → resolve with researched facts, tag `[RESEARCHED]`
   - Items requiring user judgment → auto-resolve with best-guess, tag `[AUTO-RESOLVED]`
5. **Retrospective check**: if `.claude/afc/memory/retrospectives/` exists, load the **most recent 10 files** (sorted by filename descending) and check:
   - Were there previous `[AUTO-RESOLVED]` items that turned out wrong? Flag similar patterns.
   - Were there scope-related issues in past specs? Warn about similar ambiguities.
6. **Critic Loop until convergence** (safety cap: 5, follow Critic Loop rules):
   - COMPLETENESS: does every User Story have acceptance scenarios? Any missing requirements?
   - MEASURABILITY: are success criteria measurable, not subjective? **Is quantitative evidence provided for numerical targets?**
   - INDEPENDENCE: are implementation details (code, library names) absent from the spec?
   - EDGE_CASES: are at least 2 identified? Any missing boundary conditions?
   - FAIL → auto-fix and continue. ESCALATE → pause, present options, resume after response. DEFER → record reason, mark clean.
7. **Checkpoint**: phase transition already recorded by `afc-pipeline-manage.sh phase spec` at phase start
8. Progress: `✓ 1/5 Spec complete (US: {N}, FR: {N}, researched: {N}, Critic: converged ({N} passes, {M} fixes, {E} escalations))`

### Phase 2: Plan (2/5)

`"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase plan`

Execute `/afc:plan` logic inline:

1. Load spec.md
2. If technical uncertainties exist → auto-resolve via WebSearch/code exploration → create research.md
3. **Memory loading** (skip gracefully if directories are empty or absent):
   - **Quality history**: if `.claude/afc/memory/quality-history/*.json` exists, load the **most recent 10 files** (sorted by filename descending) and display trend summary: "Last {N} pipelines: avg critic_fixes {X}, avg ci_failures {Y}, avg escalations {Z}". Use trends to inform plan risk assessment.
   - **Decisions**: if `.claude/afc/memory/decisions/` exists, load the **most recent 30 files** (sorted by filename descending) and check for conflicts with the current feature's design direction. Flag any contradictions.
   - **Reviews**: if `.claude/afc/memory/reviews/` exists, load the **most recent 15 files** (sorted by filename descending) and scan for recurring finding patterns (same file/category appearing in 2+ reviews). Flag as known risk areas.
4. Create `.claude/afc/specs/{feature}/plan.md`
   - **If setting numerical targets (line counts etc.), include structure-analysis-based estimates** (e.g., "function A ~50 lines, component B ~80 lines → total ~130 lines")
5. **Critic Loop until convergence** (safety cap: 5, follow Critic Loop rules):
   - Criteria: COMPLETENESS, FEASIBILITY, ARCHITECTURE, **CROSS_CONSISTENCY**, RISK, PRINCIPLES
   - **CROSS_CONSISTENCY criterion** (spec↔plan cross-validation, check all 5):
     1. Entity coverage: every spec Key Entity → File Change Map row. `{M}/{N} entities covered`
     2. NFR traceability: every NFR-* → Architecture Decision or Risk mitigation. `{M}/{N} NFRs traced`
     3. Terminology consistency: same concept = same name across spec and plan
     4. Constraint propagation: every spec Constraint → Risk & Mitigation or Implementation Context Must NOT. `{M}/{N} constraints propagated`
     5. Acceptance anchor alignment: Implementation Context Acceptance Anchors faithfully reflect spec acceptance scenarios
   - **RISK criterion mandatory checks**:
     - Enumerate **at least 3** `{config.ci}` failure scenarios and describe mitigation
     - Check each risk pattern described in config's Project Context section one by one
     - Consider framework characteristics from config's Project Context (server/client boundary etc.)
   - **ARCHITECTURE criterion**: explicitly describe import paths for moved/created files and pre-validate against `{config.architecture}` rules
   - Each pass must **explicitly explore what was missed in the previous pass** ("Pass 2: {X} was missed in pass 1. Further review: ...")
   - FAIL → auto-fix and continue. ESCALATE → pause, present options, resume after response. DEFER → record reason, mark clean.
6. **Research persistence**: If research.md was created in step 2, persist a copy to long-term memory:
   - Copy research findings to `.claude/afc/memory/research/{feature}.md`
   - This enables future pipelines to reference prior research decisions
7. **ADR recording via architect agent**: After plan.md is written, invoke the architect agent to record architectural decisions:
   ```
   Task("ADR: Record architecture decisions for {feature}", subagent_type: "afc:afc-architect",
     prompt: "Review the following plan and record key architecture decisions to your persistent memory.

     ## Plan Summary
     {paste Architecture Decision + File Change Map sections from plan.md}

     ## Instructions
     1. Read your MEMORY.md for prior ADR history
     2. Check for conflicts between new decisions and existing ADRs
     3. If conflicts found: return CONFLICT with details (orchestrator will ESCALATE)
     4. If no conflicts: record new ADRs to your MEMORY.md
     5. Return: { decisions_recorded: N, conflicts: [] }")
   ```
   - If architect returns conflicts → **ESCALATE** to user with conflict details
   - If no conflicts → proceed (ADR recorded for future reference)
8. **Session context preservation**: Write key decisions to `.claude/afc/specs/{feature}/context.md` for compaction resilience:
   ```markdown
   # Session Context: {feature}
   ## Goal
   - Original request: $ARGUMENTS
   - Current objective: Implement {feature}
   ## Key Decisions
   - {what}: {rationale}
   ## Discoveries
   - {file path}: {finding}
   ```
   This file is read at Implement start to restore context after compaction.
9. **Checkpoint**: phase transition already recorded by `afc-pipeline-manage.sh phase plan` at phase start
10. Progress: `✓ 2/5 Plan complete (Critic: converged ({N} passes, {M} fixes, {E} escalations), files: {N}, ADR: {N} recorded, Implementation Context: {W} words)`

### Phase 3: Implement (3/5)

`"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase implement`

**Session context reload**: At implement start, read `.claude/afc/specs/{feature}/context.md` if it exists. This restores key decisions and constraints from Plan phase (resilient to context compaction).

Execute `/afc:implement` logic inline — **follow all orchestration rules defined in `commands/implement.md`** (task generation, mode selection, batch/swarm execution, failure recovery, task execution pattern). The implement command is the single source of truth for orchestration details.

**Auto-specific additions** (beyond implement.md):

#### Step 3.1: Task Generation + Validation

1. Generate tasks.md from plan.md File Change Map (as defined in implement.md Step 1.3)
2. **Retrospective check**: if `.claude/afc/memory/retrospectives/` exists, load the **most recent 10 files** (sorted by filename descending) and check:
   - Were there previous parallel conflict issues ([P] file overlaps)? Flag similar file patterns.
   - Were there tasks that were over-decomposed or under-decomposed? Adjust granularity.
3. Script validation (DAG + parallel overlap) — no critic loop, script-based only
4. Progress: `  ├─ Tasks generated: {N} ({P} parallelizable)`

#### Step 3.2: TDD Pre-Generation (conditional)

`"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase test-pre-gen`

**Trigger condition**: tasks.md contains at least 1 task targeting a `.sh` file in `scripts/`.

**If triggered**:
1. Run the test pre-generation script:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/afc-test-pre-gen.sh" ".claude/afc/specs/{feature}/tasks.md" "spec/"
   ```
2. Review generated skeleton files — verify they are parseable:
   ```bash
   {config.test}  # should show Pending examples, not errors
   ```
3. Create `.claude/afc/specs/{feature}/tests-pre.md` listing generated test expectations per task
4. Progress: `  ├─ TDD pre-gen: {N} skeletons generated`

**If not triggered** (no `.sh` tasks): skip silently.

**Note**: Generated tests contain `Pending` examples — implementation agents replace these with real assertions during implementation.

#### Step 3.3: Blast Radius Analysis (conditional)

`"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase blast-radius`

**Trigger condition**: plan.md File Change Map lists >= 3 files to change.

**If triggered**:
1. Run the blast radius analysis:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/afc-blast-radius.sh" ".claude/afc/specs/{feature}/plan.md" "${CLAUDE_PROJECT_DIR}"
   ```
2. If exit 1 (cycle detected): **ESCALATE** — present the cycle to user with options:
   - Option 1: Refactor plan to break the cycle
   - Option 2: Acknowledge the cycle and proceed (mark as [DEFERRED])
3. If high fan-out files detected (>5 dependents): emit warning, add as RISK note in plan.md
4. Save output to `.claude/afc/specs/{feature}/impact.md`
5. Progress: `  ├─ Blast radius: {N} planned, {M} dependents`

**If not triggered** (< 3 files): skip silently (small changes have bounded blast radius).

#### Step 3.4: Execution

1. Execute tasks phase by phase using implement.md orchestration rules (sequential/batch/swarm based on [P] count)
2. **Implementation Context injection**: Every sub-agent prompt includes the `## Implementation Context` section from plan.md (ensures spec intent propagates to workers)
3. Perform **3-step gate** on each Implementation Phase completion — **always** read `${CLAUDE_PLUGIN_ROOT}/docs/phase-gate-protocol.md` first. Cannot advance to next phase without passing the gate.
   - On gate pass: create phase rollback point `"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase-tag {phase_number}`
4. Real-time `[x]` updates in tasks.md
5. After full completion, run `{config.ci}` final verification
   - On pass: `"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" ci-pass` (releases Stop Gate)
   - **On fail: Debug-based RCA** (replaces blind retry):
     1. Execute `/afc:debug` logic inline with the CI error output as input
     2. Debug performs RCA: error trace → data flow → hypothesis → targeted fix
     3. Re-run `{config.ci}` after fix
     4. If debug-fix cycle fails 3 times → **abort** (not a simple fix — requires user intervention)
     5. This replaces the previous "retry max 3 attempts" pattern with intelligent diagnosis

#### Step 3.5: Acceptance Test Generation (conditional)

**Trigger condition**: spec.md contains acceptance scenarios (Given/When/Then blocks) AND `{config.test}` is configured (non-empty).

**If triggered**:
1. Extract all GWT (Given/When/Then) acceptance scenarios from spec.md
2. Execute `/afc:test` logic inline — generate test cases from acceptance scenarios:
   ```
   For each acceptance scenario in spec.md:
   - Map GWT to a test case: Given → Arrange, When → Act, Then → Assert
   - Target file: determined by the component/module referenced in the scenario
   - Test file location: follows project convention (test framework from Project Context)
   ```
3. Run `{config.test}` to verify tests pass against the implementation
   - If tests fail → this reveals a gap between spec and implementation:
     - Fixable implementation issue → apply targeted fix
     - Spec-implementation mismatch → record as SC shortfall for Review phase
4. Progress: `  ├─ Acceptance tests: {N} generated, {M} passing`

**If not triggered** (no GWT scenarios or no test framework configured): skip silently.

#### Step 3.6: Implement Critic Loop

> **Always** read `${CLAUDE_PLUGIN_ROOT}/docs/critic-loop-rules.md` first and follow it.

**Critic Loop until convergence** (safety cap: 5, follow Critic Loop rules):
- **SCOPE_ADHERENCE**: Compare `git diff` changed files against plan.md File Change Map. Flag any file modified that is NOT in the plan. Flag any planned file NOT modified. Provide "M of N files match" count.
- **ARCHITECTURE**: Validate changed files against `{config.architecture}` rules (layer boundaries, naming conventions, import paths). Provide "N of M rules checked" count.
- **CORRECTNESS**: Cross-check implemented changes against spec.md acceptance criteria (AC). Verify each AC has corresponding code. Provide "N of M AC verified" count.
- **Adversarial 3-perspective** (mandatory each pass):
  - Skeptic: "Which implementation assumption is most likely wrong?"
  - Devil's Advocate: "How could this implementation be misused or fail unexpectedly?"
  - Edge-case Hunter: "What input would cause this implementation to fail silently?"
  - State one failure scenario per perspective. If realistic → FAIL + fix. If unrealistic → state quantitative rationale.
- FAIL → auto-fix, re-run `{config.ci}`, and continue. ESCALATE → pause, present options, resume after response. DEFER → record reason, mark clean.

6. **Implement retrospective**: if unexpected problems arose that weren't predicted in Plan, record in `.claude/afc/specs/{feature}/retrospective.md` (for memory update in Clean)
7. **Checkpoint**: phase transition already recorded by `afc-pipeline-manage.sh phase implement` at phase start
8. Progress: `✓ 3/5 Implement complete ({completed}/{total} tasks, CI: ✓, Critic: converged ({N} passes, {M} fixes, {E} escalations))`

### Phase 4: Review (4/5)

`"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase review`

Execute `/afc:review` logic inline — **follow all review perspectives defined in `commands/review.md`** (A through H). The review command is the single source of truth for review criteria.

1. Review implemented changed files (`git diff HEAD`)
2. **Specialist agent delegation** (parallel, perspectives B and C):
   Launch architect and security agents in a **single message** to leverage their persistent memory:
   ```
   Task("Architecture Review: {feature}", subagent_type: "afc:afc-architect",
     prompt: "Review the following changed files for architecture compliance.

     ## Changed Files
     {list of changed files from git diff}

     ## Architecture Rules
     {config.architecture}

     ## Instructions
     1. Read your MEMORY.md for prior architecture patterns and ADRs
     2. Check each file against architecture rules (layer boundaries, naming, placement)
     3. Cross-reference with ADRs recorded during Plan phase — any violations?
     4. Return findings as: severity (Critical/Warning/Info), file:line, issue, suggested fix
     5. Update your MEMORY.md with any new architecture patterns discovered")

   Task("Security Review: {feature}", subagent_type: "afc:afc-security",
     prompt: "Scan the following changed files for security vulnerabilities.

     ## Changed Files
     {list of changed files from git diff}

     ## Instructions
     1. Read your MEMORY.md for known vulnerability patterns and false positives
     2. Check for: command injection, path traversal, unvalidated input, sensitive data exposure
     3. Skip patterns recorded as false positives in your memory
     4. Return findings as: severity (Critical/Warning/Info), file:line, issue, suggested fix
     5. Update your MEMORY.md with new patterns or confirmed false positives")
   ```
   - Collect agent outputs and merge into the consolidated review
   - Agent findings inherit their severity classification directly
3. Check across **8 perspectives** (A-H as defined in review.md):
   - A. Code Quality — `{config.code_style}` compliance (direct review)
   - B. Architecture — **delegated to afc-architect agent** (persistent memory, ADR-aware)
   - C. Security — **delegated to afc-security agent** (persistent memory, false-positive-aware)
   - D. Performance — framework-specific patterns from Project Context (direct review)
   - E. Project Pattern Compliance — conventions and idioms (direct review)
   - **F. Reusability** — DRY, shared utilities, abstraction level (direct review)
   - **G. Maintainability** — AI/human comprehension, naming clarity, self-contained files (direct review)
   - **H. Extensibility** — extension points, OCP, future modification cost (direct review)
4. **Auto-resolved validation**: Check all `[AUTO-RESOLVED]` items from spec phase — does the implementation match the guess? Flag mismatches as Critical.
5. **Past reviews check**: if `.claude/afc/memory/reviews/` exists, load the **most recent 15 files** (sorted by filename descending) and scan for recurring finding patterns across past review reports. Prioritize those areas.
6. **Retrospective check**: if `.claude/afc/memory/retrospectives/` exists, load the **most recent 10 files** (sorted by filename descending) and check:
   - Were there recurring Critical finding categories in past reviews? Prioritize those perspectives.
   - Were there false positives that wasted effort? Reduce sensitivity for those patterns.
7. **Critic Loop until convergence** (safety cap: 5, follow Critic Loop rules):
   - COMPLETENESS: were all changed files reviewed across all 8 perspectives (A-H)?
   - SPEC_ALIGNMENT: cross-check implementation against spec.md — (1) every SC verified with `{M}/{N}` count, (2) every acceptance scenario (GWT) has corresponding code path, (3) no spec constraint is violated
   - PRECISION: are there unnecessary changes? Are there out-of-scope modifications?
   - FAIL → auto-fix and continue. ESCALATE → pause, present options, resume after response. DEFER → record reason, mark clean.
8. **Handling SC shortfalls**:
   - Fixable → attempt auto-fix → re-run `{config.ci}` verification
   - Not fixable → state in final report with reason (no post-hoc rationalization; record as Plan-phase target-setting error)
9. **Checkpoint**: phase transition already recorded by `afc-pipeline-manage.sh phase review` at phase start
10. Progress: `✓ 4/5 Review complete (Critical:{N} Warning:{N} Info:{N}, SC shortfalls: {N})`

### Phase 5: Clean (5/5)

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
   - **If research.md exists** and was not already persisted in Plan phase → copy to `.claude/afc/memory/research/{feature}.md`
   - **Agent memory consolidation**: architect and security agents have already updated their persistent MEMORY.md during Review phase. **Size enforcement**: check each agent's MEMORY.md line count — if either exceeds 100 lines, invoke the respective agent to self-prune:
     ```
     Task("Memory cleanup: afc-architect", subagent_type: "afc:afc-architect",
       prompt: "Your MEMORY.md exceeds 100 lines. Read it, prune old/redundant entries, and rewrite to under 100 lines following your size limit rules.")
     ```
     (Same pattern for afc-security if needed. Skip if both are under 100 lines.)
   - **Memory rotation**: for each memory subdirectory, check file count and prune oldest files if over threshold:
     | Directory | Threshold | Action |
     |-----------|-----------|--------|
     | `quality-history/` | 30 files | Delete oldest files beyond threshold |
     | `reviews/` | 40 files | Delete oldest files beyond threshold |
     | `retrospectives/` | 30 files | Delete oldest files beyond threshold |
     | `research/` | 50 files | Delete oldest files beyond threshold |
     | `decisions/` | 60 files | Delete oldest files beyond threshold |
     - Sort by filename ascending (oldest first), delete excess
     - Log: `"Memory rotation: {dir} pruned {N} files"`
     - Skip directories that do not exist or are under threshold
5. **Quality report** (structured pipeline metrics):
   - Generate `.claude/afc/memory/quality-history/{feature}-{date}.json` with the following structure:
     ```json
     {
       "feature": "{feature}",
       "date": "{YYYY-MM-DD}",
       "phases": {
         "clarify": { "triggered": true/false, "questions": N, "auto_resolved": N },
         "spec": { "user_stories": N, "requirements": { "FR": N, "NFR": N }, "researched": N, "auto_resolved": N, "critic_passes": N, "critic_fixes": N, "escalations": N },
         "plan": { "files_planned": N, "implementation_context_words": N, "adr_recorded": N, "adr_conflicts": N, "research_persisted": true/false, "critic_passes": N, "critic_fixes": N, "escalations": N },
         "implement": {
           "tasks": { "total": N, "parallel": N, "phases": N },
           "test_pre_gen": { "triggered": true/false, "skeletons": N },
           "blast_radius": { "triggered": true/false, "dependents": N, "high_fan_out": N },
           "completed": N, "total": N, "ci_passes": N, "ci_failures": N,
           "acceptance_tests": { "triggered": true/false, "generated": N, "passing": N },
           "debug_rca": { "triggered": true/false, "cycles": N },
           "critic_passes": N, "critic_fixes": N, "escalations": N
         },
         "review": { "critical": N, "warning": N, "info": N, "sc_shortfalls": N, "auto_resolved_mismatches": N,
           "architect_agent": { "invoked": true/false, "findings": N },
           "security_agent": { "invoked": true/false, "findings": N },
           "critic_passes": N, "critic_fixes": N, "escalations": N }
       },
       "totals": { "changed_files": N, "auto_resolved": N, "escalations": N }
     }
     ```
   - Create `.claude/afc/memory/quality-history/` directory if it does not exist
6. **Checkpoint reset**:
   - Clear `.claude/afc/memory/checkpoint.md` **and** `~/.claude/projects/{ENCODED_PATH}/auto-memory/checkpoint.md` (pipeline complete = session goal achieved, dual-delete prevents stale checkpoint in either location; `ENCODED_PATH` = project path with `/` replaced by `-`)
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
9. **Checkpoint**: phase transition already recorded by `afc-pipeline-manage.sh phase clean` at phase start
10. Progress: `✓ 5/5 Clean complete (deleted: {N}, dead code: {N}, CI: ✓)`

### Final Output

```
Auto pipeline complete: {feature}
├─ 1/5 Spec: US {N}, FR {N}, researched {N}
├─ 2/5 Plan: Critic converged ({N} passes), ADR {N} recorded, Implementation Context {W} words
├─ 3/5 Implement: {completed}/{total} tasks ({P} parallel), CI ✓
│   ├─ TDD: {triggered/skipped}, Blast Radius: {triggered/skipped}
│   ├─ Acceptance Tests: {N} generated ({M} passing) / skipped
│   └─ Critic: converged ({N} passes, {M} fixes, {E} escalations)
├─ 4/5 Review: Critical:{N} Warning:{N} Info:{N}
│   ├─ Perspectives: Quality, Architecture*, Security*, Performance, Patterns, Reusability, Maintainability, Extensibility
│   └─ (* = delegated to persistent-memory agent)
├─ 5/5 Clean: {N} artifacts deleted, {N} dead code removed
├─ Changed files: {N}
├─ Auto-resolved: {N} ({M} validated in review)
├─ Agent memory: architect {updated/skipped}, security {updated/skipped}
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
Pipeline aborted (Phase {N}/5)
├─ Reason: {abort cause}
├─ Completed phases: {completed list}
├─ Rollback: git reset --hard afc/pre-auto (restores state before implementation)
├─ Checkpoint: .claude/afc/memory/checkpoint.md (last phase gate passed)
├─ Artifacts: .claude/afc/specs/{feature}/ (partial completion, manual deletion needed if Clean did not run)
└─ Resume: /afc:resume → /afc:implement (checkpoint-based)
```

## Notes

- **Full auto does not mean uncritical**: Phase 0.3 Request Triage may reject, reduce, or redirect requests before the pipeline invests resources. "Auto" automates execution, not judgment.
- **Full auto**: runs to completion without intermediate confirmation. Fast but direction cannot be changed mid-run.
- **Review auto-resolved items**: items tagged `[AUTO-RESOLVED]` are estimates; review after the fact is recommended.
- **Large feature warning**: warn before starting if more than 5 User Stories are expected.
- **Read existing code first**: always read existing files before modifying. Do not blindly generate code.
- **Follow project rules**: project rules in `afc.config.md` and `CLAUDE.md` take priority.
- **Critic Loop is not a ritual**: a single "PASS" line is equivalent to not running Critic at all. Always follow the format in the Critic Loop rules section. Critic uses convergence-based termination — it may finish in 1 pass or take several, depending on the output quality.
- **ESCALATE pauses auto mode**: when a Critic finds an ambiguous issue requiring user judgment, the pipeline pauses and presents options via AskUserQuestion. Auto mode automates clear decisions but escalates ambiguous ones.
- **Tasks phase is absorbed**: tasks.md is generated automatically at implement start from plan.md's File Change Map. No separate tasks phase or tasks critic loop. Validation is script-based (DAG + parallel overlap checks).
- **[P] parallel is mandatory**: if a [P] marker is assigned in tasks.md, it must be executed in parallel. Orchestration mode (batch vs swarm) is selected automatically based on task count. Sequential substitution is prohibited.
- **Swarm mode is automatic**: when a phase has 6+ [P] tasks, the orchestrator pre-assigns tasks to swarm workers. Do not manually batch.
- **Implementation Context travels with workers**: every sub-agent prompt includes the Implementation Context section from plan.md, ensuring spec intent propagates to parallel workers.
- **Session context resilience**: key decisions are written to `.claude/afc/specs/{feature}/context.md` at Plan completion and read at Implement start, surviving context compaction.
- **Specialist agents enhance review**: afc-architect and afc-security agents are invoked during Review to provide persistent-memory-aware analysis. Their findings are merged into the consolidated review. Agent memory updates happen automatically during the agent call.
- **Debug-based RCA replaces blind retry**: CI failures trigger `/afc:debug` logic (hypothesis → targeted fix) instead of generic "retry 3 times". This produces better fixes and records patterns via retrospective.
- **Acceptance tests close the spec-to-code gap**: When spec contains GWT scenarios and a test framework is configured, acceptance tests are auto-generated after implementation, verifying spec intent is met.
- **Research and ADR persist across sessions**: Research findings are saved to `.claude/afc/memory/research/`, ADRs to architect agent memory. Future pipelines can reference these to avoid re-research and detect conflicts.
- **No out-of-scope deletion**: do not delete files/directories in Clean that were not created by the current pipeline.
- **NEVER use `run_in_background: true` on Task calls**: agents must run in foreground so results are returned before the next step.
