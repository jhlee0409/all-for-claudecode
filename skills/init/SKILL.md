---
name: afc:init
description: "Project initial setup — use when the user asks to set up the project, initialize afc, configure the plugin, or detect the tech stack"
argument-hint: "[additional context]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
model: sonnet
---

# /afc:init — Project Initial Setup

> Creates project-local configuration files for the all-for-claudecode plugin.
> Analyzes the project structure and generates config, rules, and profile.
> This is a **project-local** operation — it only creates files under `.claude/`.
> For global `~/.claude/CLAUDE.md` setup, use `/afc:setup` instead.

## Important

This skill is a **prompt-only skill** — there is NO `afc-init.sh` script.
All steps below are instructions for the LLM to execute directly using its allowed tools (Read, Write, Bash, Glob).
Do NOT attempt to run a shell script for this skill.

## Arguments

- `$ARGUMENTS` — (optional) Additional context or hints for project analysis

## Execution Steps

### 1. Legacy Migration Check

Before anything else, detect and migrate v1.x (selfish-pipeline) artifacts:

**A. Config file migration**
- If `.claude/selfish.config.md` exists AND `.claude/afc.config.md` does NOT exist:
  - Rename: `mv .claude/selfish.config.md .claude/afc.config.md`
  - Print: `Migrated: selfish.config.md → afc.config.md`
- If both exist: print warning, keep `afc.config.md`, skip migration

**B. State file migration**
- Glob `.claude/.selfish-*` — if any found:
  - Rename each: `.selfish-{x}` → `.afc-{x}`
  - Print: `Migrated: {count} state files (.selfish-* → .afc-*)`

**C. Artifact directory migration**
- If `.claude/selfish/` exists AND `.claude/afc/` does NOT exist:
  - Rename: `mv .claude/selfish .claude/afc`
  - Print: `Migrated: .claude/selfish/ → .claude/afc/`

**D. Git tag cleanup**
- Check `git tag -l 'selfish/*'`
- If any found:
  - Known patterns (`selfish/pre-*`, `selfish/phase-*`): rename to `afc/` equivalent (`git tag afc/... selfish/... && git tag -d selfish/...`)
  - All remaining `selfish/*`: delete (`git tag -d`)
- Print: `Migrated: {renamed} renamed, {deleted} deleted`

### 2. Check for Existing Config

If `.claude/afc.config.md` already exists:
- Ask user: "Config file already exists. Do you want to overwrite it?"
- If declined: **abort**

### 3. Analyze Project Structure

Analyze the project and auto-infer configuration. Use `$ARGUMENTS` as additional context if provided.

**Step 1. Package Manager / Script Detection**
- Read `package.json` → extract CI-related commands from `scripts` field
- Determine package manager from lockfile:

| Lockfile | Package Manager |
|----------|----------------|
| `pnpm-lock.yaml` | pnpm |
| `yarn.lock` | yarn |
| `bun.lockb` or `bun.lock` | bun |
| `package-lock.json` | npm |

- If no lockfile: check `packageManager` field in `package.json`
- Non-JS projects: check `pyproject.toml` (Python), `Cargo.toml` (Rust), `go.mod` (Go)

> These detection rules are starting-point heuristics, not definitive. If a project uses a tool not listed here, the model should still detect it from context (e.g., `bun.lockb` for Bun, `deno.lock` for Deno). Always confirm the detected setup with the user before proceeding.

**Step 2. Framework Detection**
- Determine from `package.json` dependencies/devDependencies:

| Dependency | Framework |
|-----------|-----------|
| `next` | Next.js (App Router if `app/` dir exists, else Pages Router) |
| `nuxt` | Nuxt |
| `@sveltejs/kit` | SvelteKit |
| `@remix-run/react` | Remix |
| `astro` | Astro |
| `@angular/core` | Angular |
| `vite` (alone) | Vite SPA |
| `hono` | Hono |
| `fastify` | Fastify |
| `express` | Express |

- Non-JS: `pyproject.toml` → Django/FastAPI/Flask, `Cargo.toml` → Rust project, `go.mod` → Go project
- Presence of `tsconfig.json` → TypeScript indicator

> This list covers common frameworks but is not exhaustive. For unlisted frameworks, infer from package.json dependencies, project structure, and configuration files. Present the detection result to the user for confirmation.

**Step 3. Architecture Detection**
- Analyze directory structure:
  - FSD: If the project's src/ directory contains a combination of FSD-characteristic directories (`features/`, `entities/`, `shared/`, `widgets/`, `pages/`, `processes/`, `app/`), assess whether the project follows FSD principles. Variant FSD structures (e.g., using `processes/` instead of `pages/`) should also be detected. Confirm with the user if the detection is uncertain.
  - `src/domain/`, `src/application/`, `src/infrastructure/` → Clean Architecture
  - `src/modules/` → Modular
  - Other → Layered
