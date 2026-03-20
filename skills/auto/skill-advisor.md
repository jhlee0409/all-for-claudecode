# Skill Advisor — Reference

> Invoked by `/afc:auto` at 5 phase-boundary checkpoints. Each checkpoint uses LLM semantic evaluation (not keyword matching) to determine whether auxiliary skills add value. Budget-controlled: max 5 auxiliary invocations per pipeline.

## Execution Modes

| Mode | Description | Context cost |
|------|-------------|-------------|
| **Transform** | Skill output replaces/restructures the next phase's input | High (blocking) |
| **Enrich** | Skill output appends context to the next phase's input | Low (fork/Task) |
| **Observe** | Skill output is metadata only (logged, flags set) | Low (fork) |

## Budget Control

| Constraint | Limit | Rationale |
|-----------|-------|-----------|
| Per checkpoint | max 2 skills | Phase transition delay cap |
| Pipeline total | max 5 auxiliary invocations | Total execution time cap |
| Transform mode | max 1 per pipeline | Main context pollution prevention |
| Concurrent fork | max 3 per checkpoint | Agent resource limit |

Track in `ADVISOR_COUNT` (starts 0) and `ADVISOR_TRANSFORM_USED` (boolean). Persist every increment:
```bash
afc_state_write "advisorCount" "$ADVISOR_COUNT"
afc_state_write "advisorTransformUsed" "true"  # when Transform is used
```
On context recovery: `ADVISOR_COUNT = afc_state_read "advisorCount"`.

## Expert Agent Routing

Route based on what expertise the feature actually needs (not keyword presence). Verify domain relevance against `{config.architecture}` — skip inapplicable domains (e.g., `design` for CLI, `infra` for no-deployment project).

| Domain | Agent ID (subagent_type value) | When to route |
|--------|-------------------------------|---------------|
| backend | `afc-backend-expert` | API design, database schema, server architecture, auth flows |
| infra | `afc-infra-expert` | Deployment, CI/CD, cloud infrastructure, containerization |
| pm | `afc-pm-expert` | Product decisions, user stories, prioritization, metrics |
| design | `afc-design-expert` | UI/UX, accessibility, component design, visual hierarchy |
| marketing | `afc-marketing-expert` | SEO, analytics, growth, conversion optimization |
| legal | `afc-legal-expert` | Privacy regulations, licensing, compliance, data protection |
| security | `afc-appsec-expert` | Application security, vulnerability patterns, secure coding |
| advisor | `afc-tech-advisor` | Technology selection, library comparison, stack decisions |

**Important**: Use the Agent ID column as the `subagent_type` value directly (e.g., `subagent_type: "afc:afc-backend-expert"`). `security` → `afc-appsec-expert` (NOT `afc-security-expert`).

---

## Checkpoint A — Pre-Spec

> Fire BEFORE Phase 1 (Spec). Skip if `ADVISOR_COUNT >= 5`. Budget: max 2 skills, max 1 Transform.

| # | Question | Score 1–5 | If >= 3 | Skill | Mode |
|---|----------|-----------|---------|-------|------|
| A1 | Is this request at the **idea/vision level** rather than a concrete feature? (lacks specific file paths, API endpoints, component names) | 1=concrete spec-ready, 5=pure vision | `ideate` | Transform |
| A2 | Does implementing this feature require **specialized domain knowledge** that a generalist developer wouldn't have? (regulatory, industry-specific patterns, compliance) | 1=general programming, 5=deep domain expertise essential | `consult({domain})` | Enrich (fork) |

**If A1 >= 3** (Transform — skip if `ADVISOR_TRANSFORM_USED`):
1. Execute `/afc:ideate` inline with `$ARGUMENTS`
2. On failure: do NOT set `ADVISOR_TRANSFORM_USED`, proceed with original `$ARGUMENTS`, log: `"Skill Advisor [A]: ideate failed, proceeding with original input"`
3. On success: extract `## Problem Statement` + `## Value Proposition` + `## Core Features (MoSCoW)` (Must Have only) from `ideate.md`
4. Construct enriched spec input:
   ```
   SPEC_INPUT = "$ARGUMENTS

   ## Ideation Context (auto-generated)
   {extracted Problem Statement}
   {extracted Value Proposition}
   {extracted Core Features — Must Have only}"
   ```
5. Replace `$ARGUMENTS` with `SPEC_INPUT` for Phase 1. Set `ADVISOR_TRANSFORM_USED = true`, increment `ADVISOR_COUNT`, persist both to state.
6. Progress: `  ├─ Skill Advisor [A]: ideate (score: {N}/5, input restructured from idea to structured brief)`

