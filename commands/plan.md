---
name: afc:plan
description: "Implementation design"
argument-hint: "[additional context or constraints]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - WebSearch
  - WebFetch
model: sonnet
---
# /afc:plan — Implementation Design

> Generates an implementation plan (plan.md) based on the feature specification (spec.md).
> Ensures quality with convergence-based Critic Loop and runs research in parallel when needed.

## Arguments

- `$ARGUMENTS` — (optional) Additional context or constraints

## Project Config (auto-loaded)

!`cat .claude/afc.config.md 2>/dev/null || echo "[CONFIG NOT FOUND] .claude/afc.config.md not found. Create it with /afc:init."`

## Config Load

**Always** read `.claude/afc.config.md` first (read manually if not auto-loaded above).

If config file is missing:
1. Ask the user: "`.claude/afc.config.md` not found. Run `/afc:init` to set up the project?"
2. If user accepts → run `/afc:init`, then **restart this command** with the original `$ARGUMENTS`
3. If user declines → **abort**

## Execution Steps

### 1. Load Context

1. Check **current branch** → `BRANCH_NAME`
2. Find **.claude/afc/specs/{feature}/spec.md**:
   - Search under `.claude/afc/specs/` for a directory matching the current branch name or `$ARGUMENTS`
   - If not found: print "spec.md not found. Run `/afc:spec` first." then **abort**
3. Read full **spec.md**
4. Read **.claude/afc/memory/principles.md** (if present)
5. Read **CLAUDE.md** project context

### 2. Clarification Check

- If spec.md contains `[NEEDS CLARIFICATION]` tags:
  - Warn user: "There are unresolved clarification items. Do you want to continue?"
  - If user chooses to stop → guide to `/afc:clarify` then **abort**

### 3. Phase 0 — Research (ReWOO pattern, if needed)

Extract technical uncertainties from spec.md:

1. Are there libraries/APIs not yet used?
2. Are performance requirements unverified?
3. Is the integration approach with the existing codebase unclear?

**If no uncertain items**: skip Phase 0.

**If there are uncertain items**, follow the 3-step ReWOO flow:

#### Step 1: Plan (enumerate all topics — NO execution yet)
List all research topics as a numbered list:
```
1. {topic1} — {what we need to know}
2. {topic2} — {what we need to know}
3. {topic3} — {what we need to know}
```

#### Step 2: Execute (parallel for independent topics)
- If topics are independent (no result dependency): launch parallel Task() calls in a **single message**:
  ```
  Task("Research: {topic1}", subagent_type: "general-purpose")
  Task("Research: {topic2}", subagent_type: "general-purpose")
  ```
- If a topic depends on another's result: execute sequentially after the dependency resolves
- For 1-2 topics: resolve directly via WebSearch/codebase exploration (no delegation needed)

#### Step 3: Solve (consolidate all results)
Collect all results and record in `.claude/afc/specs/{feature}/research.md`:
```markdown
## {topic}
**Decision**: {chosen approach}
**Rationale**: {reason}
**Alternatives**: {other approaches considered}
**Source**: {URL or file path}
```

### 4. Phase 1 — Write Design

Create `.claude/afc/specs/{feature}/plan.md`. **Must** follow the structure below:

