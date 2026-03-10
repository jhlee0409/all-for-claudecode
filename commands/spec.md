---
name: afc:spec
description: "Generate feature specification — use when the user asks to write a spec, define requirements, create acceptance criteria, or specify a feature"
argument-hint: "[feature description in natural language]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - WebSearch
  - WebFetch
model: sonnet
---
# /afc:spec — Generate Feature Specification

> Converts a natural language feature description into a structured specification (spec.md).
> Validates completeness with convergence-based Critic Loop. Operates on pure prompts without external scripts.

## Arguments

- `$ARGUMENTS` — (required) Feature description in natural language

## Project Config (auto-loaded)

!`cat .claude/afc.config.md 2>/dev/null || echo "[CONFIG NOT FOUND] .claude/afc.config.md not found. Create it with /afc:init."`

## Config Load

**Always** read `.claude/afc.config.md` first (read manually if not auto-loaded above).

If config file is missing:
1. Ask the user: "`.claude/afc.config.md` not found. Run `/afc:init` to set up the project?"
2. If user accepts → run `/afc:init`, then **restart this command** with the original `$ARGUMENTS`
3. If user declines → **abort**

## Execution Steps

### 1. Set Up Feature Directory

1. Check **current branch** → `BRANCH_NAME`
2. Determine **feature name**:
   - Extract 2-3 key keywords from `$ARGUMENTS`
   - Convert to kebab-case (e.g., "add user authentication" → `user-auth`)
3. **Create directory**: `.claude/afc/specs/{feature-name}/` (create parent `.claude/afc/specs/` directory if it does not exist)
4. If already exists, confirm with user: "Overwrite existing spec?"

### 2. Explore Codebase

Before writing the spec, understand the current project structure:

1. Check key directories by `{config.architecture}` layer
2. Explore existing code related to the feature description (Grep/Glob)
3. Identify related type definitions, APIs, and components
4. **Necessity & scope check** — evaluate whether the request warrants a full spec:
   - **Already exists?** If the feature substantially exists → report: "This feature appears to already exist at {path}." Ask user: enhance existing, replace entirely, or abort.
   - **Over-scoped?** If `$ARGUMENTS` implies 10+ files or multiple unrelated concerns → warn and suggest splitting into separate specs.
   - **Trivial?** If the change is small enough to implement directly (typo, config value, single-line fix) → suggest: "This can be implemented directly without a full spec. Proceed with direct edit?"
   - If user chooses abort → end with `"No spec generated — {reason}."` and suggest the appropriate alternative.

### 2.5. Research Gate (conditional)

Detect whether `$ARGUMENTS` references external libraries, APIs, or technologies not already present in the codebase:

