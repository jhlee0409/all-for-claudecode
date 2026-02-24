# all-for-claudecode Configuration

> This file defines project-specific settings for the afc command system.
> All afc commands reference this file to determine project-specific behavior.

## CI Commands

```yaml
ci: "pnpm turbo build lint test"        # Full CI (lint + typecheck + build)
typecheck: "pnpm turbo typecheck"       # Typecheck only
lint: "pnpm turbo lint"                 # Lint only
lint_fix: "pnpm turbo lint -- --fix"   # Auto-fix lint
gate: "pnpm turbo typecheck lint"       # Phase gate (run repeatedly during implement)
test: "pnpm turbo test"                 # Tests
```

## Architecture

```yaml
style: "Monorepo"
layers:                                 # Root → package order
  - apps/
  - packages/
import_rule: "apps/ may only import from packages/. packages/ must declare explicit dependencies (package.json)"
segments:
  - apps/web       # Web app
  - apps/api       # API server
  - packages/ui    # Shared UI components
  - packages/config   # Shared configuration (ESLint, Prettier, etc.)
  - packages/tsconfig # Shared TypeScript configuration
  - packages/utils    # Shared utilities
path_alias: "@repo/* → packages/*"
```

## Framework

```yaml
name: "Turborepo + pnpm workspace"
runtime: "Multiple (varies per app)"
client_directive: "Varies per app"
server_client_boundary: "Varies per app"    # Determined by each app's framework
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
any_policy: "minimize (especially strict for shared packages)"
```

## State Management

```yaml
global_state: "Varies per app"
server_state: "Varies per app"
local_state: "Varies per app"
store_location: "Within each app"
query_location: "Within each app"
```

## Styling

```yaml
framework: "Varies per app (shared UI package uses Tailwind CSS)"
```

## Testing

```yaml
framework: "Varies per app (Vitest or Jest)"
```

## Project-Specific Risks

> Project-specific risk patterns that must be checked in the Plan's RISK Critic

1. Circular dependencies between packages (turborepo detects, but runtime errors possible)
2. Build failures in dependent apps when shared packages change
3. npm publish errors when pnpm workspace protocol (workspace:*) is missing
4. tsconfig inheritance chain mismatch (extends path errors)
5. Stale builds due to incorrect pipeline cache settings in turbo.json

## Mini-Review Checklist

> Items to inspect for each file in the Mini-Review of the Implement Phase gate

1. Dependency direction between packages (apps → packages only)
2. Shared package export paths (package.json exports field)
3. TypeScript strict mode + path alias consistency
4. turbo.json pipeline configuration matches actual scripts
