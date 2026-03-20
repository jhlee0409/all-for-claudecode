# Conflict Detection Reference

## Marker Block Scanning

**Goal:** identify content inside `<!-- *:START --> ... <!-- *:END -->` blocks and exclude it from conflict analysis. Other tools manage their own blocks — only scan *unguarded* (outside-marker) content.

**Algorithm:**
1. Match `<!-- ([A-Z0-9_-]+):START -->` to `<!-- \1:END -->` pairs
2. Record each block name and its line range
3. Remove those line ranges from the scan target

## Agent Routing Conflicts (unguarded content only)

| Keyword | Conflicts with |
|---------|---------------|
| `executor`, `deep-executor` | afc:implement |
| `code-reviewer`, `quality-reviewer`, `style-reviewer`, `api-reviewer`, `security-reviewer`, `performance-reviewer` | afc:review |
| `debugger` (agent routing context) | afc:debug |
| `planner` (agent routing context) | afc:plan |
| `analyst`, `verifier` | afc:validate |
| `test-engineer` | afc:test |

## Skill Routing Conflicts (unguarded content only)

- Skill trigger tables (e.g. `| situation | skill |`)
- `delegate to`, `route to`, `always use` + agent name combinations
- Directives referencing `auto-trigger`, `intent detection`, `intent-based routing`

## Legacy Block Patterns

- `## all-for-claudecode Auto-Trigger Rules`
- `## all-for-claudecode Integration`
- `<selfish-pipeline>` / `</selfish-pipeline>` XML tags
