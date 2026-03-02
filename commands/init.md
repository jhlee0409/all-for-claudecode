---
name: afc:init
description: "Project initial setup"
argument-hint: "[additional context]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
model: haiku
---

# /afc:init — Project Initial Setup

> Creates a `.claude/afc.config.md` configuration file in the current project,
> and injects afc intent-based routing rules into `~/.claude/CLAUDE.md`.

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

**Step 3. Architecture Detection**
- Analyze directory structure:
  - FSD: requires **at least 3** of `features/`, `entities/`, `shared/`, `widgets/`, `pages/` under `src/`
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

Reference `${CLAUDE_PLUGIN_ROOT}/templates/afc.config.template.md` for the section structure.
Write sections as natural descriptions — **no YAML code blocks** except for CI Commands.
For items that cannot be inferred: note `TODO: Adjust for your project` inline.
Save to `.claude/afc.config.md`.

### 4.5. Generate Project Profile

Generate `.claude/afc/project-profile.md` for expert consultation agents:

1. Create `.claude/afc/` directory if it does not exist
2. If `.claude/afc/project-profile.md` already exists: skip (do not overwrite)
3. If not exists: generate from the detected project information using `${CLAUDE_PLUGIN_ROOT}/templates/project-profile.template.md` as the structure
   - Fill in Stack, Architecture, and Domain fields from the analysis in Step 3
   - Leave Team, Scale, and Constraints as template placeholders for user to fill
4. Print: `Project profile: .claude/afc/project-profile.md (review and adjust team/scale/domain fields)`

### 5. Scan Global CLAUDE.md and Detect Conflicts

Read `~/.claude/CLAUDE.md` and analyze in the following order.

#### Step 1. Check for Existing all-for-claudecode or Legacy SELFISH Block

Check for presence of `<!-- AFC:START -->` or `<!-- SELFISH:START -->` marker.
- If `<!-- AFC:START -->` found: replace with latest version (proceed to Step 3)
- If `<!-- SELFISH:START -->` found (legacy v1.x): remove the entire `SELFISH:START` ~ `SELFISH:END` block, then proceed to inject new all-for-claudecode block at Step 4. Print: `Migrated: SELFISH block → all-for-claudecode block in ~/.claude/CLAUDE.md`
- If neither found: proceed to Step 2

#### Step 2. Conflict Pattern Scan

Search CLAUDE.md for the patterns below. **IMPORTANT: EXCLUDE content inside any marker blocks (`<!-- *:START -->` ~ `<!-- *:END -->`). Only scan unguarded content outside marker blocks.** Other tools (OMC, etc.) manage their own blocks — their internal agent names are not conflicts.

**A. Marker Block Detection**
- Regex: `<!-- ([A-Z0-9_-]+):START -->` ~ `<!-- \1:END -->`
- Record all found block names and line ranges
- **Strip these ranges from the scan target** — only scan lines NOT inside any marker block

**B. Agent Routing Conflict Detection**
In the **unguarded** (non-marker-block) content only, find directives containing these keywords:
- `executor`, `deep-executor` — conflicts with afc:implement
- `code-reviewer`, `quality-reviewer`, `style-reviewer`, `api-reviewer`, `security-reviewer`, `performance-reviewer` — conflicts with afc:review
- `debugger` (in agent routing context) — conflicts with afc:debug
- `planner` (in agent routing context) — conflicts with afc:plan
- `analyst`, `verifier` — conflicts with afc:validate
- `test-engineer` — conflicts with afc:test

**C. Skill Routing Conflict Detection**
In the **unguarded** content only, find these patterns:
- Another tool's skill trigger table (e.g., tables like `| situation | skill |`)
- `delegate to`, `route to`, `always use` + agent name combinations
- Directives related to `auto-trigger`, `intent detection`, `intent-based routing`

**D. Legacy Block Detection**
Previous versions without markers or with old branding:
- `## all-for-claudecode Auto-Trigger Rules`
- `## all-for-claudecode Integration`
- `<!-- SELFISH:START -->` ~ `<!-- SELFISH:END -->` (v1.x block — should have been caught in Step 1, but double-check here)
- `<selfish-pipeline>` / `</selfish-pipeline>` XML tags

#### Step 3. Report Conflicts and User Choice

**No conflicts found** → proceed directly to Step 4

**Conflicts found** → report to user and present options:

```
📋 CLAUDE.md Scan Results
├─ Tool blocks found: {block name list} (lines {range})
├─ Agent routing conflicts: {conflict count}
│   e.g., "executor" (line XX) ↔ afc:implement
│   e.g., "code-reviewer" (line XX) ↔ afc:review
└─ Skill routing conflicts: {conflict count}
```

Ask user:

> "Directives overlapping with afc were found. How would you like to proceed?"
>
> 1. **afc-exclusive mode** — Adds afc override comments to conflicting agent routing directives.
>    Does not modify other tools' marker block contents; covers them with override rules in the all-for-claudecode block.
> 2. **coexistence mode** — Ignores conflicts and adds only the afc block.
>    Since it's at the end of the file, afc directives will likely take priority, but may be non-deterministic on conflict.
> 3. **manual cleanup** — Shows only the current conflict list and stops.
>    User manually cleans up CLAUDE.md then runs init again.

Based on choice:
- **Option 1**: all-for-claudecode block includes explicit override rules (activates `<conflict-overrides>` section from base template)
- **Option 2**: all-for-claudecode block added without overrides (base template as-is)
- **Option 3**: Print conflict list only and abort without modifying CLAUDE.md

#### Step 4. Inject all-for-claudecode Block

