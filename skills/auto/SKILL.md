---
name: afc:auto
description: "Full auto pipeline — use when the user asks to run the full afc pipeline automatically or automate the spec-to-clean cycle"
argument-hint: "[feature description in natural language]"
---

# /afc:auto — Full Auto Pipeline

> Runs clarify? → spec → plan → implement → review → clean fully automatically from a single feature description.
> Tasks are generated automatically at implement start (no separate tasks phase).
> Critic Loop runs at each phase with unified safety cap (5). Convergence terminates early when quality is sufficient.
> Pre-implementation gates (clarify, TDD pre-gen, blast-radius) run conditionally within the implement phase.
> **Skill Advisor**: 5 checkpoints (A–E) at phase boundaries dynamically invoke auxiliary skills (ideate, consult, architect, security, analyze, test, qa, learner) based on signal detection. Budget-controlled (max 5 per pipeline).

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

## Skill Advisor System

> Auxiliary skills (ideate, consult, architect, security, analyze, test, qa, learner) are dynamically invoked at phase boundaries based on **intent-based evaluation**. Each checkpoint uses LLM semantic judgment — not keyword counting — to determine whether auxiliary skills would add value.

### Core Principle: Intent-Based Evaluation

Each checkpoint contains a **structured evaluation prompt** that the orchestrator answers by reading the actual artifact content (not scanning for keywords). The evaluation produces a 1–5 score per signal. Score >= 3 triggers the corresponding skill.

**Why not keywords**: Keyword matching produces false positives (e.g., "token" in CSS vs auth context) and misses implicit intent (e.g., "user upload feature" implies security concerns without mentioning "XSS"). The orchestrator is an LLM — it should use semantic understanding.

### Execution Modes

| Mode | Description | Context cost | Example |
|------|-------------|-------------|---------|
| **Transform** | Skill output **replaces or restructures** the next phase's input | High (blocking) | ideate → $ARGUMENTS restructured |
| **Enrich** | Skill output **appends context** to the next phase's input | Low (fork/Task) | consult → domain constraints section added |
| **Observe** | Skill output is **metadata only** (logged, flags set) | Low (fork) | qa → quality score recorded |

### Budget Control

| Constraint | Limit | Rationale |
|-----------|-------|-----------|
| Per checkpoint | max 2 skills | Phase transition delay cap |
| Pipeline total | max 5 auxiliary invocations | Total execution time cap |
| Transform mode | max 1 per pipeline | Main context pollution prevention |
| Concurrent fork | max 3 per checkpoint | Agent resource limit |

Track auxiliary invocations in `ADVISOR_COUNT` (starts at 0, increments per invocation). If `ADVISOR_COUNT >= 5`, skip remaining checkpoints. Transform invocations tracked in `ADVISOR_TRANSFORM_USED` (boolean).

### Expert Agent Routing

When a checkpoint determines that domain expertise is needed, route to the appropriate expert agent:

| Domain | Agent | When to route |
|--------|-------|---------------|
| backend | afc-backend-expert | API design, database schema, server architecture, auth flows |
| infra | afc-infra-expert | Deployment, CI/CD, cloud infrastructure, containerization, scaling |
| pm | afc-pm-expert | Product decisions, user stories, prioritization, metrics |
| design | afc-design-expert | UI/UX, accessibility, component design, visual hierarchy |
| marketing | afc-marketing-expert | SEO, analytics, growth, conversion optimization |
| legal | afc-legal-expert | Privacy regulations, licensing, compliance, data protection |
| security | afc-appsec-expert | Application security, vulnerability patterns, secure coding |
| advisor | afc-tech-advisor | Technology selection, library comparison, stack decisions |

Route based on **what expertise the feature actually needs**, not keyword presence. Consider the project's `{config.architecture}` and tech stack — skip domains irrelevant to the project.

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
6. **Initialize Skill Advisor**: `ADVISOR_COUNT = 0`, `ADVISOR_TRANSFORM_USED = false`
7. Start notification:
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
   - On fail: **rollback fast-path changes** (`git reset --hard afc/pre-auto`), then restart with full pipeline: `⚠ Fast-path aborted — change is more complex than expected. Rolling back and running full pipeline.`
3. If change touches > 2 files OR modifies any `.sh` script: **rollback fast-path changes** (`git reset --hard afc/pre-auto`), then restart with full pipeline
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

### Skill Advisor Checkpoint A (Pre-Spec)

> Evaluate auxiliary skill triggers BEFORE entering Phase 1. Budget: max 2 skills, max 1 Transform. Skip all if `ADVISOR_COUNT >= 5`.

**Intent evaluation** — Read `$ARGUMENTS` and answer these questions semantically (not by keyword scanning):

