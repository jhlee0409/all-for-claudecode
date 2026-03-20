---
name: afc:auto
description: "Full auto pipeline — use when the user asks to run the full afc pipeline automatically or automate the spec-to-clean cycle"
argument-hint: "[feature description in natural language]"
---

# /afc:auto — Full Auto Pipeline

> Runs clarify? → spec → plan → implement → review → clean fully automatically from a single feature description.
> Tasks are generated automatically at implement start (no separate tasks phase).
> Critic Loop runs at each phase (unified safety cap: 5). Convergence terminates early when quality is sufficient.
> Pre-implementation gates (clarify, TDD pre-gen, blast-radius) run conditionally.
> **Skill Advisor**: 5 checkpoints (A–E) at phase boundaries; max 5 auxiliary invocations per pipeline. See `skills/auto/skill-advisor.md` for details.

## Arguments

- `$ARGUMENTS` — (required) Feature description in natural language

## Project Config (auto-loaded)

!`cat .claude/afc.config.md 2>/dev/null || echo "[CONFIG NOT FOUND] .claude/afc.config.md not found. Create it with /afc:init."`

## Config Load

**Always** read `.claude/afc.config.md` first. Values referenced as `{config.*}`:
- `{config.ci}` — full CI command
- `{config.gate}` — phase gate command
- `{config.test}` — test command
- `{config.architecture}` — architecture rules
- `{config.code_style}` — code style rules

If config missing: ask user to run `/afc:init`. If declined → **abort**.

---

## Critic Loop Rules

> **Always** read `${CLAUDE_SKILL_DIR}/../../docs/critic-loop-rules.md` before running any Critic pass. Core: minimum 1 concern per criterion + mandatory Adversarial failure scenario each pass + quantitative evidence required. "PASS" as a single word is prohibited. On ESCALATE: pause and present options via AskUserQuestion even in auto mode.

---

## Execution Steps

### Phase 0: Preparation

1. If `$ARGUMENTS` is empty → print "Please enter a feature description." and **abort**
2. Check current branch → `BRANCH_NAME`. Determine feature name (2-3 keywords, kebab-case).
3. **Preflight Check**:
   ```bash
   "${CLAUDE_SKILL_DIR}/../../scripts/afc-preflight-check.sh"
   ```
   Exit 1 → **abort**. Warnings (exit 0) → print and continue.
4. **Activate Pipeline Flag**:
   ```bash
   "${CLAUDE_SKILL_DIR}/../../scripts/afc-pipeline-manage.sh" start {feature}
   ```
   Creates `afc/pre-auto` safety snapshot, activates Stop Gate Hook, starts change tracking.
5. Create `.claude/afc/specs/{feature}/` → **record as `PIPELINE_ARTIFACT_DIR`**
6. **Initialize Skill Advisor**: `ADVISOR_COUNT = 0`, `ADVISOR_TRANSFORM_USED = false`
   ```bash
   afc_state_write "advisorCount" "0"
   afc_state_write "advisorTransformUsed" "false"
   ```
7. Start notification:
   ```
   Auto pipeline started: {feature}
   ├─ Clarify? → 1/5 Spec → 2/5 Plan → 3/5 Implement → 4/5 Review → 5/5 Clean
   └─ Running fully automatically (tasks auto-generated, pre-implementation gates conditional)
   ```

### Phase 0.3: Request Triage

1. **Necessity**: Explore codebase for existing implementations. If feature substantially exists → ask: "(1) Enhance existing (2) Replace entirely (3) Abort". Abort → release pipeline flag and end.
2. **Scope**: If `$ARGUMENTS` implies 10+ files or multiple unrelated concerns → warn and ask: "(1) Proceed (2) Reduce scope (3) Abort".
3. **Proportionality**: If trivially small (single file, single-line, config edit) → suggest fast-path skip.

### Phase 0.8: Size-Based Fast-Path Detection (conditional)

**ALL 3 criteria must be met** to trigger fast-path:

| Criterion | Check |
|-----------|-------|
| Trivial scope | Explicitly mentions 1-2 specific files or a single-line fix |
| No script impact | Does not reference `.sh` scripts, hooks, or pipeline logic |
| Low ambiguity | Clarify gate score < 2 |

