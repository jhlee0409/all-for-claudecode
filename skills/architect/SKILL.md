---
name: afc:architect
description: "Architecture analysis and design advice — use when the user asks about architecture, system design, layer boundaries, or wants structural design review"
argument-hint: "[analysis target or design question]"
context: fork
agent: afc-architect
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

# /afc:architect — Architecture Analysis and Design Advice

> Analyzes the codebase architecture and records design decisions.
> Ensures design quality through convergence-based Critic Loop. Does not modify source code. May write ADR files to `.claude/afc/memory/decisions/`.

## Arguments

- `$ARGUMENTS` — (required) analysis target or design question (e.g., "review state management strategy", "where to add new entity")

## Config Load

Read `.claude/afc.config.md` if CI commands are needed.
Architecture, Code Style, and Project Context are auto-loaded via `.claude/rules/afc-project.md`.

If neither rules file nor config exists: read `CLAUDE.md` for architecture info. Assume "Layered Architecture" if no source has it.

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
Task("analyze features/timeline", subagent_type: "Explore")
Task("analyze widgets/timeline", subagent_type: "Explore")
```

**Cross-Module Import Chain Verification** (after Explore agents return):

When parallel Explore agents are used, the orchestrator must verify cross-module boundaries that no single agent can see:

1. From each agent's dependency map, extract **outbound imports** that cross module boundaries
2. For each cross-module import chain (e.g., widget → feature → shared), read the actual import statements at the boundary files
3. Verify against {config.architecture} rules: does the full chain respect layer direction, not just each module's internal imports?
4. Report any cross-module violations not surfaced by individual agents

Do not trust agent-summarized import relationships for cross-boundary chains — re-read the boundary files directly.

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

Read `${CLAUDE_SKILL_DIR}/../../docs/critic-loop-rules.md` and follow it. Safety cap: 5 passes.

| Criterion | Validation |
|-----------|------------|
| **FEASIBILITY** | Is the suggestion achievable in the current codebase? |
| **INCREMENTALITY** | Can it be applied incrementally? (avoid big-bang refactoring) |
| **COMPATIBILITY** | Is it compatible with existing code? Are there breaking changes? |
| **ARCHITECTURE** | Does it comply with {config.architecture} rules? |

### 5. Save ADR (for design decisions)

If ADR type, save to `.claude/afc/memory/decisions/{YYYY-MM-DD}-{topic}.md`:

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

- **No source modification**: Does not modify project source code. May write ADR files to `.claude/afc/memory/decisions/`.
- **Based on actual code**: Explore the actual codebase, not assumptions.
- **Architecture first**: All suggestions respect {config.architecture} rules.
- **Incremental changes**: Prefer incremental improvements over big-bang refactoring.