**If A2 >= 3** (Enrich):
1. Determine which domain best matches the actual expertise gap (not keywords). Verify relevance against project tech stack.
2. Invoke expert agent:
   ```
   Task("Domain pre-consultation: {domain}", subagent_type: "afc:{agent-id}",
     prompt: "You are being consulted automatically during pipeline spec preparation.
     ## Feature Context
     {$ARGUMENTS}
     ## Why You Were Consulted
     {1-sentence explanation of expertise gap}
     ## Instructions
     1. Read your MEMORY.md for prior project context
     2. Read .claude/afc/project-profile.md if it exists
     3. Provide domain-specific constraints and anti-patterns that MUST be reflected in the spec
     4. Format EXACTLY as:
        ## Domain Constraints ({domain})
        - [MUST] {constraint}: {rationale}
        - [MUST NOT] {anti-pattern}: {risk}
        - [CONSIDER] {best practice}: {benefit}
     5. Max 10 items, prioritized by risk severity.
     6. Update your MEMORY.md with the consultation context")
   ```
3. Store as `DOMAIN_CONSTRAINTS` → inject into Phase 1. Spec MUST include `## Domain Constraints` section.
4. Increment `ADVISOR_COUNT`. Progress: `  ├─ Skill Advisor [A]: consult({domain}) (score: {N}/5, {M} constraints injected)`

---

## Checkpoint B — Post-Spec

> Fire AFTER Phase 1, BEFORE Phase 2 (Plan). Skip if `ADVISOR_COUNT >= 5`. Budget: max 2 skills.

| # | Question | Score 1–5 | If >= 3 | Skill | Mode |
|---|----------|-----------|---------|-------|------|
| B1 | Does this feature **handle, store, or transmit sensitive data or trust boundaries**? (auth/authz, PII, financial data, external input reaching internal systems, session/token lifecycle) | 1=no trust boundary touched, 5=core security feature | `security` | Enrich (fork) |
| B2 | Does this feature **cross multiple architectural boundaries** or introduce a new structural pattern? (3+ layers, new component type, coordination across independently-deployable units) | 1=single-layer change, 5=cross-cutting architectural change | `architect` | Enrich (fork) |

**If B1 >= 3** (Enrich):
1. Invoke security agent for pre-plan threat modeling:
   ```
   Task("Threat Model: {feature}", subagent_type: "afc:afc-security",
     prompt: "Generate a threat model BEFORE implementation planning begins.
     ## Spec Summary
     {spec.md FR/NFR/Key Entities — security-relevant items only}
     ## Why This Was Triggered
     {1-sentence explanation}
     ## Instructions
     1. Read your MEMORY.md for known vulnerability patterns in this project
     2. Identify attack surfaces from spec requirements
     3. Format EXACTLY as:
        ## Threat Model (pre-scan)
        | Threat | Attack Surface | Mitigation Required | Priority |
        |--------|---------------|-------------------|----------|
     4. Max 8 threats, prioritized by exploitability and impact.")
   ```
2. Store as `THREAT_MODEL` → inject into Phase 2. Plan MUST address each mitigation in Risk & Mitigation. Plan Critic RISK criterion MUST verify: `{M}/{N} threat mitigations addressed`.
3. Increment `ADVISOR_COUNT`. Progress: `  ├─ Skill Advisor [B]: security (score: {N}/5, threat model: {M} threats identified)`

**If B2 >= 3** (Enrich):
1. Invoke architect agent for pre-plan guidance:
   ```
   Task("Architecture Advisory: {feature}", subagent_type: "afc:afc-architect",
     prompt: "Provide architecture guidance BEFORE plan creation.
     ## Spec Summary
     {spec.md Key Entities + layer analysis from {config.architecture}}
     ## Why This Was Triggered
     {1-sentence explanation}
     ## Instructions
     1. Read your MEMORY.md for prior ADRs and architecture patterns
     2. Recommend: component placement, layer boundaries, interface contracts
     3. Flag conflicts with existing architecture patterns
     4. Format EXACTLY as:
        ## Architecture Advisory (pre-plan)
        - [PLACE] {component} → {layer/module}: {rationale}
        - [BOUNDARY] {interface}: {contract description}
        - [CONFLICT] {existing} ↔ {new}: {resolution recommendation}
        - [PATTERN] {recommended pattern}: {why it fits}
     5. Max 10 items. Update your MEMORY.md if new patterns are identified")
   ```
2. Store as `ARCH_ADVISORY` → inject into Phase 2. Plan Critic ARCHITECTURE criterion MUST validate against this advisory.
3. Increment `ADVISOR_COUNT`. Progress: `  ├─ Skill Advisor [B]: architect (score: {N}/5, advisory: {M} recommendations, {K} conflicts)`

