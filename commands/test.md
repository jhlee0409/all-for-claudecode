---
name: afc:test
description: "Test strategy planning and test writing"
argument-hint: "[target: file path, feature name, or coverage]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
model: sonnet
---

# /afc:test — Test Strategy Planning and Test Writing

> Establishes a test strategy for implemented code and writes tests.
> Standalone command — not part of the auto pipeline. Use after implement or before review.

## Arguments

- `$ARGUMENTS` — (required) Test target. One of:
  - File path or directory (e.g., `src/features/auth/`)
  - Feature name (e.g., `login flow`)
  - `coverage` — full coverage analysis and gap remediation

## Config Load

**Always** read `.claude/afc.config.md` first.

If config file is missing:
1. Ask the user: "`.claude/afc.config.md` not found. Run `/afc:init` to set up the project?"
2. If user accepts → run `/afc:init`, then **restart this command** with the original `$ARGUMENTS`
3. If user declines → **abort**

Values used from config:
- `{config.testing}` — test framework (jest, vitest, playwright, etc.)
- `{config.architecture}` — architecture pattern
- `{config.gate}` — CI validation command

## Execution Steps

### 1. Target Analysis

1. Parse `$ARGUMENTS`:
   - **File/Directory** → read that code, check for existing test files
   - **Feature name** → explore related files, read code
   - **coverage** → scan all existing tests, identify coverage gaps

2. **Existing coverage check**: Before writing new tests, evaluate what already exists:
   - Are there existing test files for the target? What do they cover?
   - If existing tests already provide adequate coverage → report: "Existing tests in {path} already cover the core scenarios. No additional tests needed." Ask user: "(1) Add edge case tests only (2) Rewrite tests (3) Abort"
   - If partially covered → identify specific gaps and target only those

3. Determine characteristics of target code:
   - Public interface (function signatures, component props)
   - Dependencies (external APIs, DB, state management)
   - Branch points (conditionals, error handling)
   - Edge cases

### 2. Test Strategy Planning

```markdown
### Test Strategy
- Target: {file/feature}
- Framework: {config.testing}
- Test types:
  - [ ] Unit tests: {list of target functions/methods}
  - [ ] Integration tests: {component interactions}
  - [ ] E2E tests: {user scenarios} (only if applicable)
- Mocking strategy: {mocking approach per dependency}
```

Confirm strategy with user before proceeding.

### 3. Write Tests

**Principles:**
- **AAA pattern**: Arrange → Act → Assert
- **Test names**: `it('should {expected behavior} when {condition}')` format
- **Independence**: each test can run independently
- **Readability**: test code serves as documentation

**Priority:**
1. Happy path (normal behavior)
2. Error cases (error handling)
3. Edge cases (boundary values)
4. Regression guards (prevent bug recurrence)

**Test file location**: follows project convention
- Co-location: `{filename}.test.{ext}` (same directory)
- Separate: `__tests__/{filename}.test.{ext}` or `tests/` directory

### 4. Critic Loop

> **Always** read `${CLAUDE_PLUGIN_ROOT}/docs/critic-loop-rules.md` first and follow it.

Run the critic loop until convergence. Safety cap: 5 passes.

| Criterion | Validation |
|-----------|------------|
| **COVERAGE** | Are all core logic and branch points covered? |
| **QUALITY** | Do tests validate behavior, not implementation details? Are there any brittle tests? |

**On FAIL**: auto-fix and continue to next pass.
**On ESCALATE**: pause, present options to user, apply choice, resume.
**On DEFER**: record reason, mark criterion clean, continue.
**On CONVERGE**: `✓ Critic converged ({N} passes, {M} fixes, {E} escalations)`
**On SAFETY CAP**: `⚠ Critic safety cap ({N} passes). Review recommended.`

### 5. Run and Verify Tests

```bash
{config.gate}
```

On failure:
1. Determine whether the issue is in test code or implementation code
2. Test code issue → fix tests
3. Implementation code issue → report to user (test found a bug)

Maximum 3 retries.

### 6. Final Output

```
Tests complete
├─ Target: {file/feature}
├─ Written: {N} tests ({unit X, integration Y, E2E Z})
├─ Coverage: {summary of key branch point coverage}
├─ Critic: converged ({N} passes, {M} fixes, {E} escalations)
├─ Verified: all tests passing
└─ Found: {bug details if found, otherwise "no issues"}
```

## Notes

- **No implementation coupling**: test external behavior, not internal implementation. Do not directly test private methods.
- **Minimize mocking**: mock only necessary external dependencies. Excessive mocking reduces test value.
- **Avoid snapshot overuse**: UI snapshots for core structure only. Avoid snapshots that break on style changes.
- **Respect existing tests**: follow existing test patterns and conventions. Confirm with user before introducing new patterns.
