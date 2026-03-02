---
name: afc:qa
description: "Project quality audit — detect gaps between structure and runtime behavior"
argument-hint: "[scope: all, tests, errors, coverage, or specific concern]"
user-invocable: true
context: fork
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
model: sonnet
---

# /afc:qa — Project Quality Audit

> Detects quality gaps between structural correctness and actual runtime behavior.
> **Read-only** — does not modify any files. Reports findings to console only.

## Arguments

- `$ARGUMENTS` — (optional) scope of audit. Defaults to `all`.
  - `all` — run all 5 categories
  - `tests` — category A only (Test Confidence)
  - `errors` — category B only (Error Resilience)
  - `coverage` — categories A + D (Test Confidence + API & Contract Safety)
  - Or a free-form concern (e.g., "are error messages user-friendly", "check for dead exports")

## Config Load

**Always** read `.claude/afc.config.md` first. This file contains free-form markdown sections:
- `## Architecture` — architecture pattern, layers, import rules
- `## Code Style` — language, naming conventions, lint rules
- `## CI Commands` — test, lint, gate commands (YAML)
- `## Project Context` — framework, state management, testing strategy

If config file is missing: read `CLAUDE.md` for project info. Proceed without config if neither exists.

## Audit Categories

### A. Test Confidence

Evaluate whether the test suite actually catches regressions.

Checks:
- **Assertion density**: ratio of assertions to test functions (low ratio = weak tests)
- **Test-to-code ratio**: test LOC vs source LOC per layer (guided by `{config.architecture}`)
- **Mock overuse**: tests that mock so much they only test the mock setup
- **Runtime verification**: execute `{config.test}` and analyze output (pass/fail counts, skipped tests, timing)
- **Missing coverage**: source files/modules with zero test coverage

### B. Error Resilience

Evaluate whether errors are handled consistently and helpfully.

Checks:
- **Catch consistency**: unhandled promise rejections, empty catch blocks, swallowed errors
- **Error propagation**: errors that lose context through the call chain
- **User-facing messages**: cryptic error strings, raw stack traces exposed to users
- **Boundary validation**: missing input validation at API/CLI/form boundaries
- Apply `{config.code_style}` error handling rules if available

### C. Build & CI Integrity

Evaluate whether CI pipeline is healthy and reproducible.

Checks:
- **CI execution**: run `{config.ci}` and `{config.gate}` commands, verify they pass
- **Lock file integrity**: lock file present, consistent with manifest (package.json vs lock, etc.)
- **Unused dependencies**: declared but never imported packages
- **Build reproducibility**: environment-dependent paths, hardcoded secrets, missing env vars

### D. API & Contract Safety

Evaluate whether interfaces between modules are sound.

Checks:
- **Type mismatches**: function signatures vs actual usage at call sites
- **Dead exports**: exported symbols never imported elsewhere
- **Deprecated usage**: calls to deprecated APIs (internal or external)
- **Layer boundary violations**: imports that cross architecture boundaries (guided by `{config.architecture}`)

### E. Code Health Signals

Evaluate general code quality indicators.

Checks:
- **Complexity hotspots**: deeply nested logic, functions exceeding ~50 LOC
- **Duplication**: near-identical code blocks across files
- **Magic numbers/strings**: unexplained literals in logic
- **TODO/FIXME accumulation**: stale markers (count, age if git history available)
- Compare against `{config.code_style}` rules if available

## Execution Steps

### 1. Load Config

Read `.claude/afc.config.md` (or fallback to `CLAUDE.md`). Extract:
- Test command (`{config.test}`)
- CI/gate commands (`{config.ci}`, `{config.gate}`)
- Architecture layers (`{config.architecture}`)
- Code style rules (`{config.code_style}`)

### 2. Parse Scope

Interpret `$ARGUMENTS` to determine which categories to run:

| Argument | Categories |
|----------|-----------|
| `all` or empty | A, B, C, D, E |
| `tests` | A |
| `errors` | B |
| `coverage` | A, D |
| free-form text | best-matching subset |

### 3. Lightweight Runtime

Run commands that produce real output:
- `{config.test}` — capture pass/fail/skip counts and timing
- `{config.gate}` or `{config.ci}` — capture exit code and output

Only run commands that exist in config. Skip gracefully if not configured.

### 4. Codebase Scan

For each active category:
1. Use Glob to discover relevant files
2. Use Grep for pattern-based detection (empty catches, TODO markers, etc.)
3. Use Read for targeted inspection of flagged files
4. Cross-reference findings against `{config.architecture}` layer structure

### 5. Critic Loop

Apply `docs/critic-loop-rules.md` with **safety cap: 3 rounds**.

Focus the critic on:
- Are the findings actionable or just noise?
- Did I miss obvious quality gaps?
- Are severity ratings justified by evidence?

### 6. Console Report

Output the final report in this format:

```markdown
## QA Audit: {project name or directory}

### Category A: Test Confidence
{findings with file:line references}
Verdict: PASS | WARN | FAIL

### Category B: Error Resilience
{findings with file:line references}
Verdict: PASS | WARN | FAIL

### Category C: Build & CI Integrity
{findings with file:line references}
Verdict: PASS | WARN | FAIL

### Category D: API & Contract Safety
{findings with file:line references}
Verdict: PASS | WARN | FAIL

### Category E: Code Health Signals
{findings with file:line references}
Verdict: PASS | WARN | FAIL

### Summary
├─ A: Test Confidence    — {PASS|WARN|FAIL} {(N issues) if any}
├─ B: Error Resilience   — {PASS|WARN|FAIL} {(N issues) if any}
├─ C: Build & CI         — {PASS|WARN|FAIL} {(N issues) if any}
├─ D: API & Contract     — {PASS|WARN|FAIL} {(N issues) if any}
└─ E: Code Health        — {PASS|WARN|FAIL} {(N issues) if any}

Total: {N} PASS, {N} WARN, {N} FAIL
Priority fixes: {top 3 most impactful issues}
```

## Verdict Criteria

- **PASS** — no issues found, or only cosmetic observations
- **WARN** — issues found but not blocking; quality could degrade over time
- **FAIL** — critical gaps that likely cause bugs, outages, or security issues

## Notes

- **Read-only**: Do not modify any files. Report only.
- **Evidence-based**: Every finding must include a `file:line` reference or command output.
- **Config-aware**: Adapt checks to the project's declared architecture and conventions.
- **Scope discipline**: Only run categories matching the requested scope.
- **Not a linter**: Focus on semantic quality gaps that automated tools miss.
