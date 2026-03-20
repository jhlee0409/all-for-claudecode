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

Architecture, Code Style, and Project Context are auto-loaded via `.claude/rules/afc-project.md`.
Read `.claude/afc.config.md` if CI commands are needed.

If neither rules file nor config exists: read `CLAUDE.md` for framework info. Assume "unknown" if no source has it.

For dependency audit command: infer from `packageManager` field in `package.json` or the lockfile (e.g., `npm audit`, `yarn audit`, `pnpm audit`).

## Execution Steps

### 1. Determine Scan Scope

- `$ARGUMENTS` = path → that path only
- `$ARGUMENTS` = "full" → entire codebase
- Not specified → changed files from:
  !`git diff --name-only HEAD 2>/dev/null || echo "[GIT_DIFF_FAILED]"`

### 2. Agent Teams (when scan complexity warrants it)

Use Agent Teams when the scan scope is complex enough that a single-pass review would miss cross-file vulnerability patterns. Assess holistically:

- **File types**: Auth handlers, trust boundary code, and input-processing layers warrant deeper multi-agent scrutiny than config files or simple utilities
- **Code volume**: Large files with dense logic benefit from focused agent attention
- **Diversity of concerns**: Multiple distinct security domains (auth + injection + data exposure) across separate modules
- **Trust boundaries**: Files that cross privilege levels (user input → DB, client → server, public → internal API)

Use Agent Teams when any of the following apply:
- Scan includes auth handlers, session management, or access control logic spanning multiple files
- Input entry points and their sanitization/consumption code live in different directories
- The scope spans multiple distinct security domains that cannot be assessed in a single coherent pass

Use direct scan (orchestrator only) when:
- Scope is a single module or tightly-coupled set of files
- Security concerns are localized (e.g., one feature, one data flow)
- No cross-file trust boundary transitions are involved

**Pre-scan: Data Flow Context** (before distributing to agents, when using Agent Teams):

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

For direct scans (orchestrator only): skip pre-scan — orchestrator has full context.

### 2.5. Cross-Boundary Verification

Read `${CLAUDE_SKILL_DIR}/cross-boundary-verification.md` and apply it after parallel agent results are collected.

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