**If both B1 and B2 >= 3**: launch both agents in a **single message** (parallel fork). After both return, apply `THREAT_MODEL` and `ARCH_ADVISORY` to plan. If mitigations conflict with architecture proposals → **ESCALATE** to user with conflict details.

---

## Checkpoint C — Post-Plan

> Fire AFTER Phase 2, BEFORE Phase 3 (Implement). Skip if `ADVISOR_COUNT >= 5`. Budget: max 2 skills.

| # | Question | Score 1–5 | If >= 3 | Skill | Mode |
|---|----------|-----------|---------|-------|------|
| C1 | Is **implementation risk high enough** that dependency pre-analysis would catch problems the plan missed? (files importing each other, high fan-out shared utils, incomplete `Depends On` relationships, hidden coupling) | 1=isolated changes, 5=deeply interconnected change set | dependency analysis (general-purpose fork) | Observe |
| C2 | Does the plan contain **unresolved domain uncertainties** — items tagged `[UNCERTAIN]`, open questions in Implementation Context, design decisions assuming domain knowledge the team may lack? | 1=all decisions well-grounded, 5=critical domain questions remain open | `consult({domain})` expert agent | Enrich (fork) |

**If C1 >= 3** (Observe):
1. Invoke analysis in fork context:
   ```
   Task("Complexity Analysis: {feature}", subagent_type: "general-purpose",
     prompt: "Analyze the dependency graph of files listed in the plan's File Change Map.
     ## File Change Map
     {paste File Change Map table from plan.md}
     ## Instructions
     1. For each file, check imports/dependencies (Grep for import/require/source patterns)
     2. Identify:
        - Circular dependencies between planned files
        - High fan-out files (>5 dependents outside the change set)
        - Hidden coupling not captured in Depends On column
        - Files imported by many others (risk of breakage)
     3. Format EXACTLY as:
        ## Complexity Analysis
        - [CIRCULAR] {file A} ↔ {file B}: {description}
        - [FAN-OUT] {file} → {N} dependents: {list top 5}
        - [COUPLING] {file A} → {file B}: {not in Depends On column}
        - [HIGH-RISK] {file}: {reason}
        ## Risk Summary
        Circular: {N}, High fan-out: {N}, Hidden coupling: {N}
     4. If no issues: '## Complexity Analysis\nNo significant risks detected.'")
   ```
2. Store to `.claude/afc/specs/{feature}/complexity-analysis.md`. Implement phase reads this — high-risk files get extra verification after modification. Circular dependencies → **ESCALATE** to user.
3. Increment `ADVISOR_COUNT`. Progress: `  ├─ Skill Advisor [C]: analyze (score: {N}/5, circular: {C}, fan-out: {F}, coupling: {H})`

**If C2 >= 3** (Enrich):
1. Determine which domain expert best resolves the uncertainties. Invoke:
   ```
   Task("Domain gap resolution: {domain}", subagent_type: "afc:{agent-id}",
     prompt: "Resolve domain uncertainties found during planning.
     ## Uncertain Items
     {extract all [UNCERTAIN] tagged items and open questions from plan.md}
     ## Plan Context
     {Implementation Context section from plan.md}
     ## Instructions
     1. For each uncertain item, provide a definitive answer with rationale
     2. Format EXACTLY as:
        ## Domain Resolutions
        - [RESOLVED] {item}: {answer} — {rationale}
        - [NEEDS-USER] {item}: {why this requires human judgment}
     3. Update your MEMORY.md with the resolution context")
   ```
2. Apply resolutions to plan.md (replace `[UNCERTAIN]` with `[RESOLVED: {answer}]`). `[NEEDS-USER]` → **ESCALATE** via AskUserQuestion.
3. Increment `ADVISOR_COUNT`. Progress: `  ├─ Skill Advisor [C]: consult({domain}) (score: {N}/5, {M} resolved, {K} needs-user)`

---

## Checkpoint D — Post-Implement

> Fire AFTER Phase 3, BEFORE Phase 4 (Review). Skip if `ADVISOR_COUNT >= 5`. Budget: max 2 skills.

| # | Question | Score 1–5 | If >= 3 | Skill | Mode |
|---|----------|-----------|---------|-------|------|
| D1 | Were **testable source files changed without corresponding test coverage**? (check `git diff --name-only` — skip config, types-only, static assets; only evaluate if `{config.test}` is non-empty) | 1=all changes have test coverage, 5=critical logic changed with zero tests | test generation (general-purpose fork) | Enrich |
| D2 | Based on **past pipeline quality data**, is there reason to believe this implementation has hidden quality issues? (check `.claude/afc/memory/quality-history/*.json` for elevated critical findings or recurring problem categories) | 1=clean history or no history, 5=strong pattern of recurring issues in similar areas | pre-review QA (general-purpose fork) | Observe |