- `paths` in `tsconfig.json` → extract path alias

**Step 4. State / Styling / Testing / DB Detection**
- State management: `zustand`, `@reduxjs/toolkit`, `@tanstack/react-query`, `swr`, `pinia`, `jotai`, `recoil`
- Styling: `tailwindcss`, `styled-components`, `@emotion/react`, `sass`, CSS Modules (check for `*.module.css`)
- Testing: `jest`, `vitest`, `playwright`, `@testing-library/*`, `cypress`
- Linter: `.eslintrc*` / `eslint.config.*` / `biome.json` / `biome.jsonc`
- DB/ORM: `prisma` (check `prisma/schema.prisma`), `drizzle-orm`, `typeorm`, `@prisma/client`

**Step 5. Code Style Detection**
- Check linter config → identify key rules
- `strict` in `tsconfig.json` → strict mode
- Read 2-3 existing code samples to verify naming patterns

### 4. Generate Config File

Generate `.claude/afc.config.md` in **free-form markdown** format:

1. **CI Commands** section: YAML code block with `ci`, `gate`, `test` keys (fixed format, scripts parse these)
2. **Architecture** section: describe detected architecture style, layers, import rules, path aliases in free-form prose/lists
3. **Code Style** section: describe detected language, strictness, naming conventions, lint rules in free-form prose/lists
4. **Project Context** section: describe framework, state management, styling, testing, DB/ORM, risks, and any other relevant project characteristics in free-form prose/lists

Reference `${CLAUDE_SKILL_DIR}/../../templates/afc.config.template.md` for the section structure.
Write sections as natural descriptions — **no YAML code blocks** except for CI Commands.
For items that cannot be inferred: note `TODO: Adjust for your project` inline.
Save to `.claude/afc.config.md`.

### 4.5. Generate Project Rules File

Generate `.claude/rules/afc-project.md` — a concise summary of project rules that Claude Code auto-loads for all conversations and sub-agents.

1. Create `.claude/rules/` directory if it does not exist
2. If `.claude/rules/afc-project.md` already exists:
   - If it contains `<!-- afc:auto-generated` marker: overwrite silently (auto-generated file, safe to regenerate)
   - If it does NOT contain the marker: ask user "Project rules file exists (user-managed). Overwrite with auto-generated version?" — skip if declined
3. Reference `${CLAUDE_SKILL_DIR}/../../templates/afc-project.template.md` for section structure
4. Fill in from the analysis performed in Step 3:
   - **Architecture**: pattern, key layers, import rules, path alias — concise bullet points
   - **Code Style**: language, naming conventions, lint rules — concise bullet points
   - **Project Context**: framework, state management, styling, testing, DB/ORM — concise bullet points
5. Include `<!-- afc:auto-generated — do not edit manually; regenerate with /afc:init -->` as the first line
6. Keep total length **under 30 lines** (excluding the marker comment) — rules only, no explanations
7. Save to `.claude/rules/afc-project.md`
8. Print: `Project rules: .claude/rules/afc-project.md (auto-loaded by Claude Code)`

### 4.6. Generate Project Profile

Generate `.claude/afc/project-profile.md` for expert consultation agents:

1. Create `.claude/afc/` directory if it does not exist
2. If `.claude/afc/project-profile.md` already exists: skip (do not overwrite)
3. If not exists: generate from the detected project information using `${CLAUDE_SKILL_DIR}/../../templates/project-profile.template.md` as the structure
   - Fill in Stack, Architecture, and Domain fields from the analysis in Step 3
   - Leave Team, Scale, and Constraints as template placeholders for user to fill
4. Print: `Project profile: .claude/afc/project-profile.md (review and adjust team/scale/domain fields)`

### 5. Final Output

```
all-for-claudecode project init complete
├─ Config: .claude/afc.config.md
├─ Rules: .claude/rules/afc-project.md (auto-loaded)
├─ Profile: .claude/afc/project-profile.md
├─ Framework: {detected framework}
├─ Architecture: {detected style}
├─ Package Manager: {detected manager}
├─ Auto-inferred: {inferred item count}
├─ TODO: {items requiring manual review}
└─ Next step: /afc:setup (global routing) or /afc:auto (start building)
```

## Notes

- **Idempotent**: safe to run multiple times. Existing config prompts for overwrite confirmation; auto-generated rules are silently regenerated.
- **Project-local only**: this skill only creates files under `.claude/`. It never touches `~/.claude/CLAUDE.md`. For global routing setup, use `/afc:setup`.
- **Overwrite caution**: If config file already exists, always confirm with user.
- **Inference limits**: Auto-inference is best-effort. User may need to review and adjust.
- **`.claude/` directory**: Created automatically if it does not exist.
