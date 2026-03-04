---
name: afc:security
description: "Security scan (read-only) — use when the user asks for a security scan, security review, vulnerability check, or threat assessment"
argument-hint: "[scan scope: file/directory path or full]"
context: fork
agent: afc-security
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Task
  - WebSearch
model: sonnet
---

# /afc:security — Security Scan

> Detects and reports security vulnerabilities in the codebase.
> Inspects against OWASP Top 10. **Read-only** — does not modify code.

## Arguments

- `$ARGUMENTS` — (optional) scan scope (file/directory path, or "full" for full scan)
  - If not specified: scans only files changed in the current branch

## Config Load

**Always** read `.claude/afc.config.md` first. This file contains free-form markdown sections:
- `## Project Context` — framework, state management, testing, etc. (primary source for framework info)
- `## Architecture` — architecture pattern, layers, import rules
- `## Code Style` — language, naming conventions, lint rules

If config file is missing: read `CLAUDE.md` for framework info. Assume "unknown" if neither source has it.

For dependency audit command: infer from `packageManager` field in `package.json` or the lockfile (e.g., `npm audit`, `yarn audit`, `pnpm audit`).

## Execution Steps

### 1. Determine Scan Scope

- `$ARGUMENTS` = path → that path only
- `$ARGUMENTS` = "full" → entire `src/`
- Not specified → changed files from `git diff --name-only HEAD`

### 2. Agent Teams (if more than 10 files)

Use parallel agents for wide-scope scans:

**Pre-scan: Data Flow Context** (before distributing to agents):

1. For each changed file, identify **input entry points** (user input, API params, URL params, form data) and **sanitization calls** (validation, escaping, encoding)
2. Trace input flow across changed files: where does user input enter? Where is it sanitized? Where is it consumed?
3. Include this context in each agent's prompt:
   ```
   ## Data Flow Context
   Input flows relevant to your scan scope:
   - User input enters via `req.body` in api/routes.ts → sanitized by `validateInput()` in shared/validation.ts → consumed in features/user.ts
   - URL params enter via `req.params` in api/routes.ts → NO sanitization found → used in features/search.ts
   Account for these flows when assessing injection/XSS severity.
   ```

```
Task("Security scan: src/features/", subagent_type: general-purpose,
  prompt: "... {include Data Flow Context} ...")
Task("Security scan: src/shared/api/", subagent_type: general-purpose,
  prompt: "... {include Data Flow Context} ...")
```

For scans with ≤10 files: skip pre-scan — orchestrator has full context.

### 2.5. Cross-Boundary Verification

After parallel agent results are collected, the **orchestrator** performs cross-boundary verification on injection/vulnerability findings:

1. **Filter**: From all findings, select those involving:
   - Injection vulnerabilities (SQL, command, XSS) where input origin is in another agent's scan scope
   - Authentication/authorization checks where the guard is in a different directory slice
   - Sensitive data exposure where the data source and the exposure point are in different slices

2. **Verify**: For each Critical or High finding:
   - Read the **upstream code** (where input enters or is sanitized)
   - Check: is the input actually sanitized before reaching the flagged consumption point?
   - If sanitized → downgrade: Critical → Low, High → Low (append "verified: input sanitized at {location}")
   - If NOT sanitized → keep severity, enrich with full data flow path

3. **Output**: Append verification summary before Output Results:
   ```
   Cross-Boundary Check: {N} injection/vulnerability findings verified
   ├─ Confirmed: {M} (severity kept — no upstream sanitization)
   ├─ Downgraded: {K} (false positive — sanitized upstream)
   └─ Skipped: {J} (single-file scope, no cross-boundary flow)
   ```

### 3. Security Check Items

#### A. Injection (A03:2021)
- Uses of `dangerouslySetInnerHTML`
- User input inserted directly into DOM/URL/queries
- Uses of `eval()`, `new Function()`

#### B. Broken Authentication (A07:2021)
- Hardcoded tokens or credentials
- API routes accessible without authentication
- Session management vulnerabilities

#### C. Sensitive Data Exposure (A02:2021)
- `.env` values exposed to the client (check framework-specific public env variables from Project Context)
- Sensitive information printed via console.log
- Internal details exposed in error messages

#### D. Security Misconfiguration (A05:2021)
- CORS configuration
- CSP headers
- Unnecessary debug mode enabled

#### E. XSS (A03:2021)
- Patterns that bypass React's default escaping
- URL parameters rendered without validation
- Dynamic injection of iframes or scripts

#### F. Dependencies (A06:2021)
- Packages with known vulnerabilities (dependency audit tool results)
- Outdated dependencies

### 4. Output Results

```markdown
## Security Scan Results

### Summary
| Severity | Count |
|----------|-------|
| Critical | {N} |
| High | {N} |
| Medium | {N} |
| Low | {N} |

### Findings

#### SEC-{NNN}: {title}
- **Category**: {OWASP code}
- **File**: {path}:{line}
- **Description**: {vulnerability details}
- **Impact**: {impact if exploited}
- **Mitigation**: {how to fix}

### Dependency Audit
{dependency audit command result summary — if executable}

### Recommended Actions
{prioritized fix suggestions}
```

### 5. Final Output

```
Security scan complete
├─ Scope: {file count} files
├─ Found: Critical {N} / High {N} / Medium {N} / Low {N}
└─ Recommended: {most urgent action}
```

## Notes

- **Read-only**: Does not modify code. Reports security issues only.
- **Minimize false positives**: Account for React's default XSS defenses. Report only genuinely dangerous patterns.
- **Handle sensitive data carefully**: Do not include actual token or password values in scan results.
- **Consider context**: Reflect security specifics for the project's framework environment (from Project Context).