**If D1 >= 3 AND `{config.test}` is non-empty** (Enrich):
1. For each changed source file: does the project have a test file for it? Was it also modified in this diff? Does it contain testable exports?
2. Invoke test generation:
   ```
   Task("Coverage boost: {feature}", subagent_type: "general-purpose",
     prompt: "Generate missing tests for recently implemented files.
     ## Uncovered Files
     {list of source files with testable logic but no test changes in this diff}
     ## Instructions
     1. Read each uncovered file to understand exports and behavior
     2. Read existing test files for pattern reference
     3. Generate unit tests targeting exported functions/classes, edge cases, error paths, integration points
     4. Follow project test framework: {config.test framework}
     5. Place test files following project convention
     6. Run {config.test} to verify tests pass
     7. Return: files created, test count, pass/fail status")
   ```
3. New test files automatically enter review scope. Increment `ADVISOR_COUNT`.
4. Progress: `  ├─ Skill Advisor [D]: test (score: {N}/5, {M} uncovered files → {K} test files generated)`

**If D2 >= 3** (Observe):
1. Load `.claude/afc/memory/quality-history/*.json` (most recent 3 files):
   ```
   Task("Pre-review QA: {feature}", subagent_type: "general-purpose",
     prompt: "Perform a pre-review quality audit focused on historically problematic areas.
     ## Changed Files
     {git diff --name-only}
     ## Quality History Context
     {summary of patterns from recent quality-history reports}
     ## Instructions
     1. Focus on recurring problem categories
     2. Check: error handling completeness, input validation, resource cleanup
     3. Format EXACTLY as:
        ## Pre-Review QA Findings
        - [{severity}] {file}:{line} — {issue}: {suggested fix}
        ## Priority Hints for Review
        - {file}: focus on {area} (historically problematic)
     4. Read-only — do NOT modify any files")
   ```
2. Store as `QA_FINDINGS` → inject into Phase 4 as Priority Hints. Increment `ADVISOR_COUNT`.
3. Progress: `  ├─ Skill Advisor [D]: qa (score: {N}/5, {M} priority hints for review)`

---

## Checkpoint E — Post-Review

> Fire AFTER Phase 4, BEFORE Phase 5 (Clean). Skip if `ADVISOR_COUNT >= 5`. Budget: max 1 skill.

| # | Question | Score 1–5 | If >= 3 | Skill | Mode |
|---|----------|-----------|---------|-------|------|
| E1 | Are there **recurring problem patterns** across this and past pipelines that should be codified as project rules? (check `.claude/afc/memory/retrospectives/` — same issue type recurred 3+ times and is not yet a project rule) | 1=no patterns or no history, 5=same issue type recurred 3+ times | pattern promotion (general-purpose fork) | Observe |

**If E1 >= 3** (Observe):
1. Read retrospective files. Identify recurring patterns. Check against existing `.claude/rules/afc-learned.md`.
2. Invoke learner:
   ```
   Task("Pattern promotion: {feature}", subagent_type: "general-purpose",
     prompt: "Review recurring patterns for potential promotion to project rules.
     ## Recurring Patterns
     {each pattern with: category, occurrence count, concrete examples}
     ## Current Review Findings
     {this pipeline's review findings matching retrospective patterns}
     ## Current Rules
     {read .claude/rules/afc-learned.md if exists, else 'No learned rules yet'}
     ## Instructions
     1. For each pattern, evaluate: is it actionable? already covered? would it have prevented recurrence?
     2. For patterns worth promoting, write:
        ### {Category}
        - **Rule**: {concise, enforceable statement}
        - **Rationale**: {why — based on {N} occurrences}
        - **Enforcement**: {how to check — linter, review criterion, or convention}
     3. Safety guardrails (mandatory):
        - Do NOT create rules about permissions, security policies, hook behavior, tool access
        - Do NOT contradict existing CLAUDE.md or .claude/rules/ content
        - Rules must be scoped to code conventions only (naming, style, workflow, testing, architecture)
        - Verify no duplicate or contradictory rule exists before appending
     4. Append new rules to .claude/rules/afc-learned.md (create if absent)
     5. Return: {N} evaluated, {M} promoted, {K} already covered")
   ```
3. Increment `ADVISOR_COUNT`. Progress: `  ├─ Skill Advisor [E]: learner (score: {N}/5, {M} patterns evaluated, {K} promoted to rules)`
