---
name: selfish:init
description: "Project initial setup"
argument-hint: "[preset: nextjs-fsd | react-spa | express-api | monorepo]"
disable-model-invocation: true
model: haiku
---

# /selfish:init — Project Initial Setup

> Creates a `.claude/selfish.config.md` configuration file in the current project,
> and injects selfish intent-based routing rules into `~/.claude/CLAUDE.md`.

## Arguments

- `$ARGUMENTS` — (optional) Template preset name (e.g., `nextjs-fsd`)
  - If not specified: analyzes project structure and auto-infers
  - If preset specified: uses `${CLAUDE_PLUGIN_ROOT}/templates/selfish.config.{preset}.md`

## Execution Steps

### 1. Check for Existing Config

If `.claude/selfish.config.md` already exists:
- Ask user: "Config file already exists. Do you want to overwrite it?"
- If declined: **abort**

### 2. Preset Branch

#### A. Preset Specified (`$ARGUMENTS` provided)

1. Verify `${CLAUDE_PLUGIN_ROOT}/templates/selfish.config.{$ARGUMENTS}.md` exists
2. If found: copy that file to `.claude/selfish.config.md`
3. If not found: print "Preset `{$ARGUMENTS}` not found. Available: {list}" then **abort**

#### B. Auto-Infer (`$ARGUMENTS` not provided)

Analyze project structure and auto-infer configuration:

**Step 1. Package Manager / Script Detection**
- Read `package.json` → extract CI-related commands from `scripts` field
- Determine package manager from lockfile (yarn.lock / pnpm-lock.yaml / package-lock.json)
- Reflect detected scripts in `CI Commands` section

**Step 2. Framework Detection**
- Determine from `package.json` dependencies/devDependencies:
  - `next` → Next.js (App Router/Pages Router determined by presence of `app/` directory)
  - `nuxt` → Nuxt
  - `@sveltejs/kit` → SvelteKit
  - `vite` → Vite
  - etc.
- Presence of `tsconfig.json` → TypeScript indicator

**Step 3. Architecture Detection**
- Analyze directory structure:
  - `src/app/`, `src/features/`, `src/entities/`, `src/shared/` → FSD
  - `src/domain/`, `src/application/`, `src/infrastructure/` → Clean Architecture
  - `src/modules/` → Modular
  - Other → Layered
- `paths` in `tsconfig.json` → extract path_alias

**Step 4. State Management Detection**
- From dependencies:
  - `zustand` → Zustand
  - `@reduxjs/toolkit` → Redux Toolkit
  - `@tanstack/react-query` → React Query
  - `swr` → SWR
  - `pinia` → Pinia

**Step 5. Styling / Testing Detection**
- `tailwindcss` → Tailwind CSS
- `styled-components` → styled-components
- `jest` / `vitest` / `playwright` → mapped respectively

**Step 6. Code Style Detection**
- Check `.eslintrc*` / `eslint.config.*` → identify lint rules
- `strict` in `tsconfig.json` → strict_mode
- Read 2-3 existing code samples to verify naming patterns

### 3. Generate Config File

1. Generate config based on `${CLAUDE_PLUGIN_ROOT}/templates/selfish.config.template.md`
2. Fill in blanks with auto-inferred values
3. For items that cannot be inferred: keep template defaults + mark with `# TODO: Adjust for your project`
4. Save to `.claude/selfish.config.md`

### 4. Scan Global CLAUDE.md and Detect Conflicts

Read `~/.claude/CLAUDE.md` and analyze in the following order.

#### Step 1. Check for Existing SELFISH Block

Check for presence of `<!-- SELFISH:START -->` marker.
- If found: replace with latest version (proceed to Step 3)
- If not found: proceed to Step 2

#### Step 2. Conflict Pattern Scan

Search the entire CLAUDE.md for the patterns below. **Include content inside marker blocks (`<!-- *:START -->` ~ `<!-- *:END -->`) in the scan.**

**A. Marker Block Detection**
- Regex: `<!-- ([A-Z0-9_-]+):START -->` ~ `<!-- \1:END -->`
- Record all found block names and line ranges

**B. Agent Routing Conflict Detection**
Find directives containing these keywords:
- `executor`, `deep-executor` — conflicts with selfish:implement
- `code-reviewer`, `quality-reviewer`, `style-reviewer`, `api-reviewer`, `security-reviewer`, `performance-reviewer` — conflicts with selfish:review
- `debugger` (in agent routing context) — conflicts with selfish:debug
- `planner` (in agent routing context) — conflicts with selfish:plan
- `analyst`, `verifier` — conflicts with selfish:analyze
- `test-engineer` — conflicts with selfish:test

**C. Skill Routing Conflict Detection**
Find these patterns:
- Another tool's skill trigger table (e.g., tables like `| situation | skill |`)
- `delegate to`, `route to`, `always use` + agent name combinations
- Directives related to `auto-trigger`, `intent detection`, `intent-based routing`

**D. Legacy selfish Block Detection**
Previous versions without markers:
- `## Selfish Auto-Trigger Rules`
- `## Selfish Pipeline Integration`