**If ALL 3 met** (fast-path):
1. Print: `⚡ Fast path detected — skipping spec/plan phases`
2. Implement the change directly (no tasks.md, no plan.md)
3. Run `{config.ci}` — on fail or if > 2 files modified: rollback (`git reset --hard afc/pre-auto`) and restart with full pipeline
4. ```bash
   "${CLAUDE_SKILL_DIR}/../../scripts/afc-pipeline-manage.sh" phase fast-path
   "${CLAUDE_SKILL_DIR}/../../scripts/afc-pipeline-manage.sh" ci-pass
   ```
5. Run mini-review (single Critic pass). Then run Phase 5 Clean logic.
6. Final output:
   ```
   Fast path complete: {feature}
   ├─ Mode: ⚡ Fast path (spec/plan skipped)
   ├─ Changed files: {N}
   ├─ CI: ✓
   └─ Review: mini-review passed
   ```

**If ANY criterion fails**: proceed to Phase 0.5 (full pipeline).

### Phase 0.5: Auto-Clarify Gate (conditional)

`"${CLAUDE_SKILL_DIR}/../../scripts/afc-pipeline-manage.sh" phase clarify`

Score `$ARGUMENTS` on 5 ambiguity signals (vague scope, missing quantifiers, undefined entities, unclear boundaries, multiple interpretations). If score >= 3: generate at most 3 questions via AskUserQuestion. Apply answers to refine `$ARGUMENTS`. In full-auto mode: auto-resolve with best-guess, tag `[AUTO-RESOLVED: clarify]`.

**If score < 3**: skip silently.

---

### Skill Advisor Checkpoint A (Pre-Spec)

> Evaluate BEFORE Phase 1. See `skills/auto/skill-advisor.md#checkpoint-a--pre-spec` for full evaluation prompts, invocation patterns, and state management. Budget: max 2 skills, max 1 Transform. Skip if `ADVISOR_COUNT >= 5`.

Signals: A1 (idea-level request → `ideate` Transform), A2 (domain expertise needed → `consult({domain})` Enrich).

---

### Phase 1: Spec (1/5)

`"${CLAUDE_SKILL_DIR}/../../scripts/afc-pipeline-manage.sh" phase spec`

Execute `/afc:spec` logic inline:

1. Explore codebase (Glob, Grep) by `{config.architecture}` layer
2. **Research Gate** (conditional): scan `$ARGUMENTS` for external library/API references not in codebase. If found: WebSearch (or Context7) for latest stable version, key constraints. Tag researched items `[RESEARCHED]`. Skip if all internal.
3. Create `.claude/afc/specs/{feature}/spec.md`
4. `[NEEDS CLARIFICATION]` items: research first, then auto-resolve remaining as `[AUTO-RESOLVED]`
5. **Retrospective check**: load most recent 10 `.claude/afc/memory/retrospectives/` files (if exist) — flag `[AUTO-RESOLVED]` patterns that previously went wrong
6. **Critic Loop until convergence** (safety cap: 5, follow `docs/critic-loop-rules.md`):
   - COMPLETENESS: every User Story has acceptance scenarios?
   - MEASURABILITY: criteria measurable, quantitative evidence for numerical targets?
   - INDEPENDENCE: no implementation details (code, library names) in spec?
   - EDGE_CASES: at least 2 identified?
   - TESTABILITY: every System Requirement follows EARS pattern? Each has mapped TC (`→ TC: should_...`)?
   - FAIL → auto-fix and continue. ESCALATE → pause. DEFER → record and mark clean.
7. Progress: `✓ 1/5 Spec complete (US: {N}, FR: {N}, researched: {N}, Critic: converged ({N} passes, {M} fixes, {E} escalations))`

---

### Skill Advisor Checkpoint B (Post-Spec)

> Evaluate AFTER Phase 1, BEFORE Phase 2. See `skills/auto/skill-advisor.md#checkpoint-b--post-spec` for full invocation patterns. Budget: max 2 skills. Skip if `ADVISOR_COUNT >= 5`.

Signals: B1 (sensitive data/trust boundary → `security` Enrich), B2 (cross-architectural boundary → `architect` Enrich). If both >= 3: launch parallel. Security/architecture conflicts → **ESCALATE**.

