---
name: afc:doctor
description: "Diagnose project health and plugin setup"
argument-hint: "[--verbose]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
model: haiku
---

# /afc:doctor — Project Health Diagnosis

> Runs a comprehensive health check on the all-for-claudecode setup for the current project.
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
| Config file exists | Read `.claude/afc.config.md` | File exists | Fix: run `/afc:init` |
| Required sections present | Grep for `## CI Commands`, `## Architecture`, `## Code Style` | All 3 sections found | Fix: add missing section to `.claude/afc.config.md` or re-run `/afc:init` |
| Gate command defined | Grep for `gate:` inside `## CI Commands` section | `gate:` field found | Fix: add `gate:` field to `## CI Commands` section |
| CI command runnable | Extract CI command from config, run it | Exits 0 | ⚠ Warning: CI command failed. Check `{config.ci}` in afc.config.md |
| Gate command runnable | Extract gate command from config, run it | Exits 0 | ⚠ Warning: gate command failed. Check `{config.gate}` in afc.config.md |

### Category 3: CLAUDE.md Integration

| Check | How | Pass | Fail |
|-------|-----|------|------|
| Global CLAUDE.md exists | Read `~/.claude/CLAUDE.md` | File exists | ⚠ Warning: no global CLAUDE.md. all-for-claudecode skills won't auto-trigger from intent. Fix: run `/afc:init` |
| all-for-claudecode block present | Grep for `<!-- AFC:START -->` and `<!-- AFC:END -->` in `~/.claude/CLAUDE.md` | Both markers found | Fix: run `/afc:init` to inject all-for-claudecode block |
| all-for-claudecode block version | Extract version from `<!-- AFC:VERSION:X.Y.Z -->` in CLAUDE.md. Read `${CLAUDE_PLUGIN_ROOT}/package.json` (`.version`) to get the actual plugin version. Compare the two. | Block version = plugin version | ⚠ Warning: all-for-claudecode block is outdated (found {block_version}, current {plugin_version}). Fix: run `/afc:init` to update |
| No conflicting routing | Grep for conflicting agent patterns (`executor`, `deep-executor`, `debugger`, `code-reviewer`) outside all-for-claudecode block that could intercept afc intents | No conflicts or conflicts are inside other tool blocks | ⚠ Warning: found agent routing that may conflict with afc skills. Review `~/.claude/CLAUDE.md` |

### Category 4: Legacy Migration (v1.x → v2.0)

> Detects leftover artifacts from the old `selfish-pipeline` (v1.x) plugin. If none found, print `✓ No legacy artifacts` and skip this category.

| Check | How | Pass | Fail |
|-------|-----|------|------|
| No legacy CLAUDE.md block | Grep `~/.claude/CLAUDE.md` for `<!-- SELFISH:START -->` | Marker not found | ⚠ Warning: legacy `SELFISH:START` block found in `~/.claude/CLAUDE.md`. Fix: run `/afc:init` (will replace with all-for-claudecode block) |
| No legacy config file | Check `.claude/selfish.config.md` | File does not exist | ⚠ Warning: legacy config `.claude/selfish.config.md` found. Fix: `mv .claude/selfish.config.md .claude/afc.config.md` |
| No legacy state files | Glob `.claude/.selfish-*` | No files found | ⚠ Warning: legacy state files `.claude/.selfish-*` found. Fix: `cd .claude && for f in .selfish-*; do mv "$f" "${f/.selfish-/.afc-}"; done` |
| No legacy artifact dir | Check `.claude/selfish/` directory | Directory does not exist | ⚠ Warning: legacy artifact directory `.claude/selfish/` found. Fix: `mv .claude/selfish .claude/afc` |
| No legacy git tags | `git tag -l 'selfish/pre-*' 'selfish/phase-*'` | No tags found | ⚠ Warning: legacy git tags found. Fix: `git tag -l 'selfish/*' \| xargs git tag -d` |
| No legacy plugin installed | Check if `selfish@selfish-pipeline` appears in installed plugins (grep settings.json for `selfish-pipeline`) | Not found | ⚠ Warning: old `selfish-pipeline` plugin still installed. Fix: `claude plugin uninstall selfish@selfish-pipeline && claude plugin marketplace remove jhlee0409/selfish-pipeline` |

### Category 5: Pipeline State

