---
name: afc:ideate
description: "Explore and structure a product idea — brainstorm, ideate, create product brief"
argument-hint: "[rough idea or problem statement]"
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - WebSearch
  - WebFetch
model: sonnet
---

# /afc:ideate — Explore and Structure a Product Idea

> Transforms a rough idea, problem statement, or inspiration into a structured product brief (ideate.md).
> This is a **pre-spec exploration** tool — use it when you don't yet know exactly what to build.
> The output feeds directly into `/afc:spec` as input.

## Relationship to Other Commands

```
afc:ideate (what to build?) → afc:spec (how to specify it) → afc:plan → afc:implement → ...
```

- **ideate** = "I have an idea but haven't decided the scope, audience, or approach yet"
- **spec** = "I know what to build and need a formal specification"
- ideate is **never** part of the auto pipeline — it's a standalone exploration tool

## Arguments

- `$ARGUMENTS` — (required) One of:
  - Rough idea: `"real-time collaborative whiteboard"`
  - Problem statement: `"users keep losing unsaved work when the browser crashes"`
  - Reference URL: `"https://example.com/competitor-product"` (fetched and analyzed)
  - File path: `"./meeting-notes.md"` (read and extracted)

## Execution Steps

### 1. Parse Input

Determine the input type and extract raw content:

1. **If `$ARGUMENTS` starts with `http://` or `https://`**:
   - Fetch content via WebFetch
   - Extract: product name, key features, target audience, value proposition
   - Frame as: "Build something similar/better that addresses {gap}"

2. **If `$ARGUMENTS` is a file path** (contains `/` or ends with `.md`/`.txt`):
   - Read the file content
   - Extract: action items, feature requests, pain points, user feedback
   - Frame as: structured requirements from raw notes

3. **Otherwise**: treat as a natural language idea/problem statement

### 2. Market & Context Research

Perform lightweight research to ground the idea in reality:

1. **Competitive landscape** (WebSearch):
   - Search: `"{core concept}" tool OR app OR service {current year}`
   - Identify 3-5 existing solutions
   - Note: what they do well, what gaps exist

2. **Technology feasibility** (WebSearch, optional):
   - If the idea involves unfamiliar tech: search for current state and constraints
   - Tag findings with `[RESEARCHED]`

3. **Target user validation**:
   - Who would use this? Why? What's their current workaround?

### 3. Explore Existing Codebase (if applicable)

If running inside a project with source code:

1. Check if any related functionality already exists (Glob/Grep)
2. If found: note as "Existing foundation" — ideate around extending, not rebuilding
3. If no codebase or greenfield: skip this step

### 4. Write Product Brief

Create `.claude/afc/ideate.md` (overwrite if exists after confirmation) using the template in `${CLAUDE_SKILL_DIR}/brief-template.md`. Read it first, then generate the brief using that structure.

### 5. Interactive Refinement

After writing the initial brief, present key decisions to the user:

1. **Scope check**: "The MVP has {N} features. Does this feel right, or should we cut/add?"
2. **Persona validation**: "Is {persona} the right primary user?"
3. **Open questions**: present the top 2 unresolved questions via AskUserQuestion

Apply user feedback directly into ideate.md.

### 6. Final Output

```
Ideation complete
├─ .claude/afc/ideate.md
├─ Personas: {count}
├─ MVP features: {count}
├─ Competitors analyzed: {count}
├─ Open questions: {count}
├─ Research sources: {count}
└─ Next step: /afc:spec "{suggested feature description}"
```

## Notes

- **This is exploration, not specification**. Do not write acceptance criteria, system requirements, or FR/NFR numbers — that belongs in `/afc:spec`.
- **ideate.md lives at `.claude/afc/ideate.md`** (project-level, not feature-level) because ideation may span multiple features.
- **Not part of the auto pipeline**. ideate is manually invoked when a developer needs to think through an idea before committing to a spec.
- **One ideate.md per project** — overwrite on re-run (with confirmation). If you need to preserve a previous ideation, rename it first.
- **Competitive analysis is lightweight** — 3-5 competitors max. Deep market research is not the goal; grounding the idea in reality is.
- **Mermaid diagrams are optional** — only include if the user flow benefits from visualization. Do not force diagrams for simple concepts.