---

### Phase 2: Plan (2/5)

`"${CLAUDE_SKILL_DIR}/../../scripts/afc-pipeline-manage.sh" phase plan`

Execute `/afc:plan` logic inline:

1. Load spec.md
2. **Research (ReWOO pattern, if needed)**: extract technical uncertainties. Plan → Execute parallel Tasks → Solve. Record to `.claude/afc/specs/{feature}/research.md`. 1-2 topics → resolve directly.
3. **Memory loading** (skip if absent):
   - Quality history: most recent 10 files from `.claude/afc/memory/quality-history/` — trend summary
   - Decisions: most recent 30 from `.claude/afc/memory/decisions/` — conflict check
   - Reviews: most recent 15 from `.claude/afc/memory/reviews/` — recurring finding patterns
4. Create `.claude/afc/specs/{feature}/plan.md`. Include structure-analysis-based estimates for numerical targets.
5. **Critic Loop until convergence** (safety cap: 5, follow `docs/critic-loop-rules.md`):
   - COMPLETENESS, FEASIBILITY, ARCHITECTURE, CROSS_CONSISTENCY, RISK, PRINCIPLES
   - **CROSS_CONSISTENCY** (check all 5): entity coverage, NFR traceability, terminology consistency, constraint propagation, acceptance anchor alignment
   - **RISK**: enumerate at least 3 `{config.ci}` failure scenarios; check each risk pattern from Project Context
   - **ARCHITECTURE**: describe import paths for moved/created files, pre-validate against `{config.architecture}` rules
   - Each pass must explicitly note what was missed in the previous pass
6. Persist research to `.claude/afc/memory/research/{feature}.md`
7. **ADR recording**: invoke `afc-architect` agent to record architectural decisions. If conflicts found → **ESCALATE**
8. **Session context** — write `.claude/afc/specs/{feature}/context.md`:
   ```markdown
   # Session Context: {feature}
   ## Goal
   - Original request: $ARGUMENTS
   - Current objective: Implement {feature}
   ## Acceptance Criteria (from spec.md)
   {copy ALL FR-*, NFR-*, SC-* items and GWT acceptance scenarios verbatim}
   ## Key Decisions
   - {what}: {rationale}
   ## Discoveries
   - {file path}: {finding}
   ```
9. Progress: `✓ 2/5 Plan complete (Critic: converged ({N} passes, {M} fixes, {E} escalations), files: {N}, ADR: {N} recorded, Implementation Context: {W} words)`

---

### Skill Advisor Checkpoint C (Post-Plan)

> Evaluate AFTER Phase 2, BEFORE Phase 3. See `skills/auto/skill-advisor.md#checkpoint-c--post-plan` for full invocation patterns. Budget: max 2 skills. Skip if `ADVISOR_COUNT >= 5`.

Signals: C1 (high interconnection risk → dependency analysis Observe), C2 (unresolved domain uncertainties → `consult({domain})` Enrich).

---

### Phase 3: Implement (3/5)

`"${CLAUDE_SKILL_DIR}/../../scripts/afc-pipeline-manage.sh" phase implement`

**Session context reload**: read `.claude/afc/specs/{feature}/context.md`. If `complexity-analysis.md` exists, read it and flag high-risk files for extra verification.

Follow all orchestration rules in `skills/implement/SKILL.md` (mode selection, batch/swarm, failure recovery).

#### Step 3.1: Task Generation + Validation

Generate `tasks.md` from plan.md File Change Map. Required format:
```
- [ ] T{NNN} {[P]} {[US*]} {description} `{file path}` {depends: [TXXX]}
```
Principles: 1 task = 1 file, same file = sequential, different files = [P] candidate. Append Coverage Mapping (every FR-*/NFR-* mapped to at least one task).

Check retrospective for past [P] conflict patterns. Run DAG and parallel overlap validation scripts — no critic loop, script-based only. Fix conflicts before proceeding.

Progress: `  ├─ Tasks generated: {N} ({P} parallelizable), Coverage: FR {M}%, NFR {K}%`

#### Step 3.2: TDD Pre-Generation (conditional)

**Trigger**: tasks.md contains at least 1 task targeting a `.sh` file in `scripts/`.

