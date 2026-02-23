---
name: selfish:research
description: "Technical research"
argument-hint: "[research topic]"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Write
  - WebSearch
  - WebFetch
  - Task
model: sonnet
---

# /selfish:research — Technical Research

> Investigates technical questions and summarizes conclusions.
> Results are persisted to .claude/selfish/memory/research/{topic}.md.

## Arguments

- `$ARGUMENTS` — (required) research topic (e.g., "Zustand v5 migration", "WebCodecs API comparison")

## Execution Steps

### 1. Analyze Topic

Extract from `$ARGUMENTS`:
- **Core question**: What do we need to know?
- **Context**: Why is it needed? (relevance to the current project)
- **Scope**: Depth vs breadth (specific library comparison? general technology trends?)

### 2. Check Existing Research

Check `.claude/selfish/memory/research/` directory for related prior research:
- If found: load existing content and decide whether an update is needed
- If not found: proceed with new research

### 3. Gather Information

Use Agent Teams — run independent investigations in parallel:

```
Task("WebSearch: {topic} official docs", subagent_type: "general-purpose")
Task("Codebase: analyze current usage patterns", subagent_type: "general-purpose")
```

Source priority:
1. **Official documentation** (WebSearch/WebFetch)
2. **Codebase** (existing patterns in the current project)
3. **Community** (GitHub Issues, blogs)

### 4. Summarize Conclusions

```markdown
# Research: {topic}

> Date: {YYYY-MM-DD}
> Related feature: {related feature or "general"}

## Core Question
{what we needed to know}

## Findings

### {subtopic 1}
{content}
**Source**: {URL} (verified {date})

### {subtopic 2}
{content}

## Option Comparison (if applicable)
| Criterion | {OptionA} | {OptionB} | {OptionC} |
|-----------|-----------|-----------|-----------|
| {criterion1} | {evaluation} | {evaluation} | {evaluation} |
| {criterion2} | {evaluation} | {evaluation} | {evaluation} |

## Conclusion
**Recommendation**: {choice or conclusion}
**Rationale**: {key reason}
**Caveats**: {pitfalls or constraints}

## Project Application
{how this can be applied in the current project}
```

### 5. Save

- Save to `.claude/selfish/memory/research/{topic-kebab-case}.md`
- If the file already exists, update it (refresh the date)

### 6. Final Output

```
Research complete
├─ Topic: {topic}
├─ Saved: .claude/selfish/memory/research/{filename}.md
├─ Conclusion: {one-line summary}
└─ Sources: {number of key sources}
```

## Notes

- **Current date basis**: Use WebSearch to verify up-to-date information rather than relying on knowledge cutoff.
- **Sources required**: Cite sources for all technical claims.
- **Project context**: Derive conclusions applicable to this project, not generic research.
- **Persistent storage**: Save to .claude/selfish/memory/research/ for reuse across sessions.
