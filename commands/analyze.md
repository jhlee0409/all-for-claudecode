---
name: afc:analyze
description: "Artifact consistency validation (read-only)"
argument-hint: "[validation scope: spec-plan, tasks-only]"
user-invocable: false
context: fork
allowed-tools:
  - Read
  - Grep
  - Glob
model: haiku
---

# /afc:analyze — Artifact Consistency Validation

> Validates consistency and quality across spec.md, plan.md, and tasks.md.
> **Read-only** — does not modify any files.

## Arguments

- `$ARGUMENTS` — (optional) limit validation scope (e.g., "spec-plan", "tasks-only")

## Config Load

**Always** read `.claude/afc.config.md` first. This file contains free-form markdown sections:
- `## Architecture` — architecture pattern, layers, import rules (primary reference for this command)
- `## Code Style` — language, naming conventions, lint rules
- `## Project Context` — framework, state management, testing, etc.

If config file is missing: read `CLAUDE.md` for architecture info. Assume "Layered Architecture" if neither source has it.

## Execution Steps

### 1. Load Artifacts

From `.claude/afc/specs/{feature}/`:
- **spec.md** (required)
- **plan.md** (required)
- **tasks.md** (if present)
- **research.md** (if present)

Warn about missing files but proceed with what is available.

### 2. Run Validation

Validate across 6 categories:

#### A. Duplication Detection (DUPLICATION)
- Similar requirements within spec.md
- Overlapping tasks within tasks.md

#### B. Ambiguity Detection (AMBIGUITY)
- Unmeasurable adjectives ("appropriate", "fast", "good")
- Residual TODO/TBD/FIXME markers
- Incomplete sentences

#### C. Coverage Gaps (COVERAGE)
- spec → plan: Are all FR-*/NFR-* reflected in the plan?
- plan → tasks: Are all items in the plan's File Change Map present in tasks?
- spec → tasks: Are all requirements mapped to tasks?

#### D. Inconsistencies (INCONSISTENCY)
- Terminology drift (different names for the same concept)
- Conflicting requirements
- Mismatches between technical decisions in plan and execution in tasks

#### E. Principles Compliance (PRINCIPLES)
- Validate against MUST principles in .claude/afc/memory/principles.md if present
- Potential violations of {config.architecture} rules

#### F. Unidentified Risks (RISK)
- Are there risks not identified in plan.md?
- External dependency risks
- Potential performance bottlenecks

### 3. Severity Classification

| Severity | Criteria |
|----------|----------|
| **CRITICAL** | Principles violation, core feature blocker, security issue |
| **HIGH** | Duplication/conflict, untestable, coverage gap |
| **MEDIUM** | Terminology drift, ambiguous requirements |
| **LOW** | Style improvements, minor duplication |

### 4. Output Results (console)

```markdown
## Consistency Analysis Results: {feature name}

### Findings
| ID | Category | Severity | Location | Summary | Recommended Action |
|----|----------|----------|----------|---------|-------------------|
| A-001 | COVERAGE | HIGH | spec FR-003 | No mapping in tasks | Add task |
| A-002 | AMBIGUITY | MEDIUM | spec NFR-001 | "quickly" is unmeasurable | Add numeric threshold |

### Coverage Summary
| Mapping | Coverage |
|---------|----------|
| spec → plan | {N}% |
| plan → tasks | {N}% |
| spec → tasks | {N}% |

### Metrics
- Total requirements: {N}
- Total tasks: {N}
- Issues: CRITICAL {N} / HIGH {N} / MEDIUM {N} / LOW {N}

### Next Steps
{Concrete action proposals for CRITICAL/HIGH issues}
```

### 5. Final Output

```
Analysis complete
├─ Found: CRITICAL {N} / HIGH {N} / MEDIUM {N} / LOW {N}
├─ Coverage: spec→plan {N}%, plan→tasks {N}%, spec→tasks {N}%
└─ Recommended: {next action}
```

## Notes

- **Read-only**: Do not modify any files. Report only.
- **Avoid false positives**: Do not over-flag ambiguity. Consider context.
- **Optional**: Not required in the pipeline. Can proceed plan → implement directly.
