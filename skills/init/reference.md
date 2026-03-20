# /afc:init — Detection Reference

## Package Manager Detection

| Lockfile | Package Manager |
|----------|----------------|
| `pnpm-lock.yaml` | pnpm |
| `yarn.lock` | yarn |
| `bun.lockb` or `bun.lock` | bun |
| `package-lock.json` | npm |
| `deno.lock` | deno |

Fallback: check `packageManager` field in `package.json`.
Non-JS: `pyproject.toml` (Python), `Cargo.toml` (Rust), `go.mod` (Go).

## Framework Detection

Determine from `package.json` dependencies/devDependencies:

| Dependency | Framework |
|-----------|-----------|
| `next` | Next.js (App Router if `app/` dir, else Pages Router) |
| `nuxt` | Nuxt |
| `@sveltejs/kit` | SvelteKit |
| `@remix-run/react` | Remix |
| `astro` | Astro |
| `@angular/core` | Angular |
| `vite` (alone) | Vite SPA |
| `hono` | Hono |
| `fastify` | Fastify |
| `express` | Express |

Non-JS: `pyproject.toml` → Django/FastAPI/Flask, `Cargo.toml` → Rust, `go.mod` → Go.
Unlisted: infer from project structure + confirm with user.

## Architecture Detection

| Pattern | Signals |
|---------|---------|
| FSD | `src/` contains ≥3 of: `features/`, `entities/`, `shared/`, `widgets/`, `pages/`, `app/` |
| Clean Architecture | `src/domain/`, `src/application/`, `src/infrastructure/` |
| Modular | `src/modules/` |
| Layered | Default fallback |

Also extract path aliases from `tsconfig.json` `paths`.

## Tool Detection

| Tool | Detection Signal |
|------|-----------------|
| State: zustand/redux/jotai/recoil/pinia/swr/react-query | `package.json` dep |
| Styling: tailwindcss/styled-components/@emotion/sass | `package.json` dep; CSS Modules: `*.module.css` |
| Testing: jest/vitest/playwright/cypress/@testing-library | `package.json` dep |
| Linter: eslint/biome | `.eslintrc*`, `eslint.config.*`, `biome.json` |
| DB/ORM: prisma/drizzle-orm/typeorm | `package.json` dep; prisma: check `prisma/schema.prisma` |
