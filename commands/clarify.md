---
name: afc:clarify
description: "Resolve spec ambiguities"
argument-hint: "[focus area: security, performance, UI flow]"
user-invocable: false
model: sonnet
---
# /afc:clarify — Resolve Spec Ambiguities

> Identifies ambiguous or incomplete areas in spec.md and resolves them through user questions.
> Answers are applied as inline updates to spec.md.

## Arguments

- `$ARGUMENTS` — (optional) focus on a specific area (e.g., "security", "performance", "UI flow")

## Config Load

**Must** read `.claude/afc.config.md` first. If the config file is not present, print "`.claude/afc.config.md` not found. Run `/afc:init` first." then **abort**.

## Execution Steps

### 1. Load Spec

1. Read `.claude/afc/specs/{feature}/spec.md` — stop if not found
2. If a `[NEEDS CLARIFICATION]` section exists, process it first
3. Quickly check existing codebase for related patterns

### 2. Scan for Ambiguities

Scan across 10 categories:

| # | Category | What to find |
|---|----------|-------------|
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

### 3. Generate and Present Questions

- Generate at most **5** questions
- Priority: scope > security/privacy > UX > technical
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

- **5-question limit**: If more than 5 questions arise, select only the most important. Resolve the rest during the plan phase.
- **Modify spec only**: Do not touch plan.md or tasks.md.
- **Avoid redundancy**: Do not ask about items already clearly stated in spec.
- **If `$ARGUMENTS` is provided**: Focus the scan on that area.