| # | Question | Score 1–5 | If >= 3 | Skill | Mode |
|---|----------|-----------|---------|-------|------|
| A1 | Is this request at the **idea/vision level** rather than a concrete feature? (e.g., "make onboarding better" vs "add email verification to signup flow") Does it lack specific technical scope — no file paths, no API endpoints, no component names? | 1=concrete spec-ready, 5=pure vision | `ideate` | Transform |
| A2 | Does implementing this feature require **specialized domain knowledge** that a generalist developer wouldn't have? Consider: regulatory requirements, industry-specific patterns, domain-specific anti-patterns, compliance rules. Which domain from the Expert Agent Routing table would add the most value? | 1=general programming, 5=deep domain expertise essential | `consult({domain})` | Enrich (fork) |

**If A1 >= 3** (Transform — skip if `ADVISOR_TRANSFORM_USED`):
1. Execute `/afc:ideate` inline with `$ARGUMENTS`
2. Read generated `ideate.md` → extract "## Core Concept" + "## Success Criteria" sections
3. Construct enriched spec input:
   ```
   SPEC_INPUT = "$ARGUMENTS

   ## Ideation Context (auto-generated)
   {extracted Core Concept section}
   {extracted Success Criteria section}"
   ```
4. Replace `$ARGUMENTS` with `SPEC_INPUT` for Phase 1
5. Set `ADVISOR_TRANSFORM_USED = true`, increment `ADVISOR_COUNT`
6. Progress: `  ├─ Skill Advisor [A]: ideate (score: {N}/5, input restructured from idea to structured brief)`

**If A2 >= 3** (Enrich):
1. Determine which domain from Expert Agent Routing table best matches the **actual expertise gap** (not keyword presence)
2. Verify domain relevance: does this project's `{config.architecture}` and tech stack make this domain applicable? (e.g., skip `design` for a CLI tool, skip `infra` if the project has no deployment config)
3. Invoke expert agent:
   ```
   Task("Domain pre-consultation: {domain}", subagent_type: "afc:afc-{domain}-expert",
     prompt: "You are being consulted automatically during pipeline spec preparation.

     ## Feature Context
     {$ARGUMENTS}

     ## Why You Were Consulted
     {1-sentence explanation of what domain expertise gap was identified}

     ## Instructions
     1. Read your MEMORY.md for prior project context
     2. Read .claude/afc/project-profile.md if it exists
     3. Provide domain-specific constraints, regulations, and anti-patterns that MUST be reflected in the spec
     4. Format your response EXACTLY as:
        ## Domain Constraints ({domain})
        - [MUST] {constraint}: {rationale}
        - [MUST NOT] {anti-pattern}: {risk}
        - [CONSIDER] {best practice}: {benefit}
     5. Keep to max 10 items. Prioritize by risk severity.
     6. Update your MEMORY.md with the consultation context")
   ```
4. Store output as `DOMAIN_CONSTRAINTS` → injected into Phase 1 spec context
5. Spec phase MUST include a `## Domain Constraints` section reflecting these items
6. Increment `ADVISOR_COUNT`
7. Progress: `  ├─ Skill Advisor [A]: consult({domain}) (score: {N}/5, {M} constraints injected)`

**If all scores < 3**: proceed silently to Phase 1.

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
   - TESTABILITY: Does every System Requirement follow one of the 5 EARS patterns (WHEN/WHILE/IF/WHERE/SHALL)? Does each EARS requirement have a mapped TC (`→ TC: should_...`)? If not → FAIL and auto-fix: rewrite to EARS + generate TC mapping.
   - FAIL → auto-fix and continue. ESCALATE → pause, present options, resume after response. DEFER → record reason, mark clean.
7. **Checkpoint**: phase transition already recorded by `afc-pipeline-manage.sh phase spec` at phase start
8. Progress: `✓ 1/5 Spec complete (US: {N}, FR: {N}, researched: {N}, Critic: converged ({N} passes, {M} fixes, {E} escalations))`

### Skill Advisor Checkpoint B (Post-Spec)

> Evaluate auxiliary skill triggers AFTER spec completion, BEFORE plan creation. Budget: max 2 skills. Skip all if `ADVISOR_COUNT >= 5`.

**Intent evaluation** — Read the completed spec.md and answer these questions:

| # | Question | Score 1–5 | If >= 3 | Skill | Mode |
|---|----------|-----------|---------|-------|------|
| B1 | Does this feature **handle, store, or transmit sensitive data or trust boundaries**? Consider: user authentication/authorization, cryptographic operations, PII/financial data processing, external input that reaches internal systems, session/token lifecycle. Judge by the feature's actual behavior, not by whether security-related words appear. | 1=no trust boundary touched, 5=core security feature | `security` | Enrich (fork) |
| B2 | Does this feature **cross multiple architectural boundaries** or introduce a new structural pattern? Consider: does it touch 3+ layers (e.g., API + service + data + external), create a new component type not seen in the codebase, or require coordination between independently-deployable units? | 1=single-layer change, 5=cross-cutting architectural change | `architect` | Enrich (fork) |