```bash
"${CLAUDE_SKILL_DIR}/../../scripts/afc-test-pre-gen.sh" ".claude/afc/specs/{feature}/tasks.md" "spec/"
```
Verify skeletons are parseable: `{config.test}` should show Pending examples. Create `tests-pre.md` listing expectations per task. Progress: `  ├─ TDD pre-gen: {N} skeletons generated`

#### Step 3.3: Blast Radius Analysis (conditional)

**Trigger**: plan.md File Change Map lists >= 3 files.

```bash
"${CLAUDE_SKILL_DIR}/../../scripts/afc-blast-radius.sh" ".claude/afc/specs/{feature}/plan.md" "${CLAUDE_PROJECT_DIR}"
```
Exit 1 (cycle) → **ESCALATE**. High fan-out (>5 dependents) → warning + RISK note. Save to `impact.md`. Progress: `  ├─ Blast radius: {N} planned, {M} dependents`

#### Step 3.4: Execution

1. **Baseline test**: run `{config.test}` before task execution. Failure → ask user to proceed/fix/abort.
2. Execute tasks phase by phase per implement.md orchestration rules (sequential/batch/swarm based on [P] count)
3. **Implementation Context injection**: every sub-agent prompt includes plan.md `## Implementation Context` **and** relevant FR/AC from spec.md
4. **Phase gates**: always read `${CLAUDE_SKILL_DIR}/../../docs/phase-gate-protocol.md` first. On gate pass: `"${CLAUDE_SKILL_DIR}/../../scripts/afc-pipeline-manage.sh" phase-tag {phase_number}`
5. Real-time `[x]` updates in tasks.md
6. After full completion, run `{config.ci}`:
   - Pass: `"${CLAUDE_SKILL_DIR}/../../scripts/afc-pipeline-manage.sh" ci-pass`
   - Fail: run `/afc:debug` logic inline (RCA → hypothesis → targeted fix → re-run). If debug-fix fails 3× → **abort**

#### Step 3.5: Acceptance Test Generation (conditional)

**Trigger**: spec.md has GWT acceptance scenarios AND `{config.test}` is non-empty.

Map GWT → test cases (Given=Arrange, When=Act, Then=Assert). Run `{config.test}`. Failures reveal spec-implementation gaps — apply targeted fix or record as SC shortfall for Phase 4.

Progress: `  ├─ Acceptance tests: {N} generated, {M} passing`

#### Step 3.6: Implement Critic Loop

**Critic Loop until convergence** (safety cap: 5, follow `docs/critic-loop-rules.md`):
- SCOPE_ADHERENCE: `git diff` changed files vs plan.md File Change Map. "M of N files match" count required.
- ARCHITECTURE: changed files vs `{config.architecture}` rules. "N of M rules checked" count required.
- CORRECTNESS: cross-check against spec.md AC. "N of M AC verified" count required.
- SIDE_EFFECT_SAFETY: for call order/error handling/state flow changes — verify callee behavior compatibility by reading callee implementation directly.
- **Adversarial 3-perspective** (mandatory each pass): Skeptic / Devil's Advocate / Edge-case Hunter — one failure scenario each. If realistic → FAIL + fix. If not → quantitative rationale required.
- FAIL → auto-fix + re-run `{config.ci}`. ESCALATE → pause. DEFER → record and mark clean.

7. If unexpected problems arose not predicted in Plan: record in `.claude/afc/specs/{feature}/retrospective.md`
8. Progress: `✓ 3/5 Implement complete ({completed}/{total} tasks, CI: ✓, Critic: converged ({N} passes, {M} fixes, {E} escalations))`

---

### Skill Advisor Checkpoint D (Post-Implement)

> Evaluate AFTER Phase 3, BEFORE Phase 4. See `skills/auto/skill-advisor.md#checkpoint-d--post-implement` for full invocation patterns. Budget: max 2 skills. Skip if `ADVISOR_COUNT >= 5`.

Signals: D1 (testable files changed without test coverage → test generation Enrich), D2 (historical quality issues → pre-review QA Observe).

---

### Phase 4: Review (4/5)

`"${CLAUDE_SKILL_DIR}/../../scripts/afc-pipeline-manage.sh" phase review`

