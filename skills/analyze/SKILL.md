---
name: afc:analyze
description: "General-purpose code and component analysis — use when the user asks to analyze code, trace a flow, audit consistency, understand how something works, or inspect components"
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

Architecture, Code Style, and Project Context are auto-loaded via `.claude/rules/afc-project.md`.
Read `.claude/afc.config.md` if CI commands are needed.

If neither rules file nor config exists: read `CLAUDE.md` for architecture info. Proceed without config if neither exists.

## Execution Steps

### 1. Parse Analysis Intent

Read the user's question semantically. What does the user actually want to understand? Select the mode that best serves their learning goal.

| Mode | When to select | Focus |
|------|---------------|-------|
| **Root Cause** | User wants to understand WHY something is broken, failing, or behaving unexpectedly — the goal is diagnosing a problem | Error trace → data flow → hypothesis |
| **Structural** | User wants to understand HOW a system is built or how components relate — the goal is comprehension of design or flow | Component relationships, call graphs, data flow |
| **Exploratory** | User wants to discover WHAT exists in the codebase — the goal is finding, listing, or locating things | File/function discovery, pattern matching |
| **Comparative** | User wants to understand the DIFFERENCE between two or more things — the goal is contrast and tradeoff evaluation | Side-by-side analysis of implementations |

If the question spans multiple modes, select the PRIMARY mode that best matches the user's core learning goal, and note secondary aspects to incorporate during analysis.

If the intent doesn't clearly match a single mode, default to **Exploratory**.

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
