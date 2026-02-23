---
name: selfish:doctor
description: "Diagnose project health and plugin setup"
argument-hint: "[--verbose]"
disable-model-invocation: true
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
model: haiku
---

# /selfish:doctor — Project Health Diagnosis

> Runs a comprehensive health check on the selfish-pipeline setup for the current project.
> Read-only — never modifies files. Reports issues with actionable fix commands.

## Arguments

- `$ARGUMENTS` — (optional) flags:
  - `--verbose` — detailed output with command results and file paths
  - `--fast` — skip CI/gate command execution checks (faster)

## Output Format

Three-tier status per check:
- `✓` — pass (healthy)
- `⚠` — warning (non-blocking but suboptimal)
- `✗` — fail (broken, needs action)

Each failing check includes a **Fix:** line with the exact command to resolve it.

---

## Checks

Run ALL checks regardless of earlier failures. Do not short-circuit.

### Category 1: Environment

| Check | How | Pass | Fail |
|-------|-----|------|------|
| git installed | `which git` | git found in PATH | Fix: install git |
| jq installed | `which jq` | jq found in PATH | ⚠ Warning: jq not found. Hook scripts will use grep/sed fallback (slower, less reliable). Fix: `brew install jq` or `apt install jq` |

### Category 2: Project Config

| Check | How | Pass | Fail |
|-------|-----|------|------|
| Config file exists | Read `.claude/selfish.config.md` | File exists | Fix: run `/selfish:init` |
| Required sections present | Grep for `## CI Commands`, `## Architecture`, `## Code Style`, `## Framework` | All 4 sections found | Fix: add missing section to `.claude/selfish.config.md` or re-run `/selfish:init` |
| Gate command defined | Grep for `gate:` inside `## CI Commands` section | `gate:` field found | Fix: add `gate:` field to `## CI Commands` section |
| CI command runnable | Extract CI command from config, run it | Exits 0 | ⚠ Warning: CI command failed. Check `{config.ci}` in selfish.config.md |
| Gate command runnable | Extract gate command from config, run it | Exits 0 | ⚠ Warning: gate command failed. Check `{config.gate}` in selfish.config.md |

### Category 3: CLAUDE.md Integration

| Check | How | Pass | Fail |
|-------|-----|------|------|
| Global CLAUDE.md exists | Read `~/.claude/CLAUDE.md` | File exists | ⚠ Warning: no global CLAUDE.md. Selfish skills won't auto-trigger from intent. Fix: run `/selfish:init` |
| SELFISH block present | Grep for `<!-- SELFISH:START -->` and `<!-- SELFISH:END -->` in `~/.claude/CLAUDE.md` | Both markers found | Fix: run `/selfish:init` to inject SELFISH block |
| SELFISH block version | Extract version from `<!-- SELFISH:VERSION:X.Y.Z -->` in CLAUDE.md. Then read `${CLAUDE_PLUGIN_ROOT}/package.json` to get the actual plugin version. Compare the two. | Block version ≥ plugin version | ⚠ Warning: SELFISH block is outdated (found {block_version}, current {plugin_version}). Fix: run `/selfish:init` to update |
| No conflicting routing | Grep for conflicting agent patterns (`executor`, `deep-executor`, `debugger`, `code-reviewer`) outside SELFISH block that could intercept selfish intents | No conflicts or conflicts are inside other tool blocks | ⚠ Warning: found agent routing that may conflict with selfish skills. Review `~/.claude/CLAUDE.md` |

### Category 4: Pipeline State

| Check | How | Pass | Fail |
|-------|-----|------|------|
| No stale pipeline flag | Check `.claude/.selfish-active` | File does not exist (no active pipeline) | ⚠ Warning: stale pipeline flag found (feature: {name}). This may block normal operations. Fix: `rm .claude/.selfish-active .claude/.selfish-phase .claude/.selfish-ci-passed` or run `/selfish:resume` |
| No orphaned artifacts | Glob `.claude/selfish/specs/*/spec.md` | No specs directories, or all are from active pipeline | ⚠ Warning: orphaned `.claude/selfish/specs/{name}/` found. Left over from a previous pipeline. Fix: `rm -rf .claude/selfish/specs/{name}/` |
| No lingering safety tags | `git tag -l 'selfish/pre-*'` | No tags, or tags match active pipeline | ⚠ Warning: lingering safety tag `selfish/pre-{x}` found. Fix: `git tag -d selfish/pre-{x}` |
| Checkpoint state | Read `.claude/selfish/memory/checkpoint.md` if exists | No checkpoint (clean), or checkpoint is from current session | ⚠ Warning: stale checkpoint from {date}. Fix: run `/selfish:resume` to continue or delete `.claude/selfish/memory/checkpoint.md` |

