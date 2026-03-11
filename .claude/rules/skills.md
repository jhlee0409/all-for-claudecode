---
paths:
  - "skills/**/SKILL.md"
---

# Skill Prompt Rules

Skill files (`skills/<name>/SKILL.md`) define slash commands for the afc pipeline plugin.

## Frontmatter Requirements
Every skill must have YAML frontmatter with:
- `name:` — afc:{skill-name} format
- `description:` — concise English description with trigger phrases: `"Terse label — use when the user [specific trigger phrases]"`. Trigger phrases help the LLM route user intent to the correct skill. Avoid overlapping phrases with other skills.
- `argument-hint:` — usage hint in brackets

## Model Assignment
Every skill should have a `model:` field:
- `sonnet` — all skills (reliable instruction-following for both simple and complex tasks)
- Omit for orchestrators (auto, implement) to inherit parent model

## Invocation Control
- `user-invocable: false` — hidden from / menu, model-only (validate, clarify, tasks)
- `context: fork` — isolated subagent execution (validate, analyze, architect, security)

## Shared References
- Critic Loop rules: reference `docs/critic-loop-rules.md`
- Phase gate protocol: reference `docs/phase-gate-protocol.md`
- Do not duplicate these blocks inline
