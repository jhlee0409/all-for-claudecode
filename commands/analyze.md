---
name: afc:analyze
description: "General-purpose code and component analysis"
argument-hint: "<analysis target or question>"
user-invocable: true
context: fork
allowed-tools:
  - Read
  - Grep
  - Glob
  - WebSearch
model: sonnet
---

# /afc:analyze — Code Analysis

> Performs general-purpose codebase exploration and analysis based on a natural-language prompt.
> **Read-only** — does not modify any files.

## Arguments

- `$ARGUMENTS` — (required) description of what to analyze (e.g., "trace the login flow", "root cause of rendering bug", "how does the hook system work")

## Config Load

**Always** read `.claude/afc.config.md` first. This file contains free-form markdown sections:
- `## Architecture` — architecture pattern, layers, import rules (primary reference for structural analysis)
- `## Code Style` — language, naming conventions, lint rules
- `## Project Context` — framework, state management, testing, etc.

If config file is missing: read `CLAUDE.md` for architecture info. Proceed without config if neither exists.

## Execution Steps

### 1. Parse Analysis Intent

Classify `$ARGUMENTS` into one of these analysis modes:

| Mode | Trigger Keywords | Focus |
|------|-----------------|-------|
| **Root Cause** | "why", "cause", "bug", "error", "broken" | Error trace → data flow → hypothesis |
| **Structural** | "how", "architecture", "flow", "trace", "structure" | Component relationships, call graphs, data flow |
| **Exploratory** | "what", "find", "where", "which", "list" | File/function discovery, pattern matching |
| **Comparative** | "difference", "compare", "vs", "between" | Side-by-side analysis of implementations |

If the intent doesn't clearly match a mode, default to **Exploratory**.

### 2. Codebase Exploration

Based on the classified mode:

1. **Identify scope**: determine which files/directories are relevant to `$ARGUMENTS`
2. **Read code**: read relevant files using Read tool (prioritize by relevance)
3. **Trace connections**: follow imports, function calls, and data flow
4. **Gather evidence**: collect specific code references (file:line) for findings

Exploration should be guided by `{config.architecture}` layer structure when available.

### 3. Analysis

Apply the appropriate analysis lens:

- **Root Cause**: build a causal chain from symptom → intermediate causes → root cause
- **Structural**: map component relationships, identify coupling and cohesion patterns
- **Exploratory**: enumerate findings with code references
- **Comparative**: highlight similarities, differences, and tradeoffs

### 4. Output Results (console)

```markdown
## Analysis: {summary of $ARGUMENTS}

### Mode: {Root Cause | Structural | Exploratory | Comparative}

### Findings
{Numbered findings with code references (file:line)}

### Key Relationships
{Relevant component/function relationships discovered}

### Summary
{2-3 sentence conclusion answering the original question}

### Suggested Next Steps
{1-3 actionable suggestions based on the analysis}
```

### 5. Final Output

```
Analysis complete: {short summary}
├─ Mode: {mode}
├─ Files explored: {N}
├─ Findings: {N}
└─ Suggested next steps: {N}
```

## Notes

- **Read-only**: Do not modify any files. Report only.
- **Scope discipline**: Focus analysis on what was asked. Do not expand scope unnecessarily.
- **Code references**: Always include `file:line` references so the user can navigate to relevant code.
- **Not artifact validation**: For spec/plan/tasks consistency checks, use `/afc:validate` instead.
