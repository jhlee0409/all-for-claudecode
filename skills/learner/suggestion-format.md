# Suggestion Presentation Format

Present each clustered pattern suggestion in this format:

```markdown
## Learned Patterns ({N} pending, showing top {M})

### 1. [{Rule type}] {Short title}
- Detected: {count} times across {sessions} sessions
- Confidence: {HIGH / MEDIUM / LOW}
- Proposed rule:
  ```
  {Concise, actionable rule text}
  ```
- Target: `.claude/rules/afc-learned.md` ({scope: universal / file-type-specific})
- [Approve] [Edit] [Skip] [Reject permanently]
```

## Example

```markdown
### 1. [Style] Prefer const over let
- Detected: 3 times across 2 sessions
- Confidence: HIGH
- Proposed rule:
  ```
  Prefer `const` for variable declarations. Use `let` only when reassignment is required.
  ```
- Target: `.claude/rules/afc-learned.md` (universal)
- [Approve] [Edit] [Skip] [Reject permanently]

### 2. [Naming] No default exports in React components
- Detected: 2 times (pipeline: auth-feature)
- Confidence: HIGH
- Proposed rule:
  ```
  In React component files (*.tsx), use named exports only. Avoid default exports.
  ```
- Target: `.claude/rules/afc-learned.md` (universal — scope expressed in prose)
- [Approve] [Edit] [Skip] [Reject permanently]
```

## User Response Handling

Wait for user response on each suggestion:
- **Approve**: promote to rules file
- **Edit**: user modifies the rule text, then promote
- **Skip**: remove from queue, do not promote
- **Reject permanently**: remove from queue + add to suppression list