#### Step 3. Report Conflicts and User Choice

**No conflicts found** → proceed directly to Step 4

**Conflicts found** → report to user and present options:

```
📋 CLAUDE.md Scan Results
├─ Tool blocks found: {block name list} (lines {range})
├─ Agent routing conflicts: {conflict count}
│   e.g., "executor" (line XX) ↔ selfish:implement
│   e.g., "code-reviewer" (line XX) ↔ selfish:review
└─ Skill routing conflicts: {conflict count}
```

Ask user:

> "Directives overlapping with selfish were found. How would you like to proceed?"
>
> 1. **selfish-exclusive mode** — Adds selfish override comments to conflicting agent routing directives.
>    Does not modify other tools' marker block contents; covers them with override rules in the SELFISH block.
> 2. **coexistence mode** — Ignores conflicts and adds only the selfish block.
>    Since it's at the end of the file, selfish directives will likely take priority, but may be non-deterministic on conflict.
> 3. **manual cleanup** — Shows only the current conflict list and stops.
>    User manually cleans up CLAUDE.md then runs init again.

Based on choice:
- **Option 1**: SELFISH block includes explicit override rules (activates `<conflict-overrides>` section from base template)
- **Option 2**: SELFISH block added without overrides (base template as-is)
- **Option 3**: Print conflict list only and abort without modifying CLAUDE.md

#### Step 4. Inject SELFISH Block

Add the following block at the **very end** of the file (later-positioned directives have higher priority).

Replace existing SELFISH block if present, otherwise append.
If legacy block (`## Selfish Auto-Trigger Rules` etc.) exists, remove it then append.

```markdown
<!-- SELFISH:START -->
<!-- SELFISH:VERSION:1.1.1 -->
<selfish-pipeline>
IMPORTANT: For requests matching the selfish skill routing table below, always invoke the corresponding skill via the Skill tool. Do not substitute with other agents or tools.

## Skill Routing

| Intent | Skill | Trigger Keywords |
|--------|-------|-----------------|
| Implement/Modify | `selfish:implement` | add, modify, refactor, implement |
| Review | `selfish:review` | review, check code, check PR |
| Debug | `selfish:debug` | bug, error, broken, fix |
| Test | `selfish:test` | test, coverage |
| Design | `selfish:plan` | design, plan, how to implement |
| Analyze | `selfish:analyze` | consistency, analyze, validate |
| Spec | `selfish:spec` | spec, specification |
| Tasks | `selfish:tasks` | break down tasks, decompose |
| Research | `selfish:research` | research, investigate |
| Ambiguous | `selfish:clarify` | auto-triggered when requirements are unclear |
| Full auto | `selfish:auto` | do it automatically, auto-run |

User-only (not auto-triggered — inform user on request):
- `selfish:doctor` — inform user when health check is requested
- `selfish:architect` — inform user when architecture review is requested
- `selfish:security` — inform user when security scan is requested

## Pipeline

spec → plan → tasks → implement → review → clean

## Override Rules

NEVER use executor, deep-executor, debugger, planner, analyst, verifier, test-engineer, code-reviewer, quality-reviewer, style-reviewer, api-reviewer, security-reviewer, performance-reviewer for tasks that a selfish skill covers above. ALWAYS invoke the selfish skill instead.
</selfish-pipeline>
<!-- SELFISH:END -->
```

**When Option 1 (selfish-exclusive mode) is selected**, the following `<conflict-overrides>` section is added:

Add the following directly below the Override Rules:

```markdown
## Detected Conflicts

This environment has other agent routing tools that overlap with selfish.
The following rules were auto-generated to resolve conflicts:
- The Skill Routing table above always takes priority over the agent routing directives of {detected tool blocks}
- This block is at the end of the file and therefore has the highest priority
```

### 5. Final Output

```
Selfish Pipeline initialization complete
├─ Config: .claude/selfish.config.md
├─ Framework: {detected framework}
├─ Architecture: {detected style}
├─ Package Manager: {detected manager}
├─ Auto-inferred: {inferred item count}
├─ TODO: {items requiring manual review}
├─ CLAUDE.md: {injected|updated|already current|user aborted}
│   {if conflicts found} └─ Conflict resolution: {selfish-exclusive|coexistence|user cleanup}
└─ Next step: /selfish:spec or /selfish:auto
```

## Notes

- **Overwrite caution**: If config file already exists, always confirm with user.
- **Inference limits**: Auto-inference is best-effort. User may need to review and adjust.
- **Preset path**: Presets are loaded from the `templates/` directory inside the plugin.
- **`.claude/` directory**: Created automatically if it does not exist.
- **Global CLAUDE.md principles**:
  - Never modify content outside the `<!-- SELFISH:START/END -->` markers
  - Never modify content inside other tools' marker blocks (`<!-- *:START/END -->`)
  - Always place the SELFISH block at the very end of the file (ensures priority)
  - Conflict resolution is handled only via override rules (do not delete or modify other blocks)
