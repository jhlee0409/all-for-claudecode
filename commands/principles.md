---
name: selfish:principles
description: "Manage project principles"
argument-hint: "[action: add, remove, init]"
disable-model-invocation: true
allowed-tools:
  - Read
  - Write
  - Grep
  - Glob
model: haiku
---

# /selfish:principles — Manage Project Principles

> Creates and manages the project's core principles (constitution).
> Stored in .claude/selfish/memory/principles.md and referenced across all sessions.

## Arguments

- `$ARGUMENTS` — (optional) action directive:
  - not specified: view current principles
  - `add {principle}`: add a new principle
  - `remove {number}`: remove a principle
  - `init`: interactive initial setup

## Config Load

**Must** read `.claude/selfish.config.md` first. Stop if the config file is not present.

## Execution Steps

### 1. Check Current State

Read `.claude/selfish/memory/principles.md`:
- If present: load existing principles
- If absent: empty state (show `init` instructions)

### 2. Action Branch

#### A. View (no arguments)
Display current principles list:
```
Project Principles
├─ MUST-001: {principle}
├─ MUST-002: {principle}
├─ SHOULD-001: {principle}
└─ Last updated: {date}
```

#### B. Initial Setup (`init`)

Collect principles interactively:

1. Analyze **project context** (CLAUDE.md, package.json, code structure)
2. Suggest automatically extractable principles:
   - Comply with {config.architecture} rules
   - Follow {config.code_style}
   - Zero lint warnings (per {config.ci})
   - etc.
3. Ask user for additional principles (AskUserQuestion)
4. Structure collected principles

#### C. Add (`add`)
1. Determine strength of the new principle (MUST / SHOULD / MAY)
2. Add to principles.md
3. Update version

#### D. Remove (`remove`)
1. Confirm the principle
2. Remove after user confirmation
3. Update version (MAJOR)

### 3. Storage Format

```markdown
# Project Principles

> Version: {MAJOR.MINOR.PATCH}
> Last Updated: {YYYY-MM-DD}

## MUST (non-negotiable)
- **MUST-001**: {principle} — {rationale}
- **MUST-002**: {principle} — {rationale}

## SHOULD (strongly recommended)
- **SHOULD-001**: {principle} — {rationale}

## MAY (optional)
- **MAY-001**: {principle} — {rationale}

## Changelog
- {date}: {change description}
```

### 4. Versioning Rules

- **MAJOR**: MUST principle added, removed, or redefined
- **MINOR**: SHOULD/MAY principle added, MUST principle clarified
- **PATCH**: Typo fix, rationale elaboration

## Notes

- **Persistent storage**: Saved to .claude/selfish/memory/principles.md and maintained across sessions.
- **Auto-referenced**: Automatically loaded and validated by /selfish:plan and /selfish:architect.
- **Keep it concise**: Maintain no more than 10 principles. Too many reduces effectiveness.
- **Avoid duplication with CLAUDE.md**: Do not re-register rules already present in CLAUDE.md as principles.
