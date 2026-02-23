# Selfish Pipeline

**Claude Code plugin that automates the full development cycle — spec → plan → tasks → implement → review → clean.**

[![npm version](https://img.shields.io/npm/v/selfish-pipeline)](https://www.npmjs.com/package/selfish-pipeline)
[![license](https://img.shields.io/github/license/jhlee0409/selfish-pipeline)](./LICENSE)
[![test](https://img.shields.io/badge/tests-161%20passed-brightgreen)](#how-it-works)
[![hooks](https://img.shields.io/badge/hooks-15%20events-blue)](#15-hook-events)
[![commands](https://img.shields.io/badge/commands-18-orange)](#18-slash-commands)

> Zero-dependency automation pipeline for Claude Code. One command (`/selfish:auto`) runs the entire cycle: write specs, design plans, break into tasks, implement code, review quality, and clean up — all with built-in CI gates and critic loops.

## What is Selfish Pipeline?

Selfish Pipeline is a **Claude Code plugin** that transforms your development workflow into a fully automated pipeline. Instead of manually prompting Claude through each development phase, you run a single command and the pipeline handles everything — from writing feature specifications to final code review.

- **18 slash commands** for every phase of development
- **15 hook events** with 3 handler types (shell scripts, LLM prompts, subagents)
- **5 project presets** for popular stacks (Next.js, React SPA, Express API, Monorepo)
- **Persistent memory agents** that learn across sessions
- **Built-in CI gates** that physically prevent skipping quality checks

## Quick Start

### Option A: Inside Claude Code (`/plugin`)

```
/plugin marketplace add jhlee0409/selfish-pipeline
/plugin install selfish@selfish-pipeline
```

Or use the interactive UI: type `/plugin` → Manage → Add marketplace → `jhlee0409/selfish-pipeline` → Discover → install **selfish**.

### Option B: One-line install (via npx)

```bash
npx selfish-pipeline
```

Interactive installer — choose scope (user / project / local) and done.

### Option C: Claude Code CLI

```bash
claude plugin marketplace add jhlee0409/selfish-pipeline
claude plugin install selfish@selfish-pipeline --scope user
```

### Then, inside Claude Code:

```
/selfish:init                              # Detect your stack, generate config
/selfish:auto "Add user authentication"    # Run the full pipeline
```

That's it. The pipeline will:
1. Write a feature spec with acceptance criteria
2. Design an implementation plan with file change map
3. Break the plan into parallelizable tasks
4. Implement each task with CI verification
5. Run a code review with security scan
6. Clean up artifacts and prepare for commit

## Features

### Full Auto Pipeline

```
/selfish:auto "feature description"
```

Runs all 6 phases automatically with **Critic Loop** quality checks at each gate:

```
Spec (1/6) → Plan (2/6) → Tasks (3/6) → Implement (4/6) → Review (5/6) → Clean (6/6)
```

### 18 Slash Commands

**User and model (unrestricted):**

| Command | Description |
|---|---|
| `/selfish:auto` | Full Auto pipeline — runs all 6 phases |
| `/selfish:spec` | Write feature specification with acceptance criteria |
| `/selfish:plan` | Design implementation plan with file change map |
| `/selfish:implement` | Execute code implementation with CI gates |
| `/selfish:test` | Test strategy planning and test writing |
| `/selfish:review` | Code review with security scanning |
| `/selfish:research` | Technical research with persistent storage |
| `/selfish:debug` | Bug diagnosis and fix |

**User-only** (`disable-model-invocation: true`):

| Command | Description |
|---|---|
| `/selfish:init` | Project setup — detects stack and generates config |
| `/selfish:doctor` | Diagnose project health and plugin setup |
| `/selfish:architect` | Architecture analysis (persistent memory) |
| `/selfish:security` | Security scan (persistent memory, isolated worktree) |
| `/selfish:principles` | Project principles management |
| `/selfish:checkpoint` | Save session state |
| `/selfish:resume` | Restore session state |

**Model-only** (`user-invocable: false`):

| Command | Description |
|---|---|
| `/selfish:tasks` | Break plan into parallelizable tasks |
| `/selfish:analyze` | Verify artifact consistency |
| `/selfish:clarify` | Resolve spec ambiguities |

### 15 Hook Events

Every hook fires automatically — no configuration needed after install.

| Hook | What it does |
|---|---|
| `SessionStart` | Restores pipeline state on session resume |
| `PreCompact` | Auto-checkpoints before context compression |
| `PreToolUse` | Blocks dangerous commands (`push --force`, `reset --hard`) |
| `PostToolUse` | Tracks file changes + auto-formats code |
| `SubagentStart` | Injects pipeline context into subagents |
| `Stop` | CI gate (shell) + code completeness check (AI agent) |
| `SessionEnd` | Warns about unfinished pipeline |
| `PostToolUseFailure` | Diagnostic hints for known error patterns |
| `Notification` | Desktop alerts (macOS/Linux) |
| `TaskCompleted` | CI gate (shell) + acceptance criteria verification (LLM) |
| `SubagentStop` | Tracks subagent completion in pipeline log |
| `UserPromptSubmit` | Injects Phase/Feature context per prompt |
| `PermissionRequest` | Auto-allows CI commands during implement/review |
| `ConfigChange` | Audits/blocks settings changes during active pipeline |
| `TeammateIdle` | Prevents Agent Teams idle during implement/review |

### 3 Hook Handler Types

| Type | Description | Use Case |
|---|---|---|
| `command` | Shell script execution (deterministic) | All 15 events |
| `prompt` | LLM single-turn evaluation (haiku) | TaskCompleted |
| `agent` | Subagent with file access tools | Stop |

### Persistent Memory Agents

Two custom agents that **learn across sessions**:

| Agent | Role | Memory |
|---|---|---|
| `selfish-architect` | Architecture analysis — remembers ADR decisions and patterns | `.claude/agent-memory/selfish-architect/` |
| `selfish-security` | Security scan — remembers vulnerability patterns and false positives | `.claude/agent-memory/selfish-security/` |

### Project Presets

| Preset | Stack |
|---|---|
| `template` | Generic (manual config) |
| `nextjs-fsd` | Next.js + FSD + Zustand + React Query |
| `react-spa` | Vite + React 18 + Zustand + Tailwind |
| `express-api` | Express + TypeScript + Prisma + Jest |
| `monorepo` | Turborepo + pnpm workspace |

## How It Works

```
┌─────────────────────────────────────────────┐
│  /selfish:auto "Add feature X"              │
├─────────────────────────────────────────────┤
│  Phase 1: Spec    → Critic Loop → Gate ✓    │
│  Phase 2: Plan    → Critic Loop → Gate ✓    │
│  Phase 3: Tasks   → Critic Loop → Gate ✓    │
│  Phase 4: Implement → CI Gate → Gate ✓      │
│  Phase 5: Review  → Security Scan → Gate ✓  │
│  Phase 6: Clean   → Artifacts removed       │
├─────────────────────────────────────────────┤
│  15 hooks run automatically at each step    │
│  Stop/TaskCompleted gates block if CI fails │
└─────────────────────────────────────────────┘
```

## Configuration

Initialize your project:

```bash
/selfish:init
```

This detects your tech stack and generates `.claude/selfish.config.md` with:
- CI/lint/test commands
- Architecture style and layers
- Framework-specific settings
- Code style conventions

## FAQ

### What is selfish-pipeline?
A Claude Code plugin that automates the entire development cycle (spec → plan → tasks → implement → review → clean) through 18 slash commands and 15 hook events.

### How does it compare to manual Claude Code workflows?
Instead of manually prompting each step, selfish-pipeline orchestrates the full cycle with built-in quality gates that physically prevent skipping CI or security checks.

### Does it work with any project?
Yes. Run `/selfish:init` to auto-detect your stack, or use one of the 5 presets (Next.js, React SPA, Express API, Monorepo, or generic template).

### Does it require any dependencies?
No. Zero runtime dependencies — pure markdown commands + bash hook scripts.

### How do I install it?
Inside Claude Code, run `/plugin marketplace add jhlee0409/selfish-pipeline` then `/plugin install selfish@selfish-pipeline`. Alternatively, run `npx selfish-pipeline` from your terminal for a guided install.

### What Claude Code version is required?
Claude Code with plugin support (2025+). The plugin uses standard hooks, commands, and agents APIs.

## License

MIT
