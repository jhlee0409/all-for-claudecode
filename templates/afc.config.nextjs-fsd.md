# AFC Configuration

> This file defines project-specific settings for the afc command system.
> All afc commands reference this file to determine project-specific behavior.

## CI Commands

```yaml
ci: "yarn ci"                           # Full CI (lint + typecheck + build)
typecheck: "yarn typecheck"             # Typecheck only
lint: "yarn lint"                       # Lint only
lint_fix: "yarn lint:fix"               # Auto-fix lint
gate: "yarn typecheck && yarn lint"     # Phase gate (run repeatedly during implement)
test: "yarn test"                       # Tests
```

## Architecture

```yaml
style: "FSD"                            # Feature-Sliced Design
layers:                                 # Top → bottom order
  - app
  - views
  - widgets
  - features
  - entities
  - shared
  - core
import_rule: "Upper layers may only import from lower layers (no reverse direction)"
segments:
  - api       # API-related logic (React Query hooks)
  - model     # State management and type definitions
  - ui        # UI components
  - lib       # Utility functions
  - config    # Configuration and constants
  - hooks     # Custom hooks
path_alias: "@/* → ./src/*"
```

## Framework

```yaml
name: "Next.js 14"
runtime: "App Router"
client_directive: "'use client'"
client_directive_rule: >
  Files using client hooks such as useState/useEffect/useRef must
  declare 'use client'. Pay special attention when indirectly imported
  from server components via barrel exports (index.ts).
server_client_boundary: true            # Server/client boundary exists
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
local_state: "Context API (use-context-selector)"
store_location: "model/ segment"
query_location: "api/ segment"
```

## Styling

```yaml
framework: "Tailwind CSS v3"
```

## Testing

```yaml
framework: "Jest + React Testing Library"
```

## Project-Specific Risks

> Project-specific risk patterns that must be checked in the Plan's RISK Critic

1. Missing `'use client'` in barrel export chain → build failure
2. Import order violation (ESLint FSD import order)
3. Circular reference (when using barrel imports inside shared/ui)
4. FSD layer reverse import
5. Residual `as any` → typecheck bypass

## Mini-Review Checklist

> Items to inspect for each file in the Mini-Review of the Implement Phase gate

1. Whether `'use client'` is required (mandatory when using client hooks)
2. FSD layer violations (M violations out of N import paths)
3. Project patterns (`type` vs `interface`, naming, import order)
4. Dead code (unused imports, empty exports, dead code)
