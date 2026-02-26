---
paths:
  - "commands/**/*.md"
---

# Command Prompt Rules

Markdown command files define slash commands for the afc pipeline plugin.

## Frontmatter Requirements
Every command must have YAML frontmatter with:
- `name:` — afc:{command-name} format
- `description:` — concise English description
- `argument-hint:` — usage hint in brackets

## Model Assignment
Every command should have a `model:` field:
- `haiku` — mechanical/simple tasks (init, doctor, principles, validate, checkpoint, resume)
- `sonnet` — design/analysis tasks (spec, plan, tasks, clarify, review, research, debug, test, architect, security, analyze)
- Omit for orchestrators (auto, implement) to inherit parent model

## Invocation Control
- `user-invocable: false` — hidden from / menu, model-only (validate, clarify, tasks)
- `context: fork` — isolated subagent execution (validate, analyze, architect, security)

## Shared References
- Critic Loop rules: reference `docs/critic-loop-rules.md`
- Phase gate protocol: reference `docs/phase-gate-protocol.md`
- Do not duplicate these blocks inline