Follow all review perspectives in `skills/review/SKILL.md` (A through H). **Context reload**: re-read `context.md` and `spec.md` before starting.

#### Step 4.1–4.2: Collect Targets + Reverse Impact Analysis

Collect changed files via `git diff HEAD` — read **full content** of each (not just diff). For each changed file, find dependents via LSP(findReferences) or Grep fallback. Build Impact Map. Affected files are cross-reference context, not full review targets.

#### Step 4.3: Scaled Review Orchestration

**For Parallel Batch and Review Swarm only** — pre-scan: collect outbound call chain context and include Impact Map in each agent's `## Cross-File Context`.

| File count | Mode |
|------------|------|
| ≤5 | Direct review — no delegation |
| 6–10 | Parallel Batch — 2–3 files per agent, single message |
| 11+ | Review Swarm — N workers = min(5, file count / 2), single message |

#### Step 4.4: Specialist Agent Delegation (parallel, perspectives B and C)

Launch in a **single message**:
- `afc:afc-architect` — architecture compliance vs rules and ADRs, update MEMORY.md
- `afc:afc-security` — vulnerability scan with false-positive awareness, update MEMORY.md

#### Step 4.5: Perform Review (8 perspectives)

A. Code Quality (`{config.code_style}`, direct), B. Architecture (delegated), C. Security (delegated), D. Performance (direct), E. Pattern Compliance (direct), F. Reusability (direct), G. Maintainability (direct), H. Extensibility (direct).

#### Step 4.6: Cross-Boundary Verification (MANDATORY)

After all reviews complete, orchestrator MUST verify behavioral findings. **Not optional — skipping is a review defect.**

1. Filter findings involving: call order changes, error handling modifications, state mutation changes
2. For each Critical or Warning behavioral finding: **read the callee implementation** (skip if in `node_modules/`/`vendor/` — verify against types/docs instead)
3. No conflict → downgrade to Info ("verified: no cross-boundary impact"). Confirmed conflict → keep severity with callee behavior details.
4. Output cross-boundary check summary before Review Output.

#### Step 4.7: Inject Advisor Context

If Checkpoint D produced `QA_FINDINGS` → include as Priority Hints. New test files (from D1) → include in review scope.

#### Step 4.8: Auto-specific Validations

1. Check all `[AUTO-RESOLVED]` items — does implementation match the guess? Mismatches → Critical.
2. Load most recent 15 `.claude/afc/memory/reviews/` files — scan for recurring finding patterns.
3. Load most recent 10 `.claude/afc/memory/retrospectives/` files — apply prevention rules.

#### Step 4.9: Review Critic Loop

**Critic Loop until convergence** (safety cap: 5, follow `docs/critic-loop-rules.md`):
- COMPLETENESS: all changed files reviewed across A-H?
- SPEC_ALIGNMENT: every SC verified `{M}/{N}`, every GWT has code path, no spec constraint violated?
- SIDE_EFFECT_AWARENESS: behavioral findings cross-boundary verified? `{M} of {N} verified` count required.
- PRECISION: unnecessary changes? out-of-scope modifications? false positives?

#### Step 4.10–4.12: SC Shortfalls, Retrospective, Archive

- **SC shortfalls**: fixable → auto-fix + re-run CI. Not fixable → state in report as Plan-phase error.
- **Retrospective**: if new recurring pattern found, append to `.claude/afc/memory/retrospectives/{YYYY-MM-DD}.md` (concrete + root cause + prevention rule + severity).
- **Archive**: write full review to `review-report.md` (copied to `.claude/afc/memory/reviews/{feature}-{date}.md` in Clean).
- Progress: `✓ 4/5 Review complete (Critical:{N} Warning:{N} Info:{N}, Cross-boundary: {M} verified, SC shortfalls: {N})`

---

### Skill Advisor Checkpoint E (Post-Review)

> Evaluate AFTER Phase 4, BEFORE Phase 5. See `skills/auto/skill-advisor.md#checkpoint-e--post-review` for full invocation patterns. Budget: max 1 skill. Skip if `ADVISOR_COUNT >= 5`.

Signal: E1 (recurring problem patterns → learner Observe).

---

### Phase 5: Clean (5/5)

