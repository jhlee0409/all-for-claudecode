---
paths:
  - "commands/**/*.md"
---

# Command Prompt Rules

Markdown command files define slash commands for the selfish pipeline plugin.

## Frontmatter Requirements
Every command must have YAML frontmatter with:
- `name:` — selfish:{command-name} format
- `description:` — concise Korean description
- `argument-hint:` — usage hint in brackets

## Model Assignment
Every command should have a `model:` field:
- `haiku` — mechanical/simple tasks (tasks, clarify, init, principles, analyze, checkpoint, resume)
- `sonnet` — design/analysis tasks (spec, plan, review, research, debug, architect, security)
- Omit for orchestrators (auto, implement) to inherit parent model

## Invocation Control
- `user-invocable: false` — hidden from / menu, model-only (analyze, clarify, tasks)
- `disable-model-invocation: true` — user-only (init, principles, checkpoint, resume, architect, security)
- `context: fork` — isolated subagent execution (analyze, architect, security)

## Shared References
- Critic Loop rules: reference `docs/critic-loop-rules.md`
- Phase gate protocol: reference `docs/phase-gate-protocol.md`
- Do not duplicate these blocks inline