**Version resolution**: Read `${CLAUDE_PLUGIN_ROOT}/package.json` and extract the `"version"` field. Use this value as `{PLUGIN_VERSION}` in the template below.

Add the following block at the **very end** of the file (later-positioned directives have higher priority).

Replace existing all-for-claudecode block if present, otherwise append.
If legacy block (`## all-for-claudecode Auto-Trigger Rules` etc.) exists, remove it then append.

```markdown
<!-- AFC:START -->
<!-- AFC:VERSION:{PLUGIN_VERSION} -->
<afc-pipeline>
IMPORTANT: For requests matching the afc skill routing table below, always invoke the corresponding skill via the Skill tool. Do not substitute with other agents or tools.

## Skill Routing

Classify the user's intent and route to the matching skill. Use semantic understanding — not keyword matching.

| User Intent | Skill | Route When |
|-------------|-------|------------|
| Full lifecycle | `afc:auto` | User wants end-to-end feature development, or the request is a non-trivial new feature without an existing plan |
| Specification | `afc:spec` | User wants to define or write requirements, acceptance criteria, or success conditions |
| Design/Plan | `afc:plan` | User wants to plan HOW to implement before coding — approach, architecture decisions, design |
| Implement | `afc:implement` | User wants specific code changes with a clear scope: add feature, refactor, modify. Requires existing plan or precise instructions |
| Review | `afc:review` | User wants code review, PR review, or quality check on existing/changed code |
| Debug/Fix | `afc:debug` | User reports a bug, error, or broken behavior and wants diagnosis and fix |
| Test | `afc:test` | User wants to write tests, improve coverage, or verify behavior |
| Validate | `afc:validate` | User wants to check consistency or validate existing pipeline artifacts |
| Analyze | `afc:analyze` | User wants to understand, explore, or audit existing code without modifying it |
| QA Audit | `afc:qa` | User wants project quality audit, test confidence check, or runtime quality gaps |
| Research | `afc:research` | User wants deep investigation of external tools, libraries, APIs, or technical concepts |
| Ideate | `afc:ideate` | User wants to brainstorm ideas, explore possibilities, or draft a product brief |
| Consult | `afc:consult` | User wants expert advice on a decision: library choice, architecture direction, legal/security/infra guidance |
| Tasks | `afc:tasks` | User explicitly wants to decompose work into a task breakdown |
| Ambiguous | `afc:clarify` | User's request is too vague or underspecified to route confidently |

### Routing Rules

1. **Auto vs Implement**: A new feature request without an existing plan routes to `afc:auto`. Only use `afc:implement` when the user has a clear, scoped task or an existing plan/spec.
2. **Compound intents**: Route to the primary intent. The pipeline handles sequencing internally.
3. **Design-first**: When scope is non-trivial (multiple files, architectural decisions needed), prefer `afc:auto` or `afc:plan` over direct `afc:implement`.

User-only (not auto-triggered — inform user on request):
- `afc:launch` — inform user when release artifact generation is requested
- `afc:doctor` — inform user when health check is requested
- `afc:architect` — inform user when architecture review is requested
- `afc:security` — inform user when security scan is requested
- `afc:checkpoint` — inform user when session save is requested
- `afc:resume` — inform user when session restore is requested
- `afc:principles` — inform user when project principles management is requested
- `afc:triage` — inform user when parallel PR/issue triage is requested
- `afc:pr-comment` — inform user when posting PR review comments to GitHub is requested
- `afc:release-notes` — inform user when generating release notes from git history is requested

## Pipeline

spec → plan → implement → review → clean

## Override Rules

NEVER use executor, deep-executor, debugger, planner, analyst, verifier, test-engineer, code-reviewer, quality-reviewer, style-reviewer, api-reviewer, security-reviewer, performance-reviewer for tasks that an afc skill covers above. ALWAYS invoke the afc skill instead.

## Source Verification

When analyzing or making claims about external systems, APIs, SDKs, or third-party tools:
- Verify against official documentation, NOT project-internal docs
- Do not hardcode reference data when delegating to sub-agents — instruct them to look up primary sources
- Cross-verify high-severity findings before reporting
</afc-pipeline>
<!-- AFC:END -->
```

**When Option 1 (afc-exclusive mode) is selected**, the following `<conflict-overrides>` section is added:

Add the following directly below the Override Rules:

```markdown
## Detected Conflicts

This environment has other agent routing tools that overlap with afc.
The following rules were auto-generated to resolve conflicts:
- The Skill Routing table above always takes priority over the agent routing directives of {detected tool blocks}
- This block is at the end of the file and therefore has the highest priority
```

### 6. Final Output

```
all-for-claudecode initialization complete
├─ Config: .claude/afc.config.md
├─ Framework: {detected framework}
├─ Architecture: {detected style}
├─ Package Manager: {detected manager}
├─ Auto-inferred: {inferred item count}
├─ TODO: {items requiring manual review}
├─ CLAUDE.md: {injected|updated|already current|user aborted}
│   {if conflicts found} └─ Conflict resolution: {afc-exclusive|coexistence|user cleanup}
└─ Next step: /afc:spec or /afc:auto
```

## Notes

- **Overwrite caution**: If config file already exists, always confirm with user.
- **Inference limits**: Auto-inference is best-effort. User may need to review and adjust.
- **`.claude/` directory**: Created automatically if it does not exist.
- **Global CLAUDE.md principles**:
  - Never modify content outside the `<!-- AFC:START/END -->` markers (the `AFC` prefix in markers is a compact technical identifier)
  - Never modify content inside other tools' marker blocks (`<!-- *:START/END -->`)
  - Always place the all-for-claudecode block at the very end of the file (ensures priority)
  - Conflict resolution is handled only via override rules (do not delete or modify other blocks)
