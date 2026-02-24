---
name: afc:security
description: "Security scan (read-only)"
argument-hint: "[scan scope: file/directory path or full]"
disable-model-invocation: true
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

Read the following settings from `CLAUDE.md` or `.claude/CLAUDE.md` at the project root and assign to the `config` variable:

```
config.framework  = the framework used in the project
                    (e.g., "Next.js", "Nuxt", "SvelteKit", "Express", "NestJS")
                    → Framework specified in CLAUDE.md. Assume "unknown" if not present.
config.auditCmd   = dependency audit command
                    (e.g., "yarn audit", "npm audit", "pnpm audit")
                    → Infer from the packageManager field in package.json or the lockfile.
```

## Execution Steps

### 1. Determine Scan Scope

- `$ARGUMENTS` = path → that path only
- `$ARGUMENTS` = "full" → entire `src/`
- Not specified → changed files from `git diff --name-only HEAD`

### 2. Agent Teams (if more than 10 files)

Use parallel agents for wide-scope scans:
```
Task("Security scan: src/features/", subagent_type: general-purpose)
Task("Security scan: src/shared/api/", subagent_type: general-purpose)
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
- `.env` values exposed to the client (check framework-specific public env variables for {config.framework})
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
{config.auditCmd} result summary — if executable

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
- **Consider context**: Reflect security specifics for the {config.framework} environment.
