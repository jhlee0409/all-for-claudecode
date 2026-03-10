# Project Configuration

> CI Commands are parsed by hook scripts — keep the YAML format intact.
> Architecture, Code Style, and Project Context sections below are detailed references.
> A concise summary is also generated in `.claude/rules/afc-project.md` (auto-loaded by Claude Code).

## CI Commands

<!-- DO NOT change the format below. Scripts parse these keys. -->
```yaml
ci: "npm run ci"
gate: "npm run typecheck && npm run lint"
test: "npm test"
tdd: "off"                                # TDD mode: "strict" (block impl without tests), "guide" (warn only), "off" (disabled)
```

## Architecture

(init analyzes your project and writes this section in free-form)

## Code Style

(init analyzes your project and writes this section in free-form)

## Project Context

(init analyzes your project and writes this section in free-form — framework, state management, styling, testing, risks, etc.)