```markdown
# Implementation Plan: {feature name}

## Summary
{summary of core requirements from spec + technical approach, 3-5 sentences}

## Technical Context
{summary of project settings loaded from afc.config.md}
- **Language**: {config.code_style.language}
- **Framework**: {config.framework.name}
- **State**: {config.state_management summary}
- **Architecture**: {config.architecture.style}
- **Styling**: {config.styling.framework}
- **Testing**: {config.testing.framework}
- **Constraints**: {constraints extracted from spec}

## Principles Check
{if .claude/afc/memory/principles.md exists: validation results against MUST principles}
{if violations possible: state explicitly + justification}

## Architecture Decision
### Approach
{core idea of the chosen design}

### Architecture Placement
| Layer | Path | Role |
|-------|------|------|
| {entities/features/widgets/shared} | {path} | {description} |

### State Management Strategy (omit if not applicable)
{what combination of Zustand store / React Query / Context is used where}

### API Design (omit if not applicable)
{plan for new API endpoints or use of existing APIs}

## File Change Map
{list of files to change/create. for each file:}
| File | Action | Description |
|------|--------|-------------|
| {path} | create/modify/delete | {summary of change} |

## Risk & Mitigation
| Risk | Impact | Mitigation |
|------|--------|------------|
| {risk} | {H/M/L} | {approach} |

## Alternative Design
### Approach 0: No Change (status quo)
{Why might the current state be sufficient? What is the cost of doing nothing?}
{If no change is clearly inferior: state specific reason — "Status quo lacks X, which is required by FR-001"}
{If no change is viable: recommend it — avoid implementing for the sake of implementing}

### Approach A: {chosen approach name}
{Brief description — this is the approach detailed above}

### Approach B: {alternative approach name}
{Brief description of a meaningfully different approach}

| Criterion | No Change | Approach A | Approach B |
|-----------|-----------|-----------|-----------|
| Complexity | None | {evaluation} | {evaluation} |
| Risk | None | {evaluation} | {evaluation} |
| Maintainability | Current | {evaluation} | {evaluation} |
| Justification | {why not enough} | {why this} | {why this} |

**Decision**: Approach {0/A/B} — {1-sentence rationale}
{If Approach 0 chosen: abort plan, report: "No implementation needed — current state satisfies requirements."}

## Phase Breakdown
### Phase 1: Setup
{project structure, type definitions, configuration}

### Phase 2: Core Implementation
{core business logic, state management}

### Phase 3: UI & Integration
{UI components, API integration}

### Phase 4: Polish
{error handling, performance optimization, tests}
```

### 5. Critic Loop

> **Always** read `${CLAUDE_PLUGIN_ROOT}/docs/critic-loop-rules.md` first and follow it.

Run the critic loop until convergence. Safety cap: 7 passes.

| Criterion | Validation |
|-----------|------------|
| **COMPLETENESS** | Are all requirements (FR-*) from spec.md reflected in the plan? |
| **FEASIBILITY** | Is it compatible with the existing codebase? Are dependencies available? |
| **ARCHITECTURE** | Does it comply with {config.architecture} rules? |
| **RISK** | Are there any unidentified risks? Additionally, if `.claude/afc/memory/retrospectives/` directory contains files from previous pipeline runs, load each file and check whether the current plan addresses the patterns recorded there. Tag matched patterns with `[RETRO-CHECKED]`. |
| **PRINCIPLES** | Does it not violate the MUST principles in principles.md? |

**On FAIL**: auto-fix and continue to next pass.
**On ESCALATE**: pause, present options to user, apply choice, resume.
**On DEFER**: record reason, mark criterion clean, continue.
**On CONVERGE**: `✓ Critic converged ({N} passes, {M} fixes, {E} escalations)`
**On SAFETY CAP**: `⚠ Critic safety cap ({N} passes). Review recommended.`

### 6. Final Output

```
Plan generated
├─ .claude/afc/specs/{feature}/plan.md
├─ .claude/afc/specs/{feature}/research.md (if research was performed)
├─ Critic: converged ({N} passes, {M} fixes, {E} escalations)
└─ Next step: /afc:tasks
```

## Notes

- **"No Change" is a valid outcome**: If Approach 0 (status quo) is the best option, recommend it. Do not implement for the sake of implementing.
- Write plan.md to an **actionable level**. Vague expressions like "handle appropriately" are prohibited.
- File paths in the File Change Map must be based on the **actual project structure** (no guessing).
- Place files according to {config.architecture} rules; verify by checking existing codebase patterns.
- If there is a conflict with CLAUDE.md project settings, CLAUDE.md takes priority.
