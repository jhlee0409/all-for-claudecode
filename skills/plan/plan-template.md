# Implementation Plan: {feature name}

## Summary
{summary of core requirements from spec + technical approach, 3-5 sentences}

## Technical Context
{Summarize key project settings from .claude/rules/afc-project.md (auto-loaded) and afc.config.md}
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

## Test Strategy

> Written alongside the File Change Map. Classify each implementation file and decide test coverage level.
> Determines which files need test coverage and at what level.

### Code Classification

| File | Code Type | Test Need | Reason |
|------|-----------|:---------:|--------|
| {path} | {business-logic / pure-function / side-effect / framework / config / UI} | {required / optional / unnecessary} | {brief justification} |

> Classification guide:
> - **business-logic / pure-function**: Required — unit tests (AAA pattern)
> - **side-effect code** (external API, DB, file I/O): Required — integration tests with mocks
> - **framework / config / getter-setter / boilerplate**: Unnecessary — no test
> - **UI rendering** (no state logic): Optional — minimal snapshot or skip

### Test Pyramid

- **Unit tests**: {count} files ({which files})
- **Integration tests**: {count} files ({which files}, if applicable)
- **E2E tests**: {count} (if applicable, only for critical user flows)

### Required Test Cases (derived from spec EARS requirements)

{For each spec EARS requirement with `→ TC:` mapping, list the test case here}
- `should_{behavior}_when_{trigger}` → covers FR-{NNN}
- `should_{behavior}_while_{state}` → covers FR-{NNN}

## File Change Map

| File | Action | Description | Depends On | Phase |
|------|--------|-------------|------------|-------|
| {path} | create/modify/delete | {summary} | {file(s) or "—"} | {1-N} |

> - **Depends On**: list file(s) that must be created/modified first (enables dependency-aware task generation in /afc:implement).
> - **Phase**: implementation phase number. Same-phase + no dependency + different file = parallelizable.
> - **Test files**: For each implementation file classified as "required" in Code Classification, include a corresponding test file in the same Phase. Test files are first-class citizens in the File Change Map.

## Implementation Context

> Auto-generated section for implementation agents. Compress to under 500 words.
> This section travels with every sub-agent prompt during /afc:implement.

- **Objective**: {1-sentence feature purpose from spec Overview}
- **Key Constraints**: {NFR summaries + spec Constraints section, compressed}
- **Critical Edge Cases**: {top 3 edge cases from spec, 1 line each}
- **Risk Watchpoints**: {top risks from Risk & Mitigation table}
- **Must NOT**: {explicit prohibitions — from spec constraints, principles.md, or CLAUDE.md}
- **Acceptance Anchors**: {key acceptance criteria from spec that implementation must satisfy}

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
