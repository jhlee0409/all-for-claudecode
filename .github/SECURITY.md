# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 2.4.x   | Yes       |
| 2.3.x   | Yes       |
| < 2.3   | No        |

## Reporting a Vulnerability

**Do NOT open a public issue for security vulnerabilities.**

Please report security issues by emailing **relee6203@gmail.com** with:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Affected versions

### What to Expect

- **Acknowledgment**: within 48 hours
- **Assessment**: within 1 week
- **Fix timeline**: depends on severity (critical: ASAP, high: 1 week, medium: next release)

### Scope

This project is a Claude Code plugin (markdown commands + bash hook scripts). Security concerns typically involve:

- Hook scripts that process untrusted input (stdin JSON from Claude Code)
- Path traversal or injection in file-handling hooks
- State file manipulation that could bypass pipeline safety guards
- Permission escalation through hook responses

### Out of Scope

- Issues in Claude Code itself (report to [Anthropic](https://github.com/anthropics/claude-code/issues))
- Issues in ShellSpec test framework
- Theoretical attacks requiring local shell access (hooks run locally by design)
