---
name: afc:clarify
description: "Resolve spec ambiguities with clarifying questions"
argument-hint: "[focus area: security, performance, UI flow]"
user-invocable: false
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
model: sonnet
---
# /afc:clarify — Resolve Spec Ambiguities

> Identifies ambiguous or incomplete areas in spec.md and resolves them through user questions.
> Answers are applied as inline updates to spec.md.

## Arguments

- `$ARGUMENTS` — (optional) focus on a specific area (e.g., "security", "performance", "UI flow")

## Project Config (auto-loaded)

!`cat .claude/afc.config.md 2>/dev/null || echo "[CONFIG NOT FOUND] .claude/afc.config.md not found. Run /afc:init first — abort if missing."`

## Execution Steps

### 1. Load Spec

1. Read `.claude/afc/specs/{feature}/spec.md` — stop if not found
2. If a `[NEEDS CLARIFICATION]` section exists, process it first
3. Quickly check existing codebase for related patterns

### 2. Scan for Ambiguities

Scan across 10 categories:

| # | Category | What to find |
|---|----------|-------------|
| 0 | Necessity | Is this feature truly needed? Does it already exist? Is the cost justified by the benefit? |
| 1 | Feature scope | Features with unclear boundaries |
| 2 | Domain/data | Incomplete entity relationships or field definitions |
| 3 | UX flow | Missing user journey steps |
| 4 | Non-functional quality | Performance/security requirements without numeric targets |
| 5 | External dependencies | APIs or libraries needing clarification |
| 6 | Edge cases | Undefined boundary conditions |
| 7 | Constraints/tradeoffs | Mutually incompatible requirements |
| 8 | Terminology consistency | Same concept with different names |
| 9 | Completion criteria | Success criteria that cannot be measured |
| 10 | Residual placeholders | TODO/TBD/??? |

These categories serve as a comprehensive checklist, not a rigid classification. Adapt to the project's domain — skip categories irrelevant to the project type (e.g., skip 'UX flow' for CLI tools) and add domain-specific categories if needed (e.g., 'regulatory compliance' for healthcare/fintech projects).

### 3. Generate and Present Questions

- Generate questions ranked by their impact on spec quality — how much would the answer change the spec's direction or completeness? Present the most impactful questions first. The number of questions should match the actual ambiguity level: deeply ambiguous specs may need more questions, while mostly-clear specs need fewer. Do not artificially cap at a fixed number, but keep the set focused and avoid overwhelming the user (aim for the minimum needed to resolve critical ambiguities).
- Present **one at a time** via AskUserQuestion:
  - Use multiple choice when possible (2-4 options)
  - Include the meaning/impact of each option

### 4. Update Spec

After each answer:
1. Find the relevant section in spec.md and apply the **inline update**
2. Remove `[NEEDS CLARIFICATION]` tags if present
3. Add new FR-* entries if new requirements arise from the answer
4. Briefly notify the user of changes

### 5. Final Output

```
Clarification complete
├─ Questions: {processed}/{generated}
├─ spec.md updated: {changed areas}
├─ New requirements: {added FR count}
├─ Remaining [NEEDS CLARIFICATION]: {count}
└─ Next step: /afc:plan
```

## Notes

- **Question focus**: Ask only what is needed to resolve critical ambiguities. Defer lower-priority questions to the plan phase rather than overwhelming the user.
- **Verify after update**: After updating spec.md, re-read the modified sections to confirm changes are consistent and no new `[NEEDS CLARIFICATION]` tags were introduced by the edit itself.
- **Modify spec only**: Do not touch plan.md or tasks.md.
- **Avoid redundancy**: Do not ask about items already clearly stated in spec.
- **If `$ARGUMENTS` is provided**: Focus the scan on that area.
