---
name: afc:doctor
description: "Diagnose afc plugin setup and health"
argument-hint: "[--verbose]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
model: sonnet
---

# /afc:doctor — Plugin Setup Diagnosis

> Checks whether the all-for-claudecode plugin is correctly installed and configured in the current project.
> Like `brew doctor` or `flutter doctor` — verifies the **tool's setup**, NOT the project's code quality.
> Read-only — never modifies files. Reports issues with actionable fix commands.
>
> **IMPORTANT: Do NOT analyze project source code, architecture, or code quality. Only check afc plugin configuration, hooks, state, and environment. All checks are handled by the bash script — just run it and print the output.**

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

## Execution

1. Run the health check script (covers ALL categories — no manual checks needed):
   ```
   "${CLAUDE_SKILL_DIR}/../../scripts/afc-doctor.sh" $ARGUMENTS
   ```

2. Print the script's stdout output as-is. Do not reformat, summarize, or interpret.

3. **Stop.** Output nothing after the script output. No analysis, no suggestions, no follow-up actions.

**Rules:**
- The ONLY Bash command you may run is the `afc-doctor.sh` script above. No other Bash calls.
- Do NOT execute Fix commands. They are for the user to run manually.
- Do NOT analyze project source code, git history, branches, or architecture.

## Example Output

```
all-for-claudecode Doctor (v2.11.0)
Plugin root: /path/to/plugin

Environment
  ✓ git installed (2.43.0)
  ⚠ jq not found — hook scripts will use grep/sed fallback
    Fix: brew install jq

Project Config
  ✓ .claude/afc.config.md exists
  ✓ Required sections present
  ✓ Gate command defined

CLAUDE.md Integration
  ✓ Global ~/.claude/CLAUDE.md exists
  ✓ all-for-claudecode block present
  ⚠ all-for-claudecode block outdated (block: 1.0.0, plugin: 1.1.0)
    Fix: run /afc:setup to update

Legacy Migration
  ✓ No legacy artifacts found

Pipeline State
  ✓ No stale pipeline state
  ✓ No orphaned artifacts

Memory Health

Hook Health
  ✓ hooks.json valid
  ✓ All hook scripts exist
  ✓ All scripts executable

Learner Health
  ✓ Learner not enabled (opt-in via /afc:learner enable)

Version Sync (dev)
  ✓ Version triple match (1.1.0)
  ✓ Cache in sync

Skill Definitions (dev)
  ✓ Frontmatter exists (29 files)
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
Results: 26 passed, 2 warnings, 0 failures
2 warnings found. Non-blocking but review recommended.
```

## Notes

- **Read-only**: this command NEVER modifies any files, deletes tags, changes permissions, or executes fix commands. It only reads and reports. The `Fix:` lines are instructions for the USER to run manually — do NOT execute them.
- **No project analysis**: after printing the summary, STOP. Do not analyze project source code, git history, branches, or suggest next steps about the project. Doctor's scope ends at the summary line.
- **Always run all checks**: do not stop on first failure. The full picture is the value.
- **Actionable fixes**: every non-pass result must include a Fix line. Never report a problem without a solution.
- **Fast execution**: skip CI/gate command checks if `--fast` is in arguments (these are the slowest checks).
- **Development checks**: Version Sync, Skill Definitions, Agent Definitions, Doc References only run when inside the all-for-claudecode source repo.
