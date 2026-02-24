---
name: afc:spec
description: "Generate feature specification"
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

#### Acceptance Scenarios
- [ ] Given {precondition}, When {action}, Then {result}
- [ ] Given {precondition}, When {action}, Then {result}

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

### 4. Retrospective Check

If `.claude/afc/memory/retrospectives/` directory exists, load retrospective files and check:
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

**On FAIL**: auto-fix and continue to next pass.
**On ESCALATE**: pause, present options to user, apply choice, resume.
**On DEFER**: record reason, mark criterion clean, continue.
**On CONVERGE**: `✓ Critic converged ({N} passes, {M} fixes, {E} escalations)`
**On SAFETY CAP**: `⚠ Critic safety cap ({N} passes). Review recommended.`

### 6. Final Output

```
Spec generated
├─ .claude/afc/specs/{feature-name}/spec.md
├─ User Stories: {count}
├─ Requirements: FR {count}, NFR {count}
├─ Unresolved: {[NEEDS CLARIFICATION] count}
└─ Next step: /afc:clarify (if unresolved) or /afc:plan
```

## Notes

- Do **not** write implementation details in the spec. Expressions like "manage with Zustand" belong in plan.md.
- Specify **actual paths** for entities related to existing code.
- If `$ARGUMENTS` is empty, ask user for a feature description.
- Do not pack too many features into one spec. Suggest splitting if User Stories exceed 5.
- When running `/afc:auto`, `[AUTO-SUGGESTED]` NFRs are included automatically. Review after completion is recommended.
