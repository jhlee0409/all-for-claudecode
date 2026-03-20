---
paths:
  - "agents/*.md"
---

# Agent Definition Rules

Agent files (`agents/<name>.md`) define subagents for the afc pipeline plugin.

## Authoring Guide
All agents MUST follow `docs/agent-authoring-guide.md` (single responsibility, tool restrictions, maxTurns, HITL rules, conciseness).

## Frontmatter Requirements
- `name:` — afc-{agent-name} format
- `description:` — when Claude should delegate to this agent (include pipeline phase context)
- `tools:` — explicit list (never omit). Do NOT include `Agent` (subagents cannot spawn subagents)
- `model: sonnet` — default for all agents
- `maxTurns:` — required (expert: 10, scanner: 15-20, worker: 50)

## Memory
- Persistent agents: `memory: project` with 100-line MEMORY.md limit
- Ephemeral workers (impl-worker, pr-analyst): no memory field

## Shared References
- Expert protocol: reference `docs/expert-protocol.md`
- Critic Loop: reference `docs/critic-loop-rules.md`
- Do not duplicate these blocks inline