### Category 5: Hook Health

| Check | How | Pass | Fail |
|-------|-----|------|------|
| hooks.json valid | Parse plugin's hooks.json with jq (or manual validation) | Valid JSON with `hooks` key | ✗ Fix: reinstall plugin — `claude plugin install selfish@selfish-pipeline` |
| All scripts exist | For each script referenced in hooks.json, check file exists | All scripts found | ✗ Fix: reinstall plugin |
| Scripts executable | Check execute permission on each script in plugin's scripts/ | All have +x | Fix: `chmod +x` on the missing scripts, or reinstall plugin |

### Category 6: Version Sync (development only)

> Only run if current directory is the selfish-pipeline source repo (check for `package.json` with `"name": "selfish-pipeline"`).

| Check | How | Pass | Fail |
|-------|-----|------|------|
| Version triple match | Compare versions in `package.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (both `metadata.version` and `plugins[0].version`) | All identical | ✗ Fix: update mismatched files to the same version |
| Cache in sync | Compare `commands/auto.md` content between source and `~/.claude/plugins/cache/selfish-pipeline/selfish/{version}/commands/auto.md` | Content matches | ⚠ Warning: plugin cache is stale. Fix: copy source files to cache directory |

---

## Execution

1. Print header:
   ```
   Selfish Pipeline Doctor
   =======================
   ```

2. Run each category in order. For each check:
   - Print `  ✓ {check name}` on pass
   - Print `  ⚠ {check name}: {brief reason}` on warning
   - Print `  ✗ {check name}: {brief reason}` on fail
   - On fail/warning, print `    Fix: {command}` indented below

3. If `--verbose` is in `$ARGUMENTS`:
   - Print additional details for each check (command output, file paths, versions found)

4. Print summary:
   ```
   ─────────────────────────
   Results: {pass} passed, {warn} warnings, {fail} failures
   ```
   - If all pass: `No issues found!`
   - If warnings only: `{N} warnings found. Non-blocking but review recommended.`
   - If any failures: `{N} issues need attention. Run the Fix commands above.`

## Example Output

```
Selfish Pipeline Doctor
=======================

Environment
  ✓ git installed (2.43.0)
  ⚠ jq not found — hook scripts will use grep/sed fallback
    Fix: brew install jq

Project Config
  ✓ .claude/selfish.config.md exists
  ✓ Required sections: ci, gate, architecture, code_style
  ✓ CI command runnable
  ✓ Gate command runnable

CLAUDE.md Integration
  ✓ Global ~/.claude/CLAUDE.md exists
  ✓ SELFISH block present
  ⚠ SELFISH block version outdated (1.0.0 → 1.1.0)
    Fix: /selfish:init
  ✓ No conflicting routing

Pipeline State
  ✓ No stale pipeline flag
  ✓ No orphaned artifacts
  ✓ No lingering safety tags
  ✓ No stale checkpoint

Hook Health
  ✓ hooks.json valid
  ✓ All scripts exist
  ✓ All scripts executable

─────────────────────────
Results: 14 passed, 2 warnings, 0 failures
2 warnings found. Non-blocking but review recommended.
```

## Notes

- **Read-only**: this command never modifies any files. It only reads and reports.
- **Always run all checks**: do not stop on first failure. The full picture is the value.
- **Actionable fixes**: every non-pass result must include a Fix line. Never report a problem without a solution.
- **Fast execution**: skip CI/gate command checks if `--fast` is in arguments (these are the slowest checks).
- **Development checks**: Category 6 (Version Sync) only runs when inside the selfish-pipeline source repo.