**If B1 >= 3** (Enrich):
1. Invoke security agent for pre-plan threat modeling:
   ```
   Task("Threat Model: {feature}", subagent_type: "afc:afc-security",
     prompt: "Generate a threat model BEFORE implementation planning begins.

     ## Spec Summary
     {spec.md FR/NFR/Key Entities — security-relevant items only}

     ## Why This Was Triggered
     {1-sentence explanation of which trust boundary or sensitive data flow was identified}

     ## Instructions
     1. Read your MEMORY.md for known vulnerability patterns in this project
     2. Identify attack surfaces from the spec requirements
     3. For each threat, specify the mitigation that MUST appear in the plan
     4. Format your response EXACTLY as:
        ## Threat Model (pre-scan)
        | Threat | Attack Surface | Mitigation Required | Priority |
        |--------|---------------|-------------------|----------|
     5. Max 8 threats. Prioritize by exploitability and impact.
     6. Update your MEMORY.md with the threat model context")
   ```
2. Store output as `THREAT_MODEL` → injected into Phase 2 plan context
3. Plan phase MUST address each mitigation in its Risk & Mitigation section
4. Plan Critic RISK criterion MUST verify: `{M}/{N} threat mitigations addressed`
5. Increment `ADVISOR_COUNT`
6. Progress: `  ├─ Skill Advisor [B]: security (score: {N}/5, threat model: {M} threats identified)`

**If B2 >= 3** (Enrich):
1. Invoke architect agent for pre-plan guidance:
   ```
   Task("Architecture Advisory: {feature}", subagent_type: "afc:afc-architect",
     prompt: "Provide architecture guidance BEFORE plan creation.

     ## Spec Summary
     {spec.md Key Entities + layer analysis from {config.architecture}}

     ## Why This Was Triggered
     {1-sentence explanation of which architectural boundary crossing was identified}

     ## Instructions
     1. Read your MEMORY.md for prior ADRs and architecture patterns
     2. Recommend: component placement, layer boundaries, interface contracts
     3. Flag conflicts with existing architecture patterns
     4. Format your response EXACTLY as:
        ## Architecture Advisory (pre-plan)
        - [PLACE] {component} → {layer/module}: {rationale}
        - [BOUNDARY] {interface}: {contract description}
        - [CONFLICT] {existing} ↔ {new}: {resolution recommendation}
        - [PATTERN] {recommended pattern}: {why it fits}
     5. Max 10 items.
     6. Update your MEMORY.md if new patterns are identified")
   ```
2. Store output as `ARCH_ADVISORY` → injected into Phase 2 plan context
3. Plan Critic ARCHITECTURE criterion MUST validate against this advisory
4. Increment `ADVISOR_COUNT`
5. Progress: `  ├─ Skill Advisor [B]: architect (score: {N}/5, advisory: {M} recommendations, {K} conflicts)`

**If both B1 and B2 >= 3**: launch both agents in a **single message** (parallel fork). Both count toward budget.

**If all scores < 3**: proceed silently to Phase 2.

### Phase 2: Plan (2/5)

`"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase plan`

Execute `/afc:plan` logic inline:

1. Load spec.md
2. **Research (ReWOO pattern, if needed)**:
   Extract technical uncertainties from spec.md (libraries/APIs not yet used, unverified performance requirements, unclear integration approach). If no uncertain items: skip.
   If there are uncertain items, follow the 3-step ReWOO flow:
   - **Step 1 — Plan**: List all research topics as a numbered list (NO execution yet): `1. {topic} — {what we need to know}`
   - **Step 2 — Execute**: If topics are independent → launch parallel Task() calls in a **single message**: `Task("Research: {topic1}", subagent_type: "general-purpose")`. If a topic depends on another's result → execute sequentially. For 1-2 topics → resolve directly via WebSearch/codebase exploration (no delegation).
   - **Step 3 — Solve**: Collect all results and record in `.claude/afc/specs/{feature}/research.md` with: Decision, Rationale, Alternatives, Source per topic.
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
   ## Acceptance Criteria (from spec.md)
   {copy ALL FR-*, NFR-*, SC-* items and GWT acceptance scenarios from spec.md verbatim}
   ## Key Decisions
   - {what}: {rationale}
   ## Discoveries
   - {file path}: {finding}
   ```
   This file is read at Implement start to restore context after compaction. The full AC section ensures Review phase (Phase 4) can verify spec compliance even after spec.md is compacted.
9. **Checkpoint**: phase transition already recorded by `afc-pipeline-manage.sh phase plan` at phase start
10. Progress: `✓ 2/5 Plan complete (Critic: converged ({N} passes, {M} fixes, {E} escalations), files: {N}, ADR: {N} recorded, Implementation Context: {W} words)`

### Skill Advisor Checkpoint C (Post-Plan)

> Evaluate auxiliary skill triggers AFTER plan completion, BEFORE implementation. Budget: max 2 skills. Skip all if `ADVISOR_COUNT >= 5`.

**Intent evaluation** — Read the completed plan.md and answer these questions:

| # | Question | Score 1–5 | If >= 3 | Skill | Mode |
|---|----------|-----------|---------|-------|------|
| C1 | Is the **implementation risk high enough** that a dependency pre-analysis would catch problems the plan missed? Consider: are there files in the File Change Map that import each other (potential circular dependency)? Are there shared utility files that many other files depend on (high fan-out risk)? Are the declared `Depends On` relationships complete, or could there be hidden coupling? | 1=isolated changes, 5=deeply interconnected change set | `analyze` | Observe (fork) |
| C2 | Does the plan contain **unresolved domain uncertainties** — items tagged `[UNCERTAIN]`, open questions in Implementation Context, or design decisions that assume domain knowledge the team may not have? | 1=all decisions are well-grounded, 5=critical domain questions remain open | `consult({domain})` | Enrich (fork) |

**If C1 >= 3** (Observe):
1. Invoke analysis in fork context:
   ```
   Task("Complexity Analysis: {feature}", subagent_type: "general-purpose",
     prompt: "Analyze the dependency graph of files listed in the plan's File Change Map.

     ## File Change Map
     {paste File Change Map table from plan.md}

     ## Instructions
     1. For each file in the map, check its imports/dependencies in the codebase (Grep for import/require/source patterns)
     2. Identify:
        - Circular dependencies between planned files
        - High fan-out files (>5 dependents outside the change set)
        - Hidden coupling not captured in the Depends On column
        - Files that are imported by many other files (risk of breakage)
     3. Format your response EXACTLY as:
        ## Complexity Analysis
        - [CIRCULAR] {file A} ↔ {file B}: {description}
        - [FAN-OUT] {file} → {N} dependents: {list top 5}
        - [COUPLING] {file A} → {file B}: {not in Depends On column}
        - [HIGH-RISK] {file}: {reason — most impactful if broken}
        ## Risk Summary
        Circular: {N}, High fan-out: {N}, Hidden coupling: {N}
     4. If no issues found, return: '## Complexity Analysis\nNo significant risks detected.'")
   ```
2. Store output to `.claude/afc/specs/{feature}/complexity-analysis.md`
3. Implement phase reads this file → high-risk files get extra verification after modification
4. If circular dependencies found → **ESCALATE** to user (circular deps in implementation plan are a design flaw)
5. Increment `ADVISOR_COUNT`
6. Progress: `  ├─ Skill Advisor [C]: analyze (score: {N}/5, circular: {C}, fan-out: {F}, coupling: {H})`

**If C2 >= 3** (Enrich):
1. Determine which domain expert can best resolve the uncertainties (based on the nature of the open questions, not keywords)
2. Invoke expert agent:
   ```
   Task("Domain gap resolution: {domain}", subagent_type: "afc:afc-{domain}-expert",
     prompt: "Resolve domain uncertainties found during planning.

     ## Uncertain Items
     {extract all [UNCERTAIN] tagged items and open questions from plan.md}

     ## Plan Context
     {Implementation Context section from plan.md}

     ## Instructions
     1. For each uncertain item, provide a definitive answer with rationale
     2. Format your response EXACTLY as:
        ## Domain Resolutions
        - [RESOLVED] {item}: {answer} — {rationale}
        - [NEEDS-USER] {item}: {why this requires human judgment}
     3. Update your MEMORY.md with the resolution context")
   ```
3. Apply resolutions to plan.md Implementation Context (replace `[UNCERTAIN]` with `[RESOLVED: {answer}]`)
4. `[NEEDS-USER]` items → **ESCALATE** to user via AskUserQuestion
5. Increment `ADVISOR_COUNT`
6. Progress: `  ├─ Skill Advisor [C]: consult({domain}) (score: {N}/5, {M} resolved, {K} needs-user)`

**If all scores < 3**: proceed silently to Phase 3.

### Phase 3: Implement (3/5)

`"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase implement`

**Session context reload**: At implement start, read `.claude/afc/specs/{feature}/context.md` if it exists. This restores key decisions and constraints from Plan phase (resilient to context compaction).

Execute `/afc:implement` logic inline — **follow all orchestration rules defined in `skills/implement/SKILL.md`** (task generation, mode selection, batch/swarm execution, failure recovery, task execution pattern). The implement skill is the single source of truth for orchestration details.

**Auto-specific additions** (beyond implement.md):

#### Step 3.1: Task Generation + Validation

1. Generate tasks.md from plan.md File Change Map using the following format and principles:

   **Task Format** (required):
   ```markdown
   - [ ] T{NNN} {[P]} {[US*]} {description} `{file path}` {depends: [TXXX, TXXX]}
   ```
   | Component | Required | Description |
   |-----------|----------|-------------|
   | `T{NNN}` | Yes | 3-digit sequential ID (T001, T002, ...) |
   | `[P]` | No | **Mandatory parallel execution** — task MUST run in parallel with other [P] tasks in the same phase. Requires no file overlap. |
   | `[US*]` | No | User Story label from spec.md |
   | description | Yes | Clear task description (start with a verb) |
   | file path | Yes | Primary target file (wrapped in backticks) |
   | `depends:` | No | Explicit dependency list — task cannot start until all listed complete |

   **Decomposition Principles**:
   - **1 task = 1 file** principle (where possible)
   - **Same file = sequential**, **different files = [P] candidate**
   - **Explicit dependencies**: Use `depends: [T001, T002]` for blocking dependencies
   - **Test tasks**: Include a verification task for each testable unit
   - **Phase gate**: Add a `{config.gate}` validation task at the end of each Phase

   **Phase Structure**: Group tasks by Phase (Setup → Core → UI → Integration & Polish)

   **Coverage Mapping** (append after tasks):
   ```markdown
   ## Coverage Mapping
   | Requirement | Tasks |
   |-------------|-------|
   | FR-001 | T003, T007 |
   ```
   Every FR-*/NFR-* must be mapped to at least one task.

2. **Retrospective check**: if `.claude/afc/memory/retrospectives/` exists, load the **most recent 10 files** (sorted by filename descending) and check:
   - Were there previous parallel conflict issues ([P] file overlaps)? Flag similar file patterns.
   - Were there tasks that were over-decomposed or under-decomposed? Adjust granularity.
3. **Script validation**: Run DAG validation (`afc-dag-validate.sh`) and parallel overlap validation (`afc-parallel-validate.sh`) — no critic loop, script-based only. Fix any conflicts before proceeding.
4. Progress: `  ├─ Tasks generated: {N} ({P} parallelizable), Coverage: FR {M}%, NFR {K}%`

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

0. **Baseline test** (follows implement.md Step 1, item 5): if `{config.test}` is non-empty, run `{config.test}` before starting task execution. On failure, report pre-existing test failures to user and ask: "(1) Proceed anyway (2) Fix first (3) Abort". On pass or empty config, continue.
1. Execute tasks phase by phase using implement.md orchestration rules (sequential/batch/swarm based on [P] count)
2. **Implementation Context injection**: Every sub-agent prompt includes the `## Implementation Context` section from plan.md **and relevant FR/AC items from spec.md** (ensures spec intent propagates to workers)
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
- **SIDE_EFFECT_SAFETY**: For tasks that changed call order, error handling, or state flow: verify that callee behavior is compatible with the new usage. Read callee implementations when uncertain (do not rely on function names alone).
- **Adversarial 3-perspective** (mandatory each pass):
  - Skeptic: "Which implementation assumption is most likely wrong?"
  - Devil's Advocate: "How could this implementation be misused or fail unexpectedly?"
  - Edge-case Hunter: "What input would cause this implementation to fail silently?"
  - State one failure scenario per perspective. If realistic → FAIL + fix. If unrealistic → state quantitative rationale.
- FAIL → auto-fix, re-run `{config.ci}`, and continue. ESCALATE → pause, present options, resume after response. DEFER → record reason, mark clean.

6. **Implement retrospective**: if unexpected problems arose that weren't predicted in Plan, record in `.claude/afc/specs/{feature}/retrospective.md` (for memory update in Clean)
7. **Checkpoint**: phase transition already recorded by `afc-pipeline-manage.sh phase implement` at phase start
8. Progress: `✓ 3/5 Implement complete ({completed}/{total} tasks, CI: ✓, Critic: converged ({N} passes, {M} fixes, {E} escalations))`

### Skill Advisor Checkpoint D (Post-Implement)

> Evaluate auxiliary skill triggers AFTER implementation, BEFORE review. Budget: max 2 skills. Skip all if `ADVISOR_COUNT >= 5`.

**Intent evaluation** — Examine the implementation results and answer these questions:

| # | Question | Score 1–5 | If >= 3 | Skill | Mode |
|---|----------|-----------|---------|-------|------|
| D1 | Were **testable source files changed without corresponding test coverage**? Look at `git diff --name-only` — for each changed source file, does a test file covering its behavior also appear in the diff? Consider the project's test convention and whether the changed files contain logic that should be tested (skip config files, types-only files, static assets). Only evaluate if `{config.test}` is non-empty. | 1=all changes have test coverage, 5=critical logic changed with zero tests | `test` | Enrich |
| D2 | Based on **past pipeline quality data**, is there reason to believe this implementation has hidden quality issues? Check `.claude/afc/memory/quality-history/*.json` (if exists) — have recent pipelines shown elevated critical findings? Are there recurring problem categories that this feature's changed files might be susceptible to? | 1=clean history or no history, 5=strong pattern of recurring issues in similar areas | `qa` | Observe (fork) |

**If D1 >= 3** (Enrich):
1. Identify which changed source files lack test coverage — focus on files with meaningful logic (not config, not types, not assets):
   ```
   For each changed source file:
   - Does the project have a test file for it? (check test directory patterns)
   - Was that test file also modified in this diff?
   - Does the source file contain testable exports? (functions, classes, handlers)
   → List files that have testable logic but no test coverage in this diff
   ```
2. Invoke test generation (fork):
   ```
   Task("Coverage boost: {feature}", subagent_type: "general-purpose",
     prompt: "Generate missing tests for recently implemented files.

     ## Uncovered Files (testable logic, no test changes in this diff)
     {list of uncovered source files with their full paths}

     ## Instructions
     1. Read each uncovered file to understand its exports and behavior
     2. Read existing test files in the project for pattern reference
     3. Generate unit tests targeting:
        - Exported functions/classes
        - Edge cases and error paths
        - Integration points (if the file calls other changed files)
     4. Follow the project's test framework: {config.test framework}
     5. Place test files following project convention
     6. Run {config.test} to verify tests pass
     7. Return: files created, test count, pass/fail status")
   ```
3. New test files automatically enter review scope (Phase 4)
4. Increment `ADVISOR_COUNT`
5. Progress: `  ├─ Skill Advisor [D]: test (score: {N}/5, {M} uncovered files → {K} test files generated)`

**If D2 >= 3** (Observe):
1. Load `.claude/afc/memory/quality-history/*.json` (most recent 3 files, sorted by filename descending)
2. Identify recurring problem categories and which changed files are most at risk:
   ```
   Task("Pre-review QA: {feature}", subagent_type: "general-purpose",
     prompt: "Perform a pre-review quality audit focused on historically problematic areas.

     ## Changed Files
     {git diff --name-only}

     ## Quality History Context
     {summary of patterns from recent quality-history reports — categories, frequencies, affected file types}

     ## Instructions
     1. Focus on the recurring problem categories identified above
     2. Check: error handling completeness, input validation, resource cleanup
     3. Format your response EXACTLY as:
        ## Pre-Review QA Findings
        - [{severity}] {file}:{line} — {issue}: {suggested fix}
        ## Priority Hints for Review
        - {file}: focus on {area} (historically problematic)
     4. Read-only — do NOT modify any files")
   ```
3. Store output as `QA_FINDINGS` → injected into Phase 4 review context
4. Review phase uses "Priority Hints" to focus attention
5. Increment `ADVISOR_COUNT`
6. Progress: `  ├─ Skill Advisor [D]: qa (score: {N}/5, {M} priority hints for review)`

**If all scores < 3**: proceed silently to Phase 4.

### Phase 4: Review (4/5)

`"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase review`

Execute `/afc:review` logic inline — **follow all review perspectives defined in `skills/review/SKILL.md`** (A through H). The review skill is the single source of truth for review criteria.

**Context reload**: Re-read `.claude/afc/specs/{feature}/context.md` (contains full AC) and `.claude/afc/specs/{feature}/spec.md` to ensure spec context is available for SPEC_ALIGNMENT validation (these may have been compacted since Phase 1).

#### Step 4.1: Collect Review Targets

1. Collect changed files via `git diff HEAD`
2. Read **full content** of each changed file (not just the diff — full context needed for review)

#### Step 4.2: Reverse Impact Analysis

Before reviewing, identify **files affected by the changes** (not just the changed files themselves):

1. **For each changed file**, find files that depend on it:
   - **LSP (preferred)**: `LSP(findReferences)` on exported symbols — tracks type references, function calls, re-exports
   - **Grep (fallback)**: `Grep` for `import.*{filename}`, `require.*{filename}`, `source.*{filename}` patterns across the codebase
   - LSP and Grep are complementary — use both when LSP is available

2. **Build impact map**:
   ```
   Impact Map:
   ├─ src/auth/login.ts (changed)
   │  └─ affected: src/pages/LoginPage.tsx, src/middleware/auth.ts
   └─ Total: {N} changed files → {M} affected files
   ```

3. **Scope decision**: Affected files are NOT full review targets. Include them as **cross-reference context** in review and cross-boundary verification. If an affected file has >3 references to a changed symbol → flag for closer inspection.

4. **Limitations** (include in review output):
   > ⚠ Dynamic dependencies not covered: runtime dispatch, reflection, cross-language calls, config/env-driven branching.

#### Step 4.3: Scaled Review Orchestration

Choose review orchestration based on the number of changed files:

**Pre-scan: Call Chain Context** (for Parallel Batch and Review Swarm modes only):
Before distributing files to review agents, collect cross-boundary context:
1. For each changed file, identify **outbound calls** to other changed files (imports + function calls)
2. For each outbound call target, extract: function signature + 1-line side-effect summary
3. Include the **Impact Map** from Step 4.2 — each agent receives the list of affected files
4. Include this context in each review agent's prompt as `## Cross-File Context`

For Direct review mode (≤5 files): skip pre-scan — orchestrator already has full context.

**5 or fewer files**: Direct review — review all files directly in the current context (no delegation).

**6–10 files**: Parallel Batch — distribute to parallel review agents (2–3 files per agent) in a **single message**:
```
Task("Review: {file1, file2}", subagent_type: "general-purpose")
Task("Review: {file3, file4}", subagent_type: "general-purpose")
```

**11+ files**: Review Swarm — group files into batches (2-3 per worker), spawn N review workers in a **single message** (N = min(5, file count / 2)). Review is read-only — no write race conditions.

#### Step 4.4: Specialist Agent Delegation (parallel, perspectives B and C)

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

#### Step 4.5: Perform Review (8 perspectives)

Check across **8 perspectives** (A-H as defined in `skills/review/SKILL.md`):
- A. Code Quality — `{config.code_style}` compliance (direct review)
- B. Architecture — **delegated to afc-architect agent** (persistent memory, ADR-aware)
- C. Security — **delegated to afc-security agent** (persistent memory, false-positive-aware)
- D. Performance — framework-specific patterns from Project Context (direct review)
- E. Project Pattern Compliance — conventions and idioms (direct review)
- **F. Reusability** — DRY, shared utilities, abstraction level (direct review)
- **G. Maintainability** — AI/human comprehension, naming clarity, self-contained files (direct review)
- **H. Extensibility** — extension points, OCP, future modification cost (direct review)

#### Step 4.6: Cross-Boundary Verification (MANDATORY)

After individual/parallel reviews and specialist agents complete, the **orchestrator** MUST perform a cross-boundary check. This is a required step, not optional — skipping it is a review defect.

**For 11+ file reviews**: This is especially critical because individual review agents cannot see cross-file interactions. The orchestrator MUST read callee implementations directly.

0. **Impact Map integration**: Use the Impact Map from Step 4.2 to prioritize verification. Affected files with >3 references to changed symbols should be read and checked for breakage — even if no finding was raised against them.

1. **Filter**: From all collected findings, select those involving:
   - Call order changes (function A now calls B before C)
   - Error handling modifications (try/catch scope changes, error propagation changes)
   - State mutation changes (new writes to shared state, removed cleanup)

2. **Verify**: For each behavioral finding rated Critical or Warning:
   - **Read the callee's implementation** (the function/method being called) — this read is mandatory, not optional
   - **Skip external dependencies**: If the callee is in `node_modules/`, `vendor/`, or other third-party directories, verify against type definitions or documented API contract instead. Note: "verified against types/docs, not source"
   - Check: does the callee's internal behavior (side effects, state changes, return values) actually conflict with the change?
   - If no conflict → downgrade: Critical → Info, Warning → Info (append "verified: no cross-boundary impact")
   - If confirmed conflict → keep severity, enrich description with callee behavior details

3. **False positive reference** (security-related findings only): Check `afc-security` agent's MEMORY.md `## False Positives` section if it exists. Known false positive patterns should be noted in findings.

4. **Output**: Append verification summary before Review Output:
   ```
   Cross-Boundary Check: {N} behavioral findings verified
   ├─ Confirmed: {M} (severity kept)
   ├─ Downgraded: {K} (false positive — callee compatible)
   └─ Skipped: {J} (no behavioral change)
   ```

This step runs in the orchestrator context (not delegated), as it requires reading code across file boundaries.

#### Step 4.7: Auto-specific Validations

1. **Auto-resolved validation**: Check all `[AUTO-RESOLVED]` items from spec phase — does the implementation match the guess? Flag mismatches as Critical.
2. **Past reviews check**: if `.claude/afc/memory/reviews/` exists, load the **most recent 15 files** (sorted by filename descending) and scan for recurring finding patterns across past review reports. Prioritize those areas.
3. **Retrospective check**: if `.claude/afc/memory/retrospectives/` exists, load the **most recent 10 files** (sorted by filename descending) and check:
   - Were there recurring Critical finding categories in past reviews? Prioritize those perspectives.
   - Were there false positives that wasted effort? Reduce sensitivity for those patterns.

#### Step 4.8: Critic Loop

> **Always** read `${CLAUDE_PLUGIN_ROOT}/docs/critic-loop-rules.md` first and follow it.

**Critic Loop until convergence** (safety cap: 5, follow Critic Loop rules):
- COMPLETENESS: were all changed files reviewed across all 8 perspectives (A-H)?
- SPEC_ALIGNMENT: cross-check implementation against spec.md — (1) every SC verified with `{M}/{N}` count, (2) every acceptance scenario (GWT) has corresponding code path, (3) no spec constraint is violated
- SIDE_EFFECT_AWARENESS: For findings involving call order changes, error handling modifications, or state mutation changes: did the reviewer verify the callee's internal behavior? If a Critical finding assumes a side effect without reading the target implementation → auto-downgrade to Info with note "cross-boundary unverified". Provide "{M} of {N} behavioral findings verified" count.
- PRECISION: are there unnecessary changes? Are there out-of-scope modifications? Are findings actual issues, not false positives?
- FAIL → auto-fix and continue. ESCALATE → pause, present options, resume after response. DEFER → record reason, mark clean.

#### Step 4.9: Handling SC shortfalls

- Fixable → attempt auto-fix → re-run `{config.ci}` verification
- Not fixable → state in final report with reason (no post-hoc rationalization; record as Plan-phase target-setting error)

#### Step 4.10: Retrospective Entry (if new pattern found)

If this review reveals a recurring pattern not previously documented in `.claude/afc/memory/retrospectives/`:

Append to `.claude/afc/memory/retrospectives/{YYYY-MM-DD}.md`:
```markdown
## Pattern: {category}
**What happened**: {concrete description}
**Root cause**: {why this keeps occurring}
**Prevention rule**: {actionable rule — usable in future plan/implement phases}
**Severity**: Critical | Warning
```

Only write if the pattern is new and actionable. Generic observations are prohibited.

#### Step 4.11: Archive Review Report

Persist the review results for memory:

1. Write full review output (Summary table + Impact Analysis + Detailed Findings + Positives + Cross-Boundary Check) to `.claude/afc/specs/{feature}/review-report.md`
2. Include metadata header:
   ```markdown
   # Review Report: {feature name}
   > Date: {YYYY-MM-DD}
   > Files reviewed: {count}
   > Findings: Critical {N} / Warning {N} / Info {N}
   ```
3. This file is copied to `.claude/afc/memory/reviews/{feature}-{date}.md` during Clean phase before .claude/afc/specs/ deletion.

#### Step 4.12: Checkpoint & Progress

- **Checkpoint**: phase transition already recorded by `afc-pipeline-manage.sh phase review` at phase start
- Progress: `✓ 4/5 Review complete (Critical:{N} Warning:{N} Info:{N}, Cross-boundary: {M} verified, SC shortfalls: {N})`

### Skill Advisor Checkpoint E (Post-Review)

> Evaluate auxiliary skill triggers AFTER review, BEFORE clean. Budget: max 1 skill. Skip all if `ADVISOR_COUNT >= 5`.

**Intent evaluation** — Examine review findings and retrospective history:

| # | Question | Score 1–5 | If >= 3 | Skill | Mode |
|---|----------|-----------|---------|-------|------|
| E1 | Are there **recurring problem patterns** across this and past pipelines that should be codified as project rules? Check `.claude/afc/memory/retrospectives/` — do the same types of issues (e.g., "missing error handling in hooks", "forgotten spec file updates") keep appearing? Also consider: did this pipeline's review reveal issues that match past retrospective patterns? | 1=no retrospective history or no patterns, 5=same issue type recurred 3+ times and is not yet a project rule | `learner` | Observe (fork) |

**If E1 >= 3** (Observe):
1. Read retrospective files and identify recurring pattern categories:
   - What types of issues keep recurring?
   - Are they already covered by existing rules in `.claude/rules/afc-learned.md`?
   - Would a project rule have prevented the recurrence?
2. Invoke learner:
   ```
   Task("Pattern promotion: {feature}", subagent_type: "general-purpose",
     prompt: "Review recurring patterns for potential promotion to project rules.

     ## Recurring Patterns
     {list each pattern with: category, occurrence count, concrete examples from retrospective entries}

     ## Current Review Findings
     {summary of this pipeline's review findings that match retrospective patterns}

     ## Current Rules
     {read .claude/rules/afc-learned.md if it exists, else 'No learned rules yet'}

     ## Instructions
     1. For each recurring pattern, evaluate:
        - Is it actionable? (specific enough to enforce)
        - Is it already covered by existing rules?
        - Would enforcing it have prevented the recurrence?
     2. For patterns worth promoting, write a rule in this format:
        ### {Category}
        - **Rule**: {concise, enforceable statement}
        - **Rationale**: {why — based on {N} occurrences across pipelines}
        - **Enforcement**: {how to check — linter, review criterion, or convention}
     3. Append new rules to .claude/rules/afc-learned.md (create if absent)
     4. Do NOT duplicate existing rules
     5. Return: {N} patterns evaluated, {M} promoted, {K} already covered")
   ```
3. Increment `ADVISOR_COUNT`
4. Progress: `  ├─ Skill Advisor [E]: learner (score: {N}/5, {M} patterns evaluated, {K} promoted to rules)`

**If score < 3**: proceed silently to Phase 5.

### Phase 5: Clean (5/5)

`"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" phase clean`

Artifact cleanup and codebase hygiene check after implementation and review:

1. **Artifact cleanup** (scope-limited):
   - **Delete only the `.claude/afc/specs/{feature}/` directory created by the current pipeline**
   - If other `.claude/afc/specs/` subdirectories exist, **do not delete them** (only inform the user of their existence)
   - Do not leave pipeline intermediate artifacts in the codebase
2. **Dead code scan** (prefer external tooling over LLM judgment):
   - Run `{config.gate}` / `{config.ci}` — most linters detect unused imports/variables automatically
   - If the project has dedicated dead code tools (e.g., `eslint --rule 'no-unused-vars'`, `ts-prune`, `knip`), use them first
   - Only fall back to LLM-based scan for detection that static tools cannot cover
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
       "totals": { "changed_files": N, "auto_resolved": N, "escalations": N, "totalPromptCount": N }
     }
     ```
   - Create `.claude/afc/memory/quality-history/` directory if it does not exist
6. **Checkpoint reset**:
   - Clear `.claude/afc/memory/checkpoint.md` **and** `~/.claude/projects/{ENCODED_PATH}/memory/checkpoint.md` (pipeline complete = session goal achieved, dual-delete prevents stale checkpoint in either location; `ENCODED_PATH` = project path with `/` replaced by `-`)
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
├─ Skill Advisor: {ADVISOR_COUNT} auxiliary skills invoked
│   {for each invoked: ├─ [{checkpoint}] {skill}: {summary}}
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
