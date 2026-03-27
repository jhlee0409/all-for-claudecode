---
name: afc:setup
description: "Configure afc routing block in global CLAUDE.md"
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
> **Global only** — modifies `~/.claude/CLAUDE.md`, not project files. For project-local setup, use `/afc:init`.

## Current State

!`cat ~/.claude/CLAUDE.md 2>/dev/null || echo "[CLAUDE.md NOT FOUND]"`

## Arguments

- `--force` — skip conflict prompts, default to coexistence mode

## Steps

### 1. Version Resolution

Read `${CLAUDE_SKILL_DIR}/../../package.json` → extract `"version"` → use as `{PLUGIN_VERSION}`.

### 2. Analyze Current State

Parse the pre-fetched CLAUDE.md content above:

- `<!-- AFC:START -->` found → existing AFC block
  - Extract `<!-- AFC:VERSION:X.Y.Z -->`. If matches `{PLUGIN_VERSION}`: print `AFC block already up to date (v{PLUGIN_VERSION})` and **stop**.
  - Otherwise: replace block in Step 5.
- `<!-- SELFISH:START -->` found → remove entire `SELFISH:START`…`SELFISH:END` block, print `Removed legacy SELFISH block`, proceed.
- Neither → fresh install, proceed to Step 5.

### 3. Conflict Scan

Detect conflicts in unguarded content (outside any `<!-- *:START/END -->` blocks).
See [`conflict-detection.md`](conflict-detection.md) for marker-block algorithm and conflict keyword table.

Skip this step if `--force` is set — default to coexistence.

### 4. Resolve Conflicts

**No conflicts** → proceed to Step 5.

**Conflicts found** — show scan summary and ask:

```
CLAUDE.md Scan Results
├─ Tool blocks found: {names} (lines {range})
├─ Agent routing conflicts: {count} — e.g. "executor" (line XX) ↔ afc:implement
└─ Skill routing conflicts: {count}
```

> "Directives overlapping with afc were found. Choose resolution:"
>
> 1. **afc-exclusive** — add override rules inside the AFC block (does not touch other tools' blocks)
> 2. **coexistence** — append AFC block as-is (end-of-file position gives it priority)
> 3. **manual cleanup** — print conflict list and abort

- Option 3: print list and abort without writing.

### 5. Inject AFC Block

Append the block below to the **end** of `~/.claude/CLAUDE.md` (or replace existing AFC block in place).
Also remove any legacy unguarded block (`## all-for-claudecode Auto-Trigger Rules`, etc.) before appending.

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
- `afc:issue` — analyze a single GitHub issue
- `afc:resolve` — address LLM bot review comments on a PR
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

**When afc-exclusive mode (Option 1)** is selected, append inside the block after Override Rules:

```markdown
## Detected Conflicts

The following rules were auto-generated to resolve conflicts:
- The Skill Routing table above always takes priority over agent routing directives of {detected tool blocks}
- This block is at the end of the file and therefore has the highest priority
```

### 6. Final Output

```
all-for-claudecode setup complete
├─ CLAUDE.md: {injected|updated|already current|user aborted}
├─ Version: {PLUGIN_VERSION}
│   {if conflicts} └─ Conflict resolution: {afc-exclusive|coexistence|user cleanup}
└─ Next step: /afc:init (project setup) or /afc:auto (start building)
```

## Notes

- **Idempotent**: version match → no-op.
- Never modify content outside `<!-- AFC:START/END -->` markers.
- Never modify content inside other tools' `<!-- *:START/END -->` blocks.
- Always place the AFC block at the end of the file.
