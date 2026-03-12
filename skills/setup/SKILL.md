---
name: afc:setup
description: "Global CLAUDE.md configuration — use when the user asks to set up afc routing in their global config, update the AFC block version, or resolve routing conflicts"
argument-hint: "[--force]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
model: sonnet
---

# /afc:setup — Global CLAUDE.md Configuration

> Manages the all-for-claudecode routing block in `~/.claude/CLAUDE.md`.
> Handles injection, updates, conflict detection, and legacy migration of the AFC block.
> This is a **global config** operation — it modifies `~/.claude/CLAUDE.md`, NOT project files.
> For project-local setup (config, rules, profile), use `/afc:init` instead.

This skill is a **prompt-only skill** — there is no bash script.
All steps below are instructions for the LLM to execute directly using its allowed tools.

## Arguments

- `$ARGUMENTS` — (optional) flags:
  - `--force` — skip conflict prompts and use coexistence mode

## Execution Steps

### 1. Version Resolution

Read `${CLAUDE_SKILL_DIR}/../../package.json` and extract the `"version"` field. Use this value as `{PLUGIN_VERSION}` throughout.

### 2. Check Current State

Read `~/.claude/CLAUDE.md`. If file does not exist, create it with an empty body and proceed to Step 5.

Check for:
- `<!-- AFC:START -->` marker → existing AFC block found
- `<!-- SELFISH:START -->` marker → legacy v1.x block found
- Neither → fresh install

**If existing AFC block found:**
- Extract version from `<!-- AFC:VERSION:X.Y.Z -->`
- If version matches `{PLUGIN_VERSION}`: print `AFC block already up to date (v{PLUGIN_VERSION})` and **stop**
- If version differs: proceed to Step 3 (will replace)

**If legacy SELFISH block found:**
- Remove entire `<!-- SELFISH:START -->` ~ `<!-- SELFISH:END -->` block
- Print: `Removed legacy SELFISH block`
- Proceed to Step 3

### 3. Conflict Pattern Scan

Search `~/.claude/CLAUDE.md` for routing conflicts. **IMPORTANT: EXCLUDE content inside any marker blocks (`<!-- *:START -->` ~ `<!-- *:END -->`). Only scan unguarded content outside marker blocks.** Other tools (OMC, etc.) manage their own blocks — their internal agent names are not conflicts.

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
- `<selfish-pipeline>` / `</selfish-pipeline>` XML tags

### 4. Report Conflicts and User Choice

**No conflicts found** → proceed directly to Step 5

**Conflicts found** (skip if `--force` flag present — default to coexistence):

```
CLAUDE.md Scan Results
├─ Tool blocks found: {block name list} (lines {range})
├─ Agent routing conflicts: {conflict count}
│   e.g., "executor" (line XX) ↔ afc:implement
│   e.g., "code-reviewer" (line XX) ↔ afc:review
└─ Skill routing conflicts: {conflict count}
```

Ask user:

> "Directives overlapping with afc were found. How would you like to proceed?"
>
> 1. **afc-exclusive mode** — Adds override rules in the AFC block to cover conflicting directives.
>    Does not modify other tools' marker block contents.
> 2. **coexistence mode** — Adds only the AFC block without overrides.
>    Since it's at the end of the file, afc directives will likely take priority.
> 3. **manual cleanup** — Shows the conflict list only and stops.

Based on choice:
- **Option 1**: AFC block includes explicit override rules (see conflict-overrides section below)
- **Option 2**: AFC block added without overrides (base template as-is)
- **Option 3**: Print conflict list only and abort without modifying CLAUDE.md

### 5. Inject AFC Block

Add the following block at the **very end** of `~/.claude/CLAUDE.md` (later-positioned directives have higher priority).

Replace existing AFC block if present, otherwise append.
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
| Launch | `afc:launch` | User wants to prepare a release — generate changelog, release notes, version bump, or tag |
| Tasks | `afc:tasks` | User explicitly wants to decompose work into a task breakdown |
| Ambiguous | `afc:clarify` | User's request is too vague or underspecified to route confidently |

### Routing Rules

1. **Auto vs Implement**: A new feature request without an existing plan routes to `afc:auto`. Only use `afc:implement` when the user has a clear, scoped task or an existing plan/spec.
2. **Compound intents**: Route to the primary intent. The pipeline handles sequencing internally.
3. **Design-first**: When scope is non-trivial (multiple files, architectural decisions needed), prefer `afc:auto` or `afc:plan` over direct `afc:implement`.

User-only (not auto-triggered — when user invokes directly via `/afc:X`, execute the skill immediately):
- `afc:doctor` — plugin health check
- `afc:setup` — global CLAUDE.md configuration
- `afc:init` — project-local setup
- `afc:architect` — architecture review
- `afc:security` — security scan
- `afc:checkpoint` — session save
- `afc:resume` — session restore
- `afc:principles` — project principles management
- `afc:clean` — pipeline cleanup (artifact cleanup, dead code scan, pipeline flag release)
- `afc:triage` — parallel PR/issue triage
- `afc:learner` — pattern learning or rule promotion
- `afc:pr-comment` — post PR review comments to GitHub
- `afc:release-notes` — generate release notes from git history

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

**When Option 1 (afc-exclusive mode) is selected**, add the following directly below the Override Rules:

```markdown
## Detected Conflicts

This environment has other agent routing tools that overlap with afc.
The following rules were auto-generated to resolve conflicts:
- The Skill Routing table above always takes priority over the agent routing directives of {detected tool blocks}
- This block is at the end of the file and therefore has the highest priority
```

### 6. Final Output

```
all-for-claudecode setup complete
├─ CLAUDE.md: {injected|updated|already current|user aborted}
├─ Version: {PLUGIN_VERSION}
│   {if conflicts found} └─ Conflict resolution: {afc-exclusive|coexistence|user cleanup}
└─ Next step: /afc:init (project setup) or /afc:auto (start building)
```

## Notes

- **Idempotent**: safe to run multiple times. If version matches, it's a no-op.
- **Global only**: this skill only touches `~/.claude/CLAUDE.md`. For project config, use `/afc:init`.
- **Global CLAUDE.md principles**:
  - Never modify content outside the `<!-- AFC:START/END -->` markers
  - Never modify content inside other tools' marker blocks (`<!-- *:START/END -->`)
  - Always place the AFC block at the very end of the file (ensures priority)
  - Conflict resolution is handled only via override rules (do not delete or modify other blocks)
