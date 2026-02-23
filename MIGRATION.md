# Migration Guide: install.sh → Plugin

> A guide for migrating from the `git clone` + `install.sh` approach to the Claude Code plugin system.

## Summary of Changes

| Item | Before | After |
|------|--------|-------|
| Installation | `git clone` + `./install.sh` | `/plugin install <url>` |
| Command separator | `.` (`/selfish.spec`) | `:` (`/selfish:spec`) |
| Command location | `~/.claude/commands/selfish.*.md` | `commands/*.md` inside the plugin |
| Hook scripts | `<project>/.claude/hooks/*.sh` | `scripts/*.sh` inside the plugin |
| Hook config | `<project>/.claude/settings.json` | `hooks/hooks.json` inside the plugin |
| Config file | `.claude/selfish.config.md` (unchanged) | `.claude/selfish.config.md` (unchanged) |

## Migration Steps

### 1. Clean Up Existing Files

```bash
# Remove existing command files (user level)
rm -f ~/.claude/commands/selfish.*.md

# Remove existing hook scripts (project level)
rm -f .claude/hooks/session-start-context.sh
rm -f .claude/hooks/pre-compact-checkpoint.sh
rm -f .claude/hooks/track-selfish-changes.sh
rm -f .claude/hooks/selfish-stop-gate.sh
rm -f .claude/hooks/selfish-pipeline-manage.sh
```

### 2. Remove selfish hooks from settings.json

Remove selfish-related hook entries from `.claude/settings.json`.
Since the plugin registers hooks via its own `hooks.json`, manual configuration in settings.json is no longer needed.

Items to remove (from settings.json):
- `SessionStart` → `session-start-context.sh`
- `PreCompact` → `pre-compact-checkpoint.sh`
- `PostToolUse` → `track-selfish-changes.sh`
- `Stop` → `selfish-stop-gate.sh`

> If you have other project-specific hooks in settings.json, keep those as they are.

### 3. Install the Plugin

```bash
npx selfish-pipeline
```

Or manually:

```bash
claude plugin marketplace add jhlee0409/selfish-pipeline
claude plugin install selfish@selfish-pipeline --scope user
```

The equivalent of `install.sh --commands-only` is the **User** scope; for team sharing, use the **Project** scope.

### 4. Command Name Changes

The separator for all commands has changed from `.` to `:`:

```text
# Before
/selfish.auto "feature description"
/selfish.spec "feature description"
/selfish.plan

# After
/selfish:auto "feature description"
/selfish:spec "feature description"
/selfish:plan
```

### 5. Verify Config File

`.claude/selfish.config.md` can be **used as-is without any changes**.

For new projects, you can auto-generate it with `/selfish:init`.

## What Stays the Same

- `.claude/selfish.config.md` file format and path
- `.claude/selfish/specs/{feature}/` artifact paths
- `.claude/selfish/memory/` references (checkpoint, principles, research, decisions)
- `.selfish-*` state file paths
- `git tag selfish/pre-*` safety tags
- Internal logic of hook scripts

## FAQ

**Q: Do I need to recreate `.claude/selfish.config.md` for existing projects?**
A: No. The config file format is the same. Use it as-is.

**Q: I'm using this across multiple projects. Do I need to migrate each one?**
A: You only need to install the plugin once. For each project, just clean up the existing `.claude/hooks/*.sh` files and selfish hook entries in settings.json.

**Q: Can I use the old version and the plugin at the same time?**
A: This is not recommended. Since the command names differ (`/selfish.spec` vs `/selfish:spec`), there are no conflicts, but hooks may get registered twice.