| Check | How | Pass | Fail |
|-------|-----|------|------|
| No stale pipeline state | Check `.claude/.afc-state.json` via `afc-pipeline-manage.sh status` | File does not exist (no active pipeline) | ⚠ Warning: stale pipeline state found (feature: {name}, phase: {phase}). This may block normal operations. Fix: `"${CLAUDE_PLUGIN_ROOT}/scripts/afc-pipeline-manage.sh" end --force` or run `/afc:resume` |
| No orphaned artifacts | Glob `.claude/afc/specs/*/spec.md` | No specs directories, or all are from active pipeline | ⚠ Warning: orphaned `.claude/afc/specs/{name}/` found. Left over from a previous pipeline. Fix: `rm -rf .claude/afc/specs/{name}/` |
| No lingering safety tags | `git tag -l 'afc/pre-*'` | No tags, or tags match active pipeline | ⚠ Warning: lingering safety tag `afc/pre-{x}` found. Fix: `git tag -d afc/pre-{x}` |
| Checkpoint state | Read `.claude/afc/memory/checkpoint.md` if exists | No checkpoint (clean), or checkpoint is from current session | ⚠ Warning: stale checkpoint from {date}. Fix: run `/afc:resume` to continue or delete `.claude/afc/memory/checkpoint.md` |

### Category 6: Memory Health

> Checks `.claude/afc/memory/` subdirectory sizes and agent memory file sizes. If memory directory does not exist, print `✓ No memory directory` and skip this category.

| Check | How | Pass | Fail |
|-------|-----|------|------|
| quality-history count | Count files in `.claude/afc/memory/quality-history/` | ≤ 30 files | ⚠ Warning: {N} files in quality-history/ (threshold: 30). Oldest files should be pruned. Fix: run a pipeline with `/afc:auto` (Clean phase auto-prunes) or manually delete oldest files |
| reviews count | Count files in `.claude/afc/memory/reviews/` | ≤ 40 files | ⚠ Warning: {N} files in reviews/ (threshold: 40). Fix: run a pipeline or manually delete oldest files |
| retrospectives count | Count files in `.claude/afc/memory/retrospectives/` | ≤ 30 files | ⚠ Warning: {N} files in retrospectives/ (threshold: 30). Fix: run a pipeline or manually delete oldest files |
| research count | Count files in `.claude/afc/memory/research/` | ≤ 50 files | ⚠ Warning: {N} files in research/ (threshold: 50). Fix: run a pipeline or manually delete oldest files |
| decisions count | Count files in `.claude/afc/memory/decisions/` | ≤ 60 files | ⚠ Warning: {N} files in decisions/ (threshold: 60). Fix: run a pipeline or manually delete oldest files |
| afc-architect MEMORY.md size | Count lines in `.claude/agent-memory/afc-architect/MEMORY.md` (if exists) | ≤ 100 lines | ⚠ Warning: afc-architect MEMORY.md is {N} lines (limit: 100). Fix: invoke `/afc:architect` to trigger self-pruning, or manually edit the file |
| afc-security MEMORY.md size | Count lines in `.claude/agent-memory/afc-security/MEMORY.md` (if exists) | ≤ 100 lines | ⚠ Warning: afc-security MEMORY.md is {N} lines (limit: 100). Fix: invoke `/afc:security` to trigger self-pruning, or manually edit the file |

### Category 7: Hook Health

| Check | How | Pass | Fail |
|-------|-----|------|------|
| hooks.json valid | Parse plugin's hooks.json with jq (or manual validation) | Valid JSON with `hooks` key | ✗ Fix: reinstall plugin — `claude plugin install afc@all-for-claudecode` |
| All scripts exist | For each script referenced in hooks.json, check file exists | All scripts found | ✗ Fix: reinstall plugin |
| Scripts executable | Check execute permission on each script in plugin's scripts/ | All have +x | Fix: `chmod +x` on the missing scripts, or reinstall plugin |

### Category 8: Version Sync (development only)

> Only run if current directory is the all-for-claudecode source repo (check for `package.json` with `"name": "all-for-claudecode"`).

| Check | How | Pass | Fail |
|-------|-----|------|------|
| Version triple match | Compare versions in `package.json` (`.version`), `.claude-plugin/plugin.json` (`.version`), `.claude-plugin/marketplace.json` (`.metadata.version` and `.plugins[0].version`) | All identical | ✗ Fix: update mismatched files to the same version |
| Cache in sync | Compare `commands/auto.md` content between source and `~/.claude/plugins/cache/all-for-claudecode/afc/{version}/commands/auto.md` | Content matches | ⚠ Warning: plugin cache is stale. Fix: copy source files to cache directory |

### Category 9: Command Definitions (development only)

> Only run if current directory is the all-for-claudecode source repo (same condition as Category 8).

| Check | How | Pass | Fail |
|-------|-----|------|------|
| Frontmatter exists | Each `commands/*.md` file has opening and closing `---` block | All files have frontmatter | ✗ Fix: add YAML frontmatter block to `commands/{file}.md` |
| Required fields | Each command frontmatter contains `name:` and `description:` | All files have both fields | ✗ Fix: add missing `name:` or `description:` to `commands/{file}.md` |
| Name-filename match | `name:` value follows `afc:{filename}` pattern (e.g. `auto.md` → `name: afc:auto`) | All names match filenames | ✗ Fix: rename `name:` field in `commands/{file}.md` to `afc:{filename}` |
| Fork-agent reference | Commands with `context: fork` and `agent:` field reference a file that exists in `agents/` (e.g. `agent: afc-architect` → `agents/afc-architect.md` exists) | All agent references resolve | ✗ Fix: create missing agent file `agents/{name}.md` or fix `agent:` field in `commands/{file}.md` |

