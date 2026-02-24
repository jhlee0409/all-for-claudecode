# Development Rules

When adding or modifying features in all-for-claudecode, follow these rules.

## Change Impact Matrix

Before making changes, identify the blast radius:

- **Command change** → also update: auto.md (if pipeline phase), CLAUDE.md (counts), init.md all-for-claudecode block (if routing changed)
- **Hook script change** → also update: tests/test-hooks.sh (mandatory), hooks.json (if new event)
- **Shared doc change** (critic-loop-rules.md, phase-gate-protocol.md) → affects ALL commands that reference it
- **Version change** → must sync: package.json + plugin.json + marketplace.json (all 3)

## Mandatory Before Commit

1. `npm run test:all` must pass
2. No Korean text in tracked files: `git diff --cached --name-only | xargs grep -l '[가-힣]' 2>/dev/null` should return empty
3. New shell scripts must have: `set -euo pipefail`, `trap cleanup EXIT`, jq-first parsing
4. New shell scripts must have test coverage in tests/test-hooks.sh

## Plugin Cache

Source changes don't take effect until synced to cache during development:
```bash
cp commands/{file}.md ~/.claude/plugins/cache/all-for-claudecode/afc/$(jq -r .version package.json)/commands/{file}.md
```

## Command Design Rules

- model: haiku (mechanical) | sonnet (analysis/design) | omit (orchestrators inherit parent)
- Never duplicate docs/critic-loop-rules.md or docs/phase-gate-protocol.md inline — always reference
- Orchestration modes (sequential/batch/swarm) are selected automatically by task count — do not hardcode
- All output text must be in English (global open-source project)

## Full Guidelines

Read `CONTRIBUTING.md` for comprehensive development guidelines including: new command checklist, hook script template, testing patterns, version sync, and release process.
