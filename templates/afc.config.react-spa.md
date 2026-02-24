# all-for-claudecode Configuration

> This file defines project-specific settings for the afc command system.
> All afc commands reference this file to determine project-specific behavior.

## CI Commands

```yaml
ci: "npm run build && npm run lint && npm run test"  # Full CI (build + lint + test)
typecheck: "npx tsc --noEmit"                        # Typecheck only
lint: "npx eslint src/"                              # Lint only
lint_fix: "npx eslint src/ --fix"                    # Auto-fix lint
gate: "npx tsc --noEmit && npx eslint src/"          # Phase gate (run repeatedly during implement)
test: "npx vitest run"                               # Tests
```

## Architecture

```yaml
style: "Modular"
layers:                                 # Role-based separation structure
  - src/components
  - src/features
  - src/hooks
  - src/lib
  - src/stores
  - src/types
  - src/api
import_rule: "No direct imports between features/ (route via shared)"
segments: []
path_alias: "@/* → ./src/*"
```

## Framework

```yaml
name: "Vite + React 18"
runtime: "SPA (Client-Side)"
client_directive: ""                    # Not needed for SPA
server_client_boundary: false           # No server/client boundary
```

## Code Style

```yaml
language: "TypeScript"
strict_mode: true
type_keyword: "type"                    # Use type instead of interface
import_type: true                       # Use import type { ... }
component_style: "PascalCase"
props_position: "above component"       # Define Props type above the component
handler_naming: "handle[Event]"
boolean_naming: "is/has/can[State]"
constant_naming: "UPPER_SNAKE_CASE"
any_policy: "minimize (comply with strict mode)"
```

## State Management

```yaml
global_state: "Zustand"
server_state: "React Query v5"
local_state: "useState / useReducer"
store_location: "src/stores/"
query_location: "src/api/"
```

## Styling

```yaml
framework: "Tailwind CSS v3"
```

## Testing

```yaml
framework: "Vitest + React Testing Library"
```

## Project-Specific Risks

> Project-specific risk patterns that must be checked in the Plan's RISK Critic

1. Missing environment variables when building with Vite HMR disabled
2. Stale data displayed due to missing React Query cache invalidation
3. Unnecessary re-renders when selectors are not used in Zustand store
4. Mismatch between path alias and Vite resolve.alias

## Mini-Review Checklist

> Items to inspect for each file in the Mini-Review of the Implement Phase gate

1. TypeScript strict mode violations (any, as unknown)
2. Whether import paths use path alias (@/)
3. React hooks rules (no conditional hook calls)
4. Unused imports / dead code
