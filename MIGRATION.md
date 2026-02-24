# Migration Guide

## v2.0 — Rebrand: selfish-pipeline → all-for-claudecode

> all-for-claudecode v2.0 renames the package, plugin prefix, scripts, agents, and state files from `selfish` to `afc`.

### What Changed

| Item | Before (v1.x) | After (v2.0) |
|------|---------------|--------------|
| Package name | `selfish-pipeline` | `all-for-claudecode` |
| Plugin name | `selfish` | `afc` |
| Command prefix | `/selfish:spec` | `/afc:spec` |
| Script prefix | `selfish-*.sh` | `afc-*.sh` |
| Agent names | `selfish-architect`, `selfish-security` | `afc-architect`, `afc-security` |
| State files | `.selfish-active`, `.selfish-phase`, etc. | `.claude/.afc-state.json` (single consolidated file) |
| Config file | `selfish.config.md` | `afc.config.md` |
| Git tags | `selfish/pre-auto` | `afc/pre-auto` |
| CLAUDE.md block | `SELFISH:START` / `SELFISH:END` | `AFC:START` / `AFC:END` |
| Artifact dir | `.claude/selfish/` | `.claude/afc/` |
| GitHub repo | `jhlee0409/selfish-pipeline` | `jhlee0409/all-for-claudecode` |

### Migration Steps

#### 1. Uninstall old plugin

```bash
claude plugin uninstall selfish@selfish-pipeline
claude plugin marketplace remove jhlee0409/selfish-pipeline
```

#### 2. Install new plugin

```bash
npx all-for-claudecode
```

Or manually:

```bash
claude plugin marketplace add jhlee0409/all-for-claudecode
claude plugin install afc@all-for-claudecode --scope user
```

#### 3. Update CLAUDE.md

Replace the `SELFISH:START` / `SELFISH:END` block in your project's CLAUDE.md:

- Change `<!-- SELFISH:START -->` → `<!-- AFC:START -->`
- Change `<!-- SELFISH:END -->` → `<!-- AFC:END -->`
- Change `<!-- SELFISH:VERSION:x.x.x -->` → `<!-- AFC:VERSION:2.0.0 -->`
- Change `<selfish-pipeline>` → `<afc-pipeline>`
- Change all `selfish:` command references → `afc:`
- Change `selfish-architect` / `selfish-security` → `afc-architect` / `afc-security`

Or simply run `/afc:init` to regenerate the block.

#### 4. Migrate state files (if pipeline was active)

v2.0 consolidated multiple state flag files (`.selfish-active`, `.selfish-phase`, `.selfish-ci-passed`, `.selfish-changes.log`) into a single JSON file (`.claude/.afc-state.json`). If you had an active pipeline:

```bash
cd .claude
# Remove old individual flag files
rm -f .selfish-active .selfish-phase .selfish-ci-passed .selfish-changes.log
# Rename directories
[ -d selfish ] && mv selfish afc
[ -f selfish.config.md ] && mv selfish.config.md afc.config.md
# Note: .afc-state.json is created automatically on next pipeline start
```

#### 5. Update git tags

```bash
git tag -d selfish/pre-auto 2>/dev/null
# Phase tags are cleaned up automatically on pipeline end
```

---

## v1.0 — Migration: install.sh → Plugin

> A guide for migrating from the `git clone` + `install.sh` approach to the Claude Code plugin system.

## Summary of Changes

| Item | Before | After |
|------|--------|-------|
| Installation | `git clone` + `./install.sh` | `/plugin install <url>` |
| Command separator | `.` (`/afc-legacy.spec`) | `:` (`/afc:spec`) |
| Command location | `~/.claude/commands/afc-legacy.*.md` | `commands/*.md` inside the plugin |
| Hook scripts | `<project>/.claude/hooks/*.sh` | `scripts/*.sh` inside the plugin |
| Hook config | `<project>/.claude/settings.json` | `hooks/hooks.json` inside the plugin |
| Config file | `.claude/afc.config.md` (unchanged) | `.claude/afc.config.md` (unchanged) |

## Migration Steps

### 1. Clean Up Existing Files

```bash
# Remove existing command files (user level)
rm -f ~/.claude/commands/afc-legacy.*.md

# Remove existing hook scripts (project level)
rm -f .claude/hooks/session-start-context.sh
rm -f .claude/hooks/pre-compact-checkpoint.sh
rm -f .claude/hooks/track-afc-changes.sh
rm -f .claude/hooks/afc-stop-gate.sh
rm -f .claude/hooks/afc-pipeline-manage.sh
```

### 2. Remove legacy hooks from settings.json

Remove afc-related hook entries from `.claude/settings.json`.
Since the plugin registers hooks via its own `hooks.json`, manual configuration in settings.json is no longer needed.

Items to remove (from settings.json):
- `SessionStart` → `session-start-context.sh`
- `PreCompact` → `pre-compact-checkpoint.sh`
- `PostToolUse` → `track-afc-changes.sh`
- `Stop` → `afc-stop-gate.sh`

> If you have other project-specific hooks in settings.json, keep those as they are.

### 3. Install the Plugin

```bash
npx all-for-claudecode
```

Or manually:

```bash
claude plugin marketplace add jhlee0409/all-for-claudecode
claude plugin install afc@all-for-claudecode --scope user
```

The equivalent of `install.sh --commands-only` is the **User** scope; for team sharing, use the **Project** scope.

### 4. Command Name Changes

The separator for all commands has changed from `.` to `:`:

```text
# Before
/afc-legacy.auto "feature description"
/afc-legacy.spec "feature description"
/afc-legacy.plan

# After
/afc:auto "feature description"
/afc:spec "feature description"
/afc:plan
```

### 5. Verify Config File

`.claude/afc.config.md` can be **used as-is without any changes**.

For new projects, you can auto-generate it with `/afc:init`.

## What Stays the Same

- `.claude/afc.config.md` file format and path
- `git tag afc/pre-*` safety tags
- Internal logic of hook scripts
- Pipeline state concept (now consolidated in `.claude/.afc-state.json`)

## What Changed (v1.2.2+)

- `specs/{feature}/` → `.claude/afc/specs/{feature}/`
- `memory/` → `.claude/afc/memory/` (checkpoint, principles, research, decisions)

## FAQ

**Q: Do I need to recreate `.claude/afc.config.md` for existing projects?**
A: No. The config file format is the same. Use it as-is.

**Q: I'm using this across multiple projects. Do I need to migrate each one?**
A: You only need to install the plugin once. For each project, just clean up the existing `.claude/hooks/*.sh` files and legacy hook entries in settings.json.

**Q: Can I use the old version and the plugin at the same time?**
A: This is not recommended. Since the command names differ (`/afc-legacy.spec` vs `/afc:spec`), there are no conflicts, but hooks may get registered twice.
