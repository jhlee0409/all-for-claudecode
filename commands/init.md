---
name: afc:init
description: "Project initial setup"
argument-hint: "[preset: nextjs-fsd | react-spa | express-api | monorepo]"
disable-model-invocation: true
model: haiku
---

# /afc:init — Project Initial Setup

> Creates a `.claude/afc.config.md` configuration file in the current project,
> and injects afc intent-based routing rules into `~/.claude/CLAUDE.md`.

## Arguments

- `$ARGUMENTS` — (optional) Template preset name (e.g., `nextjs-fsd`)
  - If not specified: analyzes project structure and auto-infers
  - If preset specified: uses `${CLAUDE_PLUGIN_ROOT}/templates/afc.config.{preset}.md`

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

**D. Git tag migration**
- Check `git tag -l 'selfish/pre-*' 'selfish/phase-*'`
- If any found: rename each tag (`git tag afc/... selfish/... && git tag -d selfish/...`)
- Print: `Migrated: {count} git tags (selfish/* → afc/*)`

### 2. Check for Existing Config

If `.claude/afc.config.md` already exists:
- Ask user: "Config file already exists. Do you want to overwrite it?"
- If declined: **abort**

### 3. Preset Branch

#### A. Preset Specified (`$ARGUMENTS` provided)

1. Verify `${CLAUDE_PLUGIN_ROOT}/templates/afc.config.{$ARGUMENTS}.md` exists
2. If found: copy that file to `.claude/afc.config.md`
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

### 4. Generate Config File

1. Generate config based on `${CLAUDE_PLUGIN_ROOT}/templates/afc.config.template.md`
2. Fill in blanks with auto-inferred values
3. For items that cannot be inferred: keep template defaults + mark with `# TODO: Adjust for your project`
4. Save to `.claude/afc.config.md`

### 5. Scan Global CLAUDE.md and Detect Conflicts

Read `~/.claude/CLAUDE.md` and analyze in the following order.

#### Step 1. Check for Existing AFC or Legacy SELFISH Block

Check for presence of `<!-- AFC:START -->` or `<!-- SELFISH:START -->` marker.
- If `<!-- AFC:START -->` found: replace with latest version (proceed to Step 3)
- If `<!-- SELFISH:START -->` found (legacy v1.x): remove the entire `SELFISH:START` ~ `SELFISH:END` block, then proceed to inject new AFC block at Step 4. Print: `Migrated: SELFISH block → AFC block in ~/.claude/CLAUDE.md`
- If neither found: proceed to Step 2

#### Step 2. Conflict Pattern Scan

Search the entire CLAUDE.md for the patterns below. **Include content inside marker blocks (`<!-- *:START -->` ~ `<!-- *:END -->`) in the scan.**

**A. Marker Block Detection**
- Regex: `<!-- ([A-Z0-9_-]+):START -->` ~ `<!-- \1:END -->`
- Record all found block names and line ranges

**B. Agent Routing Conflict Detection**
Find directives containing these keywords:
- `executor`, `deep-executor` — conflicts with afc:implement
- `code-reviewer`, `quality-reviewer`, `style-reviewer`, `api-reviewer`, `security-reviewer`, `performance-reviewer` — conflicts with afc:review
- `debugger` (in agent routing context) — conflicts with afc:debug
- `planner` (in agent routing context) — conflicts with afc:plan
- `analyst`, `verifier` — conflicts with afc:analyze
- `test-engineer` — conflicts with afc:test

**C. Skill Routing Conflict Detection**
Find these patterns:
- Another tool's skill trigger table (e.g., tables like `| situation | skill |`)
- `delegate to`, `route to`, `always use` + agent name combinations
- Directives related to `auto-trigger`, `intent detection`, `intent-based routing`

**D. Legacy Block Detection**
Previous versions without markers or with old branding:
- `## All-for-ClaudeCode Auto-Trigger Rules`
- `## All-for-ClaudeCode Integration`
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
>    Does not modify other tools' marker block contents; covers them with override rules in the AFC block.
> 2. **coexistence mode** — Ignores conflicts and adds only the afc block.
>    Since it's at the end of the file, afc directives will likely take priority, but may be non-deterministic on conflict.
> 3. **manual cleanup** — Shows only the current conflict list and stops.
>    User manually cleans up CLAUDE.md then runs init again.

Based on choice:
- **Option 1**: AFC block includes explicit override rules (activates `<conflict-overrides>` section from base template)
- **Option 2**: AFC block added without overrides (base template as-is)
- **Option 3**: Print conflict list only and abort without modifying CLAUDE.md

#### Step 4. Inject AFC Block

**Version resolution**: Read `${CLAUDE_PLUGIN_ROOT}/package.json` and extract the `"version"` field. Use this value as `{PLUGIN_VERSION}` in the template below.

Add the following block at the **very end** of the file (later-positioned directives have higher priority).

Replace existing AFC block if present, otherwise append.
If legacy block (`## All-for-ClaudeCode Auto-Trigger Rules` etc.) exists, remove it then append.

```markdown
<!-- AFC:START -->
<!-- AFC:VERSION:{PLUGIN_VERSION} -->
<afc-pipeline>
IMPORTANT: For requests matching the afc skill routing table below, always invoke the corresponding skill via the Skill tool. Do not substitute with other agents or tools.

## Skill Routing

| Intent | Skill | Trigger Keywords |
|--------|-------|-----------------|
| Implement/Modify | `afc:implement` | add, modify, refactor, implement |
| Review | `afc:review` | review, check code, check PR |
| Debug | `afc:debug` | bug, error, broken, fix |
| Test | `afc:test` | test, coverage |
| Design | `afc:plan` | design, plan, how to implement |
| Analyze | `afc:analyze` | consistency, analyze, validate |
| Spec | `afc:spec` | spec, specification |
| Tasks | `afc:tasks` | break down tasks, decompose |
| Research | `afc:research` | research, investigate |
| Ambiguous | `afc:clarify` | auto-triggered when requirements are unclear |
| Full auto | `afc:auto` | do it automatically, auto-run |

User-only (not auto-triggered — inform user on request):
- `afc:doctor` — inform user when health check is requested
- `afc:architect` — inform user when architecture review is requested
- `afc:security` — inform user when security scan is requested
- `afc:checkpoint` — inform user when session save is requested
- `afc:resume` — inform user when session restore is requested
- `afc:principles` — inform user when project principles management is requested

## Pipeline

spec → plan → tasks → implement → review → clean

## Override Rules

NEVER use executor, deep-executor, debugger, planner, analyst, verifier, test-engineer, code-reviewer, quality-reviewer, style-reviewer, api-reviewer, security-reviewer, performance-reviewer for tasks that a afc skill covers above. ALWAYS invoke the afc skill instead.
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
All-for-ClaudeCode initialization complete
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
- **Preset path**: Presets are loaded from the `templates/` directory inside the plugin.
- **`.claude/` directory**: Created automatically if it does not exist.
- **Global CLAUDE.md principles**:
  - Never modify content outside the `<!-- AFC:START/END -->` markers
  - Never modify content inside other tools' marker blocks (`<!-- *:START/END -->`)
  - Always place the AFC block at the very end of the file (ensures priority)
  - Conflict resolution is handled only via override rules (do not delete or modify other blocks)