`"${CLAUDE_SKILL_DIR}/../../scripts/afc-pipeline-manage.sh" phase clean`

1. **Artifact cleanup**: delete only `.claude/afc/specs/{feature}/` (current pipeline). Do not delete other subdirectories.
2. **Dead code scan**: run `{config.gate}` / `{config.ci}` first (linters detect unused imports/variables). Use dedicated tools (`ts-prune`, `knip`) before LLM-based scan. Remove empty directories.
3. **Final CI gate**: run `{config.ci}`. Auto-fix on failure (max 2 attempts).
4. **Memory update**:
   - Reusable patterns → `.claude/afc/memory/`
   - `[AUTO-RESOLVED]` items → `.claude/afc/memory/decisions/`
   - `retrospective.md` → `.claude/afc/memory/retrospectives/`
   - `review-report.md` → `.claude/afc/memory/reviews/{feature}-{date}.md`
   - `research.md` (if not already persisted) → `.claude/afc/memory/research/{feature}.md`
   - **Agent memory consolidation**: if architect/security MEMORY.md has redundant entries, invoke agent for self-pruning
   - **Memory rotation**: prune oldest files when directories grow large (soft guidelines: quality-history ~30, reviews ~40, retrospectives ~30, research ~50, decisions ~60). Use relevance judgment, not hard cutoffs.
5. **Quality report**: write `.claude/afc/memory/quality-history/{feature}-{date}.json` with full phase metrics (clarify, spec, plan, implement, review, totals).
6. **Checkpoint reset**: clear `.claude/afc/memory/checkpoint.md` AND `~/.claude/projects/{ENCODED_PATH}/memory/checkpoint.md`
7. **Timeline finalize + release pipeline flag**:
   ```bash
   "${CLAUDE_SKILL_DIR}/../../scripts/afc-pipeline-manage.sh" log pipeline-end "Pipeline complete: {feature}"
   "${CLAUDE_SKILL_DIR}/../../scripts/afc-pipeline-manage.sh" end
   ```
8. Progress: `✓ 5/5 Clean complete (deleted: {N}, dead code: {N}, CI: ✓)`

---

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
├─ Skill Advisor: {ADVISOR_COUNT} auxiliary skills invoked
│   {for each invoked: ├─ [{checkpoint}] {skill}: {summary}}
├─ Changed files: {N}
├─ Auto-resolved: {N} ({M} validated in review)
├─ Agent memory: architect {updated/skipped}, security {updated/skipped}
├─ Retrospective: {present/absent}
└─ .claude/afc/specs/{feature}/ cleaned up
```

---

## Abort Conditions

Abort and report to user when:
1. `{config.ci}` fails 3 consecutive times
2. File conflict during implementation (overlaps from another branch)
3. Critical security issue found (cannot auto-fix)

On abort:
```
Pipeline aborted (Phase {N}/5)
├─ Reason: {abort cause}
├─ Completed phases: {completed list}
├─ Rollback: git reset --hard afc/pre-auto
├─ Checkpoint: .claude/afc/memory/checkpoint.md (last phase gate passed)
├─ Artifacts: .claude/afc/specs/{feature}/ (partial — manual deletion needed if Clean did not run)
└─ Resume: /afc:resume → /afc:implement (checkpoint-based)
```

---

## Notes

- **Full auto does not mean uncritical**: Phase 0.3 Request Triage may reject/reduce/redirect before investing resources.
- **[AUTO-RESOLVED] items**: estimates only — review after the fact is recommended.
- **Large feature warning**: warn before starting if 5+ User Stories are expected.
- **Read existing code first**: always read existing files before modifying.
- **[P] parallel is mandatory**: if a `[P]` marker is assigned in tasks.md, it must execute in parallel. Sequential substitution is prohibited.
- **Implementation Context travels with workers**: every sub-agent prompt includes plan.md `## Implementation Context`.
- **Session context resilience**: `context.md` is written at Plan completion and read at Implement start (survives context compaction).
- **Debug-based RCA replaces blind retry**: CI failures trigger `/afc:debug` logic.
- **NEVER use `run_in_background: true` on Task calls**: agents must run in foreground so results are returned before the next step.
- **Orchestration mode details**: see `docs/orchestration-modes.md` for sequential/batch/swarm specifics.
