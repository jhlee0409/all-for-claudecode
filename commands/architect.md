---
name: selfish:architect
description: "Architecture analysis and design advice"
argument-hint: "[analysis target or design question]"
disable-model-invocation: true
context: fork
agent: selfish-architect
allowed-tools:
  - Read
  - Write
  - Grep
  - Glob
  - Bash
  - Task
  - WebSearch
model: sonnet
---

# /selfish:architect — Architecture Analysis and Design Advice

> Analyzes the codebase architecture and records design decisions.
> Ensures design quality through convergence-based Critic Loop. Does not modify source code. May write ADR files to `memory/decisions/`.

## Arguments

- `$ARGUMENTS` — (required) analysis target or design question (e.g., "review state management strategy", "where to add new entity")

## Config Load

Read the following settings from `CLAUDE.md` or `.claude/CLAUDE.md` at the project root and assign to the `config` variable:

```
config.architecture = the architecture pattern used in the project
                      (e.g., "FSD", "Clean Architecture", "Layered", "Modular Monolith")
                      → Architecture standard specified in CLAUDE.md. Assume "Layered Architecture" if not present.
```

## Execution Steps

### 1. Determine Scope

Analyze `$ARGUMENTS` to identify the task type:

| Type | Example | Output |
|------|---------|--------|
| **Structure Analysis** | "timeline module structure" | Dependency map + improvement suggestions |
| **Design Question** | "where to put new feature?" | Placement suggestion + rationale |
| **ADR Recording** | "Redis vs In-memory decision" | Architecture Decision Record |
| **Refactoring Evaluation** | "need to split store?" | Current issues + refactoring plan |

### 2. Explore Codebase

1. Explore relevant directories/files (Glob, Grep, Read)
2. Trace dependency flow (import relationships)
3. Verify {config.architecture} structure
4. Identify existing patterns

Use Agent Teams for wide analysis scope (3+ modules) with parallel exploration:
```
Task("analyze features/timeline", subagent_type: Explore)
Task("analyze widgets/timeline", subagent_type: Explore)
```

### 3. Write Analysis

Structure analysis results and **print to console**:

```markdown
## Architecture Analysis: {topic}

### Current Structure
{dependency map, module relationships, data flow}

### Findings
| # | Area | Current | Suggested | Impact |
|---|------|---------|-----------|--------|
| 1 | {area} | {current approach} | {suggestion} | H/M/L |

### Design Decision (ADR)
**Decision**: {chosen approach}
**Status**: Proposed / Accepted / Deprecated
**Context**: {background}
**Options**:
1. {option1} — Pros: / Cons:
2. {option2} — Pros: / Cons:
**Rationale**: {why this choice}
**Consequences**: {expected impact}

### Architecture Consistency
{config.architecture} rule violations, import direction validation
```

### 4. Critic Loop

> **Always** read `${CLAUDE_PLUGIN_ROOT}/docs/critic-loop-rules.md` first and follow it.

Run the critic loop until convergence. Safety cap: 7 passes.

| Criterion | Validation |
|-----------|------------|
| **FEASIBILITY** | Is the suggestion achievable in the current codebase? |
| **INCREMENTALITY** | Can it be applied incrementally? (avoid big-bang refactoring) |
| **COMPATIBILITY** | Is it compatible with existing code? Are there breaking changes? |
| **ARCHITECTURE** | Does it comply with {config.architecture} rules? |

**On FAIL**: auto-fix and continue to next pass.
**On ESCALATE**: pause, present options to user, apply choice, resume.
**On DEFER**: record reason, mark criterion clean, continue.
**On CONVERGE**: `✓ Critic converged ({N} passes, {M} fixes, {E} escalations)`
**On SAFETY CAP**: `⚠ Critic safety cap ({N} passes). Review recommended.`

### 5. Save ADR (for design decisions)

If ADR type, save to `memory/decisions/{YYYY-MM-DD}-{topic}.md`:

```markdown
# ADR: {title}
- **Date**: {YYYY-MM-DD}
- **Status**: Proposed
- **Context**: {background}
- **Decision**: {choice}
- **Rationale**: {reason}
- **Consequences**: {impact}
```

### 6. Final Output

```
Architecture analysis complete
├─ Type: {structure analysis | design question | ADR | refactoring evaluation}
├─ Findings: {count}
├─ Critic: converged ({N} passes, {M} fixes, {E} escalations)
├─ ADR: {saved | n/a}
└─ Suggestion: {key suggestion in one line}
```

## Notes

- **No source modification**: Does not modify project source code. May write ADR files to `memory/decisions/`.
- **Based on actual code**: Explore the actual codebase, not assumptions.
- **Architecture first**: All suggestions respect {config.architecture} rules.
- **Incremental changes**: Prefer incremental improvements over big-bang refactoring.