### Category 10: Agent Definitions (development only)

> Only run if current directory is the all-for-claudecode source repo (same condition as Category 8).

| Check | How | Pass | Fail |
|-------|-----|------|------|
| Frontmatter exists | Each `agents/*.md` file has opening and closing `---` block | All files have frontmatter | ✗ Fix: add YAML frontmatter block to `agents/{file}.md` |
| Required fields | Each agent frontmatter contains `name:`, `description:`, and `model:` | All files have all 3 fields | ✗ Fix: add missing field to `agents/{file}.md` |
| Name-filename match | `name:` value equals the filename without extension (e.g. `afc-architect.md` → `name: afc-architect`) | All names match filenames | ✗ Fix: rename `name:` field in `agents/{file}.md` to match filename |
| Expert memory | All 8 expert consultation agents (`afc-backend-expert`, `afc-infra-expert`, `afc-pm-expert`, `afc-design-expert`, `afc-marketing-expert`, `afc-legal-expert`, `afc-appsec-expert`, `afc-tech-advisor`) have `memory: project` | All experts have memory field | ✗ Fix: add `memory: project` to `agents/{name}.md` frontmatter |
| Worker maxTurns | `afc-impl-worker` and `afc-pr-analyst` have `maxTurns:` field | Both workers have maxTurns | ✗ Fix: add `maxTurns:` to `agents/{name}.md` frontmatter |

### Category 11: Doc References (development only)

> Only run if current directory is the all-for-claudecode source repo (same condition as Category 8).

| Check | How | Pass | Fail |
|-------|-----|------|------|
| Referenced docs exist | Scan commands and agents for file references to `docs/` (e.g. `docs/critic-loop-rules.md`, `docs/phase-gate-protocol.md`). Each referenced file must exist. | All referenced docs found | ✗ Fix: create missing `docs/{file}.md` or fix the reference |
| Domain adapters exist | `docs/domain-adapters/` directory contains at least one `.md` file | ≥ 1 adapter file found | ✗ Fix: add domain adapter files to `docs/domain-adapters/` |

---

## Execution

1. Run the automated health check script:
   ```
   "${CLAUDE_PLUGIN_ROOT}/scripts/afc-doctor.sh" $ARGUMENTS
   ```
   This covers Categories 1-8 automatically.

2. Print the script's stdout output as-is (already formatted with pass/warn/fail markers).

3. If in the source repo (package.json `name` = `"all-for-claudecode"`), continue with Categories 9-11 manually using the check tables above.

4. Print combined summary (script summary + any additional findings from Categories 9-11).

## Example Output

```
all-for-claudecode Doctor
=======================

Environment
  ✓ git installed (2.43.0)
  ⚠ jq not found — hook scripts will use grep/sed fallback
    Fix: brew install jq

Project Config
  ✓ .claude/afc.config.md exists
  ✓ Required sections: ci, gate, architecture, code_style
  ✓ CI command runnable
  ✓ Gate command runnable

CLAUDE.md Integration
  ✓ Global ~/.claude/CLAUDE.md exists
  ✓ all-for-claudecode block present
  ⚠ all-for-claudecode block version outdated (1.0.0 → 1.1.0)
    Fix: /afc:init
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

Version Sync (dev)
  ✓ Version triple match
  ✓ Cache in sync

Command Definitions (dev)
  ✓ Frontmatter exists (25 files)
  ✓ Required fields present
  ✓ Name-filename match
  ✓ Fork-agent references valid

Agent Definitions (dev)
  ✓ Frontmatter exists (12 files)
  ✓ Required fields present
  ✓ Name-filename match
  ✓ Expert memory configured (8/8)
  ✓ Worker maxTurns configured (2/2)

Doc References (dev)
  ✓ Referenced docs exist
  ✓ Domain adapters exist (3 files)

─────────────────────────
Results: 28 passed, 2 warnings, 0 failures
2 warnings found. Non-blocking but review recommended.
```

## Notes

- **Read-only**: this command never modifies any files. It only reads and reports.
- **Always run all checks**: do not stop on first failure. The full picture is the value.
- **Actionable fixes**: every non-pass result must include a Fix line. Never report a problem without a solution.
- **Fast execution**: skip CI/gate command checks if `--fast` is in arguments (these are the slowest checks).
- **Development checks**: Categories 8–11 (Version Sync, Command Definitions, Agent Definitions, Doc References) only run when inside the all-for-claudecode source repo.
