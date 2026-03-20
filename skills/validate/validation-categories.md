# /afc:validate — Validation Categories

## A. Duplication Detection (DUPLICATION)
- Similar requirements within spec.md
- Overlapping tasks within tasks.md

## B. Ambiguity Detection (AMBIGUITY)
- Unmeasurable adjectives ("appropriate", "fast", "good")
- Residual TODO/TBD/FIXME markers
- Incomplete sentences

## C. Coverage Gaps (COVERAGE)
- spec → plan: Are all FR-*/NFR-* reflected in the plan?
- plan → tasks: Are all items in plan's File Change Map present in tasks?
- spec → tasks: Are all requirements mapped to tasks?
- spec → context.md (if present): Are all FR-*/NFR-*/SC-* items copied into context.md's Acceptance Criteria section?

## D. Inconsistencies (INCONSISTENCY)
- Terminology drift (different names for the same concept)
- Conflicting requirements
- Mismatches between technical decisions in plan and execution in tasks

## E. Principles Compliance (PRINCIPLES)
- Validate against MUST principles in `.claude/afc/memory/principles.md` if present
- Potential violations of `{config.architecture}` rules

## F. Unidentified Risks (RISK)
- Risks not identified in plan.md
- External dependency risks
- Potential performance bottlenecks

## Severity Classification

| Severity | Criteria |
|----------|----------|
| **CRITICAL** | Principles violation, core feature blocker, security issue |
| **HIGH** | Duplication/conflict, untestable, coverage gap |
| **MEDIUM** | Terminology drift, ambiguous requirements |
| **LOW** | Style improvements, minor duplication |
