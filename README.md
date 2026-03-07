<div align="center">                                                                                                                                        
  <img src="https://github.com/user-attachments/assets/9e23029e-e326-4cfa-b329-3bdd1006aecd" alt="all-for-claudecode" width="640" />                        
</div>

# all-for-claudecode

**Claude Code plugin that automates the full development cycle — spec → plan → implement → review → clean.**

[![CI](https://github.com/jhlee0409/all-for-claudecode/actions/workflows/ci.yml/badge.svg)](https://github.com/jhlee0409/all-for-claudecode/actions/workflows/ci.yml)
[![npm version](https://img.shields.io/npm/v/all-for-claudecode)](https://www.npmjs.com/package/all-for-claudecode)
[![npm downloads](https://img.shields.io/npm/dm/all-for-claudecode)](https://www.npmjs.com/package/all-for-claudecode)
[![license](https://img.shields.io/github/license/jhlee0409/all-for-claudecode)](./LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/jhlee0409/all-for-claudecode?style=social)](https://github.com/jhlee0409/all-for-claudecode)

> One command (`/afc:auto`) runs the entire cycle. Zero runtime dependencies — pure markdown commands + bash hook scripts.

## Quick Start

```bash
# Option A: Inside Claude Code
/plugin marketplace add jhlee0409/all-for-claudecode
/plugin install afc@all-for-claudecode

# Option B: npx
npx all-for-claudecode
```

Then:

```
/afc:init                              # Detect your stack, generate config
/afc:auto "Add user authentication"    # Run the full pipeline
```

The pipeline will:
1. Write a feature spec with acceptance criteria
2. Design an implementation plan with file change map
3. Implement tasks with CI gates (auto task decomposition + parallel execution)
4. Run code review with architecture/security agent analysis
5. Clean up artifacts and prepare for commit

## How It Works

```
/afc:auto "Add feature X"

Spec (1/5) → Plan (2/5) → Implement (3/5) → Review (4/5) → Clean (5/5)
  │              │              │                │              │
  │              │              │                │              └─ Artifact cleanup
  │              │              │                └─ 8 perspectives + agent review
  │              │              └─ Auto task decomposition, parallel execution, CI gates
  │              └─ File change map, ADR recording, research persistence
  └─ Acceptance criteria, pre-implementation gates

Hooks run automatically at each step.
CI failure → debug-based RCA (not blind retry).
Critic Loops verify quality at each gate until convergence.
```

## Walkthrough: What a Pipeline Run Looks Like

Running `/afc:auto "Add password reset flow"` produces this (abbreviated):

**Spec (1/5)** — Generates `spec.md` with requirements and acceptance criteria:
```
FR-001: POST /auth/reset sends email with token
FR-002: GET /auth/reset/:token validates and shows form
FR-003: Token expires after 1 hour
Acceptance: Given expired token, When user submits, Then show error
```

**Plan (2/5)** — Creates `plan.md` with file change map and architecture decisions:
```
File Change Map:
  src/routes/auth.ts        — ADD reset endpoint handlers
  src/services/email.ts     — ADD sendResetEmail()
  src/middleware/validate.ts — MODIFY add token validation
  tests/auth.test.ts        — ADD reset flow tests
```

**Implement (3/5)** — Auto-decomposes into tasks, executes with CI gates:
```
Tasks: 4 total (2 parallel)
  [1] Add reset endpoint     ✓
  [2] Add email service       ✓  ← parallel with [1]
  [3] Add token validation    ✓  ← depends on [1]
  [4] Add tests               ✓
CI: npm test → passed
```

**Review (4/5)** — 8-perspective review + specialist agent analysis:
```
Architecture (afc-architect): ✓ layer boundaries respected
Security (afc-security): ⚠ rate-limit reset endpoint
Performance: ✓ no N+1 queries
→ Auto-fixed: added rate limiter middleware
```

**Clean (5/5)** — Removes pipeline artifacts, final CI check.

## Slash Commands

| Command | Description |
|---|---|
| `/afc:auto` | Full Auto pipeline — runs all 5 phases |
| `/afc:spec` | Write feature specification with acceptance criteria |
| `/afc:plan` | Design implementation plan with file change map |
| `/afc:implement` | Execute code implementation with CI gates |
| `/afc:test` | Test strategy planning and test writing |
| `/afc:review` | Code review with architecture/security scanning |
| `/afc:clean` | Pipeline artifact cleanup and codebase hygiene |
| `/afc:research` | Technical research with persistent storage |
| `/afc:debug` | Bug diagnosis and fix |
| `/afc:init` | Project setup — detects stack and generates config |
| `/afc:doctor` | Diagnose project health and plugin setup |
| `/afc:architect` | Architecture analysis (persistent memory) |
| `/afc:security` | Security scan (persistent memory, isolated worktree) |
| `/afc:principles` | Project principles management |
| `/afc:checkpoint` | Save session state |
| `/afc:resume` | Restore session state |
| `/afc:tasks` | Task decomposition (auto-generated by implement) |
| `/afc:ideate` | Explore and structure a product idea |
| `/afc:launch` | Generate release artifacts (changelog, tag, publish) |
| `/afc:validate` | Verify artifact consistency |
| `/afc:analyze` | General-purpose code and component analysis |
| `/afc:qa` | Project quality audit — test confidence, error resilience, code health |
| `/afc:consult` | Expert consultation (backend, infra, PM, design, marketing) |
| `/afc:triage` | Analyze open PRs and issues in parallel |
| `/afc:pr-comment` | Generate structured PR review comments |
| `/afc:release-notes` | Generate release notes from git history |
| `/afc:learner` | Review and promote learned patterns to project rules |
| `/afc:clarify` | Resolve spec ambiguities |

### Individual Command Examples

```bash
# Write a spec for a specific feature
/afc:spec "Add dark mode toggle"

# Design a plan from an existing spec
/afc:plan

# Debug a specific error
/afc:debug "TypeError: Cannot read property 'user' of undefined"

# Run code review on current changes
/afc:review

# Explore and structure a product idea
/afc:ideate "real-time collaboration feature"

# Triage open PRs and issues
/afc:triage              # all open PRs + issues
/afc:triage --pr         # PRs only
/afc:triage --deep       # deep analysis with diff review
/afc:triage 42 99        # specific items by number
```

## Hook Events

Every hook fires automatically — no configuration needed after install.

| Hook | What it does |
|---|---|
| `SessionStart` | Restores pipeline state on session resume |
| `PreCompact` | Auto-checkpoints before context compression |
| `PreToolUse` | Blocks dangerous commands (`push --force`, `reset --hard`) |
| `PostToolUse` | Tracks file changes + auto-formats code |
| `SubagentStart` | Injects pipeline context into subagents |
| `Stop` | CI gate (shell) + code completeness check (shell) |
| `SessionEnd` | Warns about unfinished pipeline |
| `PostToolUseFailure` | Diagnostic hints for known error patterns |
| `Notification` | Desktop alerts (macOS/Linux) |
| `TaskCompleted` | CI gate (shell) + acceptance criteria verification (LLM) |
| `SubagentStop` | Tracks subagent completion in pipeline log |
| `UserPromptSubmit` | **Inactive**: detects intent keywords and suggests matching afc skill. **Active**: injects Phase/Feature context + drift checkpoint at threshold prompts |
| `PermissionRequest` | Auto-allows CI commands during implement/review |
| `ConfigChange` | Audits/blocks settings changes during active pipeline |
| `TeammateIdle` | Prevents Agent Teams idle during implement/review |
| `WorktreeCreate` | Sets up worktree isolation for parallel workers |
| `WorktreeRemove` | Cleans up worktree after worker completion |

Handler types: `command` (shell scripts, all events), `prompt` (LLM single-turn, TaskCompleted).

## Persistent Memory Agents

| Agent | Role |
|---|---|
| `afc-architect` | Remembers ADR decisions and architecture patterns across sessions. Auto-invoked during Plan (ADR recording) and Review (architecture compliance). |
| `afc-security` | Remembers vulnerability patterns and false positives across sessions. Auto-invoked during Review (security scanning). Runs in isolated worktree. |
| `afc-impl-worker` | Parallel implementation worker. Receives pre-assigned tasks from orchestrator. Ephemeral (no memory). Max 50 turns, auto-approve edits. |
| `afc-pr-analyst` | PR deep analysis worker for triage. Runs in isolated worktree with diff access. Max 15 turns. |

## Expert Consultation

Get advice from domain specialists — each with persistent memory of your project:

```bash
/afc:consult backend "Should I use JWT or session cookies?"
/afc:consult infra "How should I set up CI/CD?"
/afc:consult pm "How should I prioritize my backlog?"
/afc:consult design "Is this form accessible?"
/afc:consult marketing "How to improve SEO?"
/afc:consult legal "Do I need GDPR compliance?"
/afc:consult security "Is storing JWT in localStorage safe?"
/afc:consult advisor "I need a database for my Next.js app"

# Auto-detect domain from question
/afc:consult "My API is slow when loading the dashboard"

# Exploratory mode — expert asks diagnostic questions
/afc:consult backend
```

| Expert | Domain |
|---|---|
| `backend` | API design, database, authentication, server architecture |
| `infra` | Deployment, CI/CD, cloud, monitoring, scaling |
| `pm` | Product strategy, prioritization, user stories, metrics |
| `design` | UI/UX, accessibility, components, user flows |
| `marketing` | SEO, analytics, growth, content strategy |
| `legal` | GDPR, privacy, licenses, compliance, terms of service |
| `security` | Application security, OWASP, threat modeling, secure coding |
| `advisor` | Technology/library/framework selection, ecosystem navigation |

Features:
- **Persistent memory**: experts remember your project's decisions across sessions
- **Overengineering Guard**: recommendations scaled to your actual project size
- **Domain adapters**: industry-specific guardrails (fintech, ecommerce, healthcare)
- **Pipeline-aware**: when a pipeline is active, experts consider the current phase context

## Task Orchestration

The implement phase automatically selects execution strategy:

| Parallel tasks in phase | Mode |
|---|---|
| 0 | Sequential — one task at a time |
| 1–5 | Parallel Batch — concurrent Task() calls |
| 6+ | Swarm — orchestrator pre-assigns tasks to worker agents (max 5) |

Dependencies are tracked via DAG. CI gate + Mini-Review + Auto-Checkpoint run at each phase boundary.

## Configuration

```
/afc:init
```

Auto-detects your tech stack (package manager, framework, architecture, testing, linting) and generates `.claude/afc.config.md` with CI commands, architecture rules, and code style conventions. No manual preset selection needed — the init command analyzes your project structure directly.

## FAQ

### Does it work with any project?
Yes. Run `/afc:init` to auto-detect your stack. Works with JavaScript/TypeScript, Python, Rust, Go, and any project with a CI command.

### Does it require any dependencies?
No. Pure markdown commands + bash hook scripts. No npm packages are imported at runtime.

### What happens if CI fails during the pipeline?
Debug-based RCA: traces the error, forms a hypothesis, applies a targeted fix. Halts after 3 failed attempts with full diagnosis.

### Can I run individual phases?
Yes. Each phase has its own command (`/afc:spec`, `/afc:plan`, `/afc:implement`, `/afc:review`, `/afc:clean`). `/afc:auto` runs them all.

### What are Critic Loops?
Convergence-based quality checks after each phase. They evaluate output against criteria and auto-fix issues until stable. 4 verdicts: PASS, FAIL, ESCALATE (asks user), DEFER.

### How many tokens does a pipeline run use?
Depends on project size and feature complexity. A typical `/afc:auto` run for a medium feature uses roughly the same as a detailed manual implementation session — the pipeline adds structure, not overhead.

### Can I customize the pipeline behavior?
Yes. Edit `.claude/afc.config.md` to change CI commands, architecture rules, and code style conventions. The pipeline reads this config at every phase.

### Does it work with monorepos?
Yes. Run `/afc:init` in the monorepo root. The init command detects workspace structure and configures accordingly.

### Can multiple team members use it on the same repo?
Yes. Each developer runs their own pipeline independently. The `.claude/afc.config.md` config is shared (commit it to the repo), but pipeline state is local and session-scoped.

### How is this different from Cursor / Copilot / other AI tools?
All-for-claudecode is not a code completion tool — it is a structured development pipeline. It enforces spec → plan → implement → review flow with quality gates, persistent memory agents, and CI verification at every step.

## License

MIT