1. **Scan for external references**: extract library names, API names, protocol names, and framework references from `$ARGUMENTS`
2. **Check codebase presence**: Grep/Glob for each reference in the project
3. **If all references are internal** (found in codebase): skip research, proceed to Step 3
4. **If external references detected**:
   - For each unknown reference, run a focused WebSearch query: `"{library/API name} latest stable version usage guide {current year}"`
   - Optionally use Context7 (`mcp__context7__resolve-library-id` → `mcp__context7__query-docs`) for library-specific documentation
   - Record findings to `.claude/afc/specs/{feature-name}/research-notes.md` (lightweight spec-scoped notes; distinct from plan phase's `research.md` which covers deep technical research)
   - Also use findings inline as context for spec writing
   - Tag each researched item in spec with `[RESEARCHED]` for traceability

> Research here is **lightweight and spec-scoped** — just enough to write accurate requirements. Deep technical research (alternatives comparison, migration paths) belongs in `/afc:plan` Phase 0.

### 3. Write Spec

Create `.claude/afc/specs/{feature-name}/spec.md`:

```markdown
# Feature Spec: {feature name}

> Created: {YYYY-MM-DD}
> Branch: {BRANCH_NAME}
> Status: Draft

## Overview
{2-3 sentences on the purpose and background of the feature}

## User Stories

### US1: {story title} [P1]
**Description**: {feature description from user perspective}
**Priority rationale**: {why this order}
**Independent testability**: {whether this story can be tested on its own}

#### Acceptance Scenarios (GWT for user scenarios)
- [ ] Given {precondition}, When {action}, Then {result}
- [ ] Given {precondition}, When {action}, Then {result}

#### System Requirements (EARS notation)

> Use one of the 5 EARS patterns for each requirement. Each requirement must map to at least one expected test case (TC).

| Pattern | Template | Use When |
|---------|----------|----------|
| Ubiquitous | `THE System SHALL {behavior}` | Always-on property (no trigger needed) |
| Event-driven | `WHEN {trigger}, THE System SHALL {response}` | Specific event triggers a response |
| State-driven | `WHILE {state}, THE System SHALL {behavior}` | Behavior depends on system state |
| Unwanted | `IF {condition}, THE System SHALL {handling}` | Error/failure handling |
| Optional | `WHERE {feature/config active}, THE System SHALL {behavior}` | Feature flag or conditional capability |

- [ ] WHEN {trigger}, THE System SHALL {behavior} → TC: `should_{behavior}_when_{trigger}`
- [ ] WHILE {state}, THE System SHALL {behavior} → TC: `should_{behavior}_while_{state}`

### US2: {story title} [P2]
{same format}

## Requirements

### Functional Requirements
- **FR-001**: {requirement}
- **FR-002**: {requirement}

### Non-Functional Requirements
- **NFR-001**: {performance/security/accessibility etc.}

### Auto-Suggested NFRs
{Load `${CLAUDE_PLUGIN_ROOT}/docs/nfr-templates.md` and select 3-5 relevant NFRs based on the project type detected from afc.config.md}
- **NFR-A01** [AUTO-SUGGESTED]: {suggestion from matching project type template}
- **NFR-A02** [AUTO-SUGGESTED]: {suggestion}
- **NFR-A03** [AUTO-SUGGESTED]: {suggestion}
{Tag each with [AUTO-SUGGESTED]. Users may accept, modify, or remove.}

### Key Entities
| Entity | Description | Related Existing Code |
|--------|-------------|-----------------------|
| {name} | {description} | {path or "new"} |

## Success Criteria
- **SC-001**: {measurable success indicator}
- **SC-002**: {measurable success indicator}

## Edge Cases
- {edge case 1}
- {edge case 2}

## Constraints
- {technical/business constraints}

## [NEEDS CLARIFICATION]
- {uncertain items — record if any, remove section if none}
```

### 3.5. Inline Clarification (standalone mode only)

After writing the spec, check for `[NEEDS CLARIFICATION]` items:

1. **If no `[NEEDS CLARIFICATION]` items exist**: skip, proceed to Step 4
2. **If items exist and running standalone** (`/afc:spec` directly):
   - Present each ambiguity to the user via AskUserQuestion (max 3 questions per batch)
   - Apply answers directly into spec.md (replace `[NEEDS CLARIFICATION]` with resolved text)
   - If user chooses to defer: leave items as `[NEEDS CLARIFICATION]` and note in final output
3. **If running inside `/afc:auto`**: skip this step entirely (auto.md handles auto-resolution in Phase 1)

> This replaces the previous pattern of always deferring to `/afc:clarify`. Standalone spec now resolves ambiguities immediately when the user is present. `/afc:clarify` remains available for revisiting specs later.

### 4. Retrospective Check

If `.claude/afc/memory/retrospectives/` directory exists, load the **most recent 10 files** (sorted by filename descending) and check:
- Were there previous `[AUTO-RESOLVED]` items that turned out wrong? Flag similar patterns.
- Were there scope-related issues in past specs? Warn about similar ambiguities.

### 5. Critic Loop

> **Always** read `${CLAUDE_PLUGIN_ROOT}/docs/critic-loop-rules.md` first and follow it.

Run the critic loop until convergence. Safety cap: 5 passes.

| Criterion | Validation |
|-----------|------------|
| **COMPLETENESS** | Does every User Story have acceptance scenarios? Are any requirements missing? |
| **MEASURABILITY** | Are the success criteria measurable, not subjective? |
| **INDEPENDENCE** | Are implementation details (code, library names) absent from the spec? |
| **EDGE_CASES** | Are at least 2 edge cases identified? Any missing boundary conditions? |
| **TESTABILITY** | Does every System Requirement follow one of the 5 EARS patterns (WHEN/WHILE/IF/WHERE/SHALL)? Does each EARS requirement have a mapped TC (`→ TC: should_...`)? If not → FAIL and auto-fix: rewrite to EARS + generate TC mapping. |

**On FAIL**: auto-fix and continue to next pass.
**On ESCALATE**: pause, present options to user, apply choice, resume.
**On DEFER**: record reason, mark criterion clean, continue.
**On CONVERGE**: `✓ Critic converged ({N} passes, {M} fixes, {E} escalations)`
**On SAFETY CAP**: `⚠ Critic safety cap ({N} passes). Review recommended.`

### 5.5. Auto-Checkpoint (standalone only)

When not running inside `/afc:auto`, save progress for `/afc:resume`:
- Create `.claude/afc/memory/` directory if it does not exist (`mkdir -p .claude/afc/memory/`)
- Write/update `.claude/afc/memory/checkpoint.md` with: branch, last commit (or "none" if empty repo), feature name, current phase (spec complete), next step (`/afc:plan`)
- Skip if running inside auto pipeline (auto manages its own checkpoints via phase transitions)

### 6. Final Output

```
Spec generated
├─ .claude/afc/specs/{feature-name}/spec.md
├─ User Stories: {count}
├─ Requirements: FR {count}, NFR {count}
├─ Research: {N} external references researched / skipped (all internal)
├─ Clarified: {N} items resolved inline / {M} deferred
├─ Unresolved: {[NEEDS CLARIFICATION] count}
└─ Next step: /afc:plan (unresolved items will be flagged at plan start)
```

## Notes

- Do **not** write implementation details in the spec. Expressions like "manage with Zustand" belong in plan.md.
- Specify **actual paths** for entities related to existing code.
- If `$ARGUMENTS` is empty, ask user for a feature description.
- Do not pack too many features into one spec. Suggest splitting if User Stories exceed 5.
- When running `/afc:auto`, `[AUTO-SUGGESTED]` NFRs are included automatically. Review after completion is recommended.
