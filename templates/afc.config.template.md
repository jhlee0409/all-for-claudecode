# AFC Configuration

> This file defines project-specific settings for the afc command system.
> All afc commands reference this file to determine project-specific behavior.
> Modify each section to match your project.

## CI Commands

```yaml
ci: "npm run ci"                        # Full CI (lint + typecheck + build)
typecheck: "npm run typecheck"          # Typecheck only
lint: "npm run lint"                    # Lint only
lint_fix: "npm run lint:fix"            # Auto-fix lint
gate: "npm run typecheck && npm run lint"  # Phase gate (run repeatedly during implement)
test: "npm test"                        # Tests
```

## Architecture

```yaml
style: "Layered"                        # e.g.: FSD, Clean Architecture, Modular Monolith, Layered
layers: []                              # List from top to bottom layer
import_rule: ""                         # Import direction rule (e.g.: "upper → lower only")
segments: []                            # Sub-segments for each layer
path_alias: ""                          # e.g.: "@/* → ./src/*"
```

## Framework

```yaml
name: ""                                # e.g.: Next.js 14, Vite, CRA
runtime: ""                             # e.g.: App Router, Pages Router
client_directive: ""                    # e.g.: 'use client' (leave empty if not applicable)
client_directive_rule: ""               # Rule for applying client directives
server_client_boundary: false           # Whether a server/client boundary exists
```

## Code Style

```yaml
language: "TypeScript"
strict_mode: true
type_keyword: "type"                    # type vs interface
import_type: true                       # Whether to use import type
component_style: "PascalCase"
props_position: "above component"
handler_naming: "handle[Event]"
boolean_naming: "is/has/can[State]"
constant_naming: "UPPER_SNAKE_CASE"
any_policy: "minimize"
```

## State Management

```yaml
global_state: ""                        # e.g.: Zustand, Redux, Pinia
server_state: ""                        # e.g.: React Query, SWR, Apollo
local_state: ""                         # e.g.: Context API, useState
store_location: ""                      # Store file location pattern
query_location: ""                      # Query file location pattern
```

## Styling

```yaml
framework: ""                           # e.g.: Tailwind CSS, styled-components, CSS Modules
```

## Testing

```yaml
framework: ""                           # e.g.: Jest, Vitest, Playwright
```

## Project-Specific Risks

> Project-specific risk patterns that must be checked in the Plan's RISK Critic
> Modify to match your project.

1. (example) Import order violation
2. (example) Circular reference
3. (example) Type safety bypass (as any)

## Mini-Review Checklist

> Items to inspect for each file in the Mini-Review of the Implement Phase gate

1. Architecture rule violations
2. Code style pattern compliance
3. Dead code (unused imports, empty exports, dead code)
