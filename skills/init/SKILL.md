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

> Creates project-local configuration files (`.claude/afc.config.md`, `.claude/rules/afc-project.md`, `.claude/afc/project-profile.md`).
> **Project-local only** — never touches `~/.claude/CLAUDE.md`. For global routing setup use `/afc:setup`.

## Project State (auto-loaded)
!`ls .claude/afc.config.md .claude/rules/afc-project.md .claude/selfish.config.md .claude/.selfish-* 2>/dev/null | head -20 || echo "[no existing afc files]"`

## Arguments

- `$ARGUMENTS` — (optional) additional context or hints for project analysis

## Execution Steps

### 1. Legacy Migration (v1.x → v2.x)

Detect and migrate `selfish-pipeline` artifacts in one pass:

- `.claude/selfish.config.md` exists, `afc.config.md` does not → rename to `afc.config.md`
- `.claude/.selfish-*` files found → rename each to `.afc-{x}`
- `.claude/selfish/` exists, `.claude/afc/` does not → rename to `.claude/afc/`
- `git tag -l 'selfish/*'` → rename known patterns to `afc/` equivalent, delete the rest

Print a single migration summary line. If nothing to migrate, skip silently.

### 2. Check for Existing Config

If `.claude/afc.config.md` already exists and this is NOT a migration:
- Ask user: "Config file already exists. Overwrite?"
- If declined: **abort**

### 3. Analyze Project Structure

Use `$ARGUMENTS` as additional context. Detection heuristics are in [`reference.md`](./reference.md) — consult it for package manager, framework, architecture, and tool detection tables.

1. Read `package.json` → extract CI scripts, detect package manager from lockfile
2. Detect framework from `package.json` deps
3. Detect architecture from directory structure + `tsconfig.json` paths
4. Detect state/styling/testing/linter/DB tools
5. Read 2–3 code samples to verify naming patterns

> Detection is best-effort. Present results to user for confirmation before writing files.

### 4. Generate Config File

Write `.claude/afc.config.md` based on template at `${CLAUDE_SKILL_DIR}/../../templates/afc.config.template.md`:

1. **CI Commands** — YAML block with `ci`, `gate`, `test` keys (scripts parse this; format is fixed)
2. **Architecture** — detected pattern, layers, import rules, path aliases (free-form prose)
3. **Code Style** — language, strictness, naming, lint rules (free-form prose)
4. **Project Context** — framework, state, styling, testing, DB, risks (free-form prose)

No YAML blocks except CI Commands. Use `TODO: Adjust for your project` for unresolved items.

### 4.5. Generate Project Rules File

Write `.claude/rules/afc-project.md` (auto-loaded by Claude Code for all sub-agents):

1. Create `.claude/rules/` if not present
2. If file exists with `<!-- afc:auto-generated` marker → overwrite silently
3. If file exists without marker → ask user before overwriting
4. Use template `${CLAUDE_SKILL_DIR}/../../templates/afc-project.template.md`
5. First line: `<!-- afc:auto-generated — do not edit manually; regenerate with /afc:init -->`
6. Max 30 lines (excluding marker) — bullets only, no explanations

### 4.6. Generate Project Profile

Write `.claude/afc/project-profile.md` for expert consultation agents:

1. Create `.claude/afc/` if not present
2. If file already exists → skip (do not overwrite)
3. Fill Stack/Architecture/Domain from Step 3 analysis; leave Team/Scale/Constraints as placeholders
4. Use template `${CLAUDE_SKILL_DIR}/../../templates/project-profile.template.md`

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

- **Idempotent**: existing auto-generated rules are silently regenerated; config prompts for confirmation.
- **Inference limits**: Auto-detection is best-effort — review and adjust after generation.
