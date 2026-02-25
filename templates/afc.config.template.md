# Project Configuration

> afc commands reference this file to determine project-specific behavior.
> CI Commands are parsed by scripts — keep the YAML format intact.
> All other sections are free-form markdown — write whatever best describes your project.

## CI Commands

<!-- DO NOT change the format below. Scripts parse these keys. -->
```yaml
ci: "npm run ci"
gate: "npm run typecheck && npm run lint"
test: "npm test"
```

## Architecture

(init analyzes your project and writes this section in free-form)

## Code Style

(init analyzes your project and writes this section in free-form)

## Project Context

(init analyzes your project and writes this section in free-form — framework, state management, styling, testing, risks, etc.)
