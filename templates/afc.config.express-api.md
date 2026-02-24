# AFC Configuration

> This file defines project-specific settings for the afc command system.
> All afc commands reference this file to determine project-specific behavior.

## CI Commands

```yaml
ci: "npm run build && npm run lint && npm run test"  # Full CI (build + lint + test)
typecheck: "npx tsc --noEmit"                        # Typecheck only
lint: "npx eslint src/"                              # Lint only
lint_fix: "npx eslint src/ --fix"                    # Auto-fix lint
gate: "npx tsc --noEmit && npx eslint src/"          # Phase gate (run repeatedly during implement)
test: "npx jest --runInBand"                         # Tests
```

## Architecture

```yaml
style: "Layered"                        # Layered architecture
layers:                                 # Top → bottom order
  - src/routes
  - src/controllers
  - src/services
  - src/repositories
  - src/models
  - src/middleware
  - src/lib
  - src/types
  - src/config
import_rule: "Upper layers (routes) depend only in order: controllers → services → repositories"
segments: []
path_alias: "@/* → ./src/*"
```

## Framework

```yaml
name: "Express.js"
runtime: "Node.js (CommonJS or ESM)"
client_directive: ""                    # Server-only — not applicable
server_client_boundary: false           # Server-only application
```

## Code Style

```yaml
language: "TypeScript"
strict_mode: true
type_keyword: "type"                    # Use type instead of interface
import_type: true                       # Use import type { ... }
component_style: ""                     # No UI components
props_position: ""                      # No UI components
handler_naming: "camelCase"
boolean_naming: "is/has/can[State]"
constant_naming: "UPPER_SNAKE_CASE"
any_policy: "banned (use unknown with strict mode)"
```

## State Management

```yaml
global_state: ""                        # Server — stateless
server_state: ""
local_state: ""
store_location: ""
query_location: ""
```

## Styling

```yaml
framework: ""                           # Not applicable
```

## Testing

```yaml
framework: "Jest + Supertest"
```

## Project-Specific Risks

> Project-specific risk patterns that must be checked in the Plan's RISK Critic

1. Prisma migration and schema mismatch
2. Express middleware ordering errors (auth → validation → handler)
3. Missing async/await error handling (try-catch or wrapper)
4. Runtime errors when environment variables (.env) are not set
5. SQL injection (caution with raw queries when using Prisma)

## Mini-Review Checklist

> Items to inspect for each file in the Mini-Review of the Implement Phase gate

1. TypeScript strict mode violations
2. Error handling (try-catch or asyncHandler on async routes)
3. Input validation (type checking of req.body/params/query)
4. Unused imports / dead code
