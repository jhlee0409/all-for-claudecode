---
name: afc:consult
description: "Expert consultation — use when the user asks for expert advice, wants to consult a specialist, needs domain-specific guidance on backend, infra, PM, design, marketing, legal, or tech decisions, or wants to think together, brainstorm, discuss ideas, or have a structured dialogue"
argument-hint: "[domain?] \"[question]\" [brief|deep]"
model: sonnet
---

# /afc:consult — Expert Consultation

> Consult a domain expert for advice tailored to your project.
> Each expert has persistent memory — they remember your project's decisions across sessions.
> Pipeline-independent: works anytime, no active pipeline required.

## Arguments

- `$ARGUMENTS` — (optional) Format: `[domain] "[question]" [brief|deep]`
  - `domain` — one of: `backend`, `infra`, `pm`, `design`, `marketing`, `legal`, `security`, `advisor`, `peer` (optional, auto-detected if omitted)
  - `question` — the consultation question (optional, enters exploratory mode if omitted)
  - `brief|deep` — depth hint (optional, default: `auto`)

## Execution Steps

### 1. Parse Arguments

Extract from `$ARGUMENTS`:
- **domain**: first word if it matches a known domain name
- **question**: remaining text after domain (if any), with quotes stripped
- **depth**: last word if it matches `brief` or `deep`

If `$ARGUMENTS` is empty → go to Step 2 (domain selection).

### 2. Domain Detection

**A. Explicit domain provided** → use it directly.

**B. No domain, but question provided** → keyword matching:

| Domain | Keywords |
|--------|----------|
| backend | API, database, schema, query, server, auth, JWT, REST, GraphQL, ORM, migration, endpoint, middleware, validation, session, cookie, token |
| infra | deploy, Docker, CI/CD, cloud, monitoring, k8s, pipeline, Kubernetes, terraform, AWS, GCP, Azure, nginx, SSL, DNS, CDN, container, scaling |
| pm | feature, user story, priority, roadmap, PRD, MVP, backlog, metric, KPI, retention, churn, persona, requirement, scope |
| design | UI, UX, accessibility, component, layout, color, animation, responsive, wireframe, prototype, typography, spacing, contrast, WCAG |
| marketing | SEO, analytics, content, growth, conversion, funnel, GA4, acquisition, retention, landing page, Open Graph, meta tag, social media |
| legal | GDPR, CCPA, privacy, cookie, consent, license, GPL, MIT, compliance, terms of service, data protection, PII, HIPAA, regulation, policy |
| security | XSS, CSRF, injection, OWASP, vulnerability, attack, exploit, encryption, secret, credential, CORS, CSP, rate limit, brute force, penetration |
| advisor | library, framework, stack, tool, package, which to use, alternative, compare, choose, select, recommend, what exists, ecosystem, best option, switch to |
| peer | think together, brainstorm, discuss, explore idea, talk through, figure out, pros and cons, what if, should I, direction, approach, trade-off, opinion, weigh options |

Match rules:
- Case-insensitive keyword matching against the question
- If multiple domains match: pick the one with the most keyword hits
- If tie: pick the first domain in the table order above

**C. No domain, no question, or no keyword match** → ask user:

Use AskUserQuestion:
```
"Which expert would you like to consult?"
Options:
1. Backend — API design, database, authentication, server architecture
2. Infra — deployment, CI/CD, cloud, monitoring, scaling
3. PM — product strategy, prioritization, user stories, metrics
4. Design — UI/UX, accessibility, components, user flows
5. Marketing — SEO, analytics, growth, content strategy
6. Legal — GDPR, privacy, licenses, compliance, terms of service
7. Security — application security, OWASP, threat modeling, secure coding
8. Advisor — technology/library/framework selection, ecosystem navigation, stack decisions
9. Peer — think together, brainstorm, discuss ideas, explore directions as equals
```

### 3. Peer Mode (if domain is `peer`)

If the detected domain is `peer`, **do not delegate to a subagent**. Run the dialogue directly in the main context.

#### Behavior Principles

You are a thinking partner, not an expert giving answers. Follow these rules:

1. **Ask before answering.** Default to questions that deepen the user's thinking, not solutions. "What would happen if...?", "What are you optimizing for?"
2. **Challenge, don't agree.** Apply the Anti-Sycophancy Rules from `expert-protocol.md`. When the user states a direction, probe its weaknesses before supporting it.
3. **Present the strongest counter-argument.** Steel-man the opposing view: "The best case for NOT doing this is..."
4. **Name what's been decided and what hasn't.** Periodically summarize: "So far we've landed on X. Still open: Y and Z."
5. **Suggest convergence, don't force it.** When the discussion feels circular or key decisions are made, say so: "I think we have enough to move forward. Want to wrap up?"

#### Coaching Techniques

Use these as appropriate — not all at once, not in order:

- **5 Whys** — repeat "why?" to reach the root motivation
- **Pre-mortem** — "If this fails in 6 months, what went wrong?"
- **Constraint flip** — "What if you had half the time?" / "What if cost didn't matter?"
- **Steel-manning** — present the strongest version of the opposing view
- **Bisection** — "Is the core question A or B?" to narrow scope

#### Codebase Context

If the discussion involves the current project:
- Read relevant files (Read/Glob/Grep) to ground the conversation in reality
- Reference actual code, not hypothetical structures
- Note existing patterns that constrain or enable options

#### Wrapping Up

When the user signals completion (or agrees to your convergence suggestion):

1. Write `.claude/afc/discuss.md` with:

```markdown
# Discussion: {topic}

> Date: {YYYY-MM-DD}
> Seed: {original question/topic}

## Key Decisions
- [DECIDED] {decision} — {rationale}

## Open Questions
- [OPEN] {unresolved item}

## Summary
{3-5 sentence synthesis of what was discussed and concluded}

## Next Steps
- {recommended action, e.g., → /afc:spec "...", → /afc:plan "...", → /afc:research "..."}
```

2. Output:
```
Discussion complete
├─ .claude/afc/discuss.md
├─ Decisions: {count}
├─ Open questions: {count}
└─ Suggested next: {command}
```

**Skip Steps 4-6 and end here.**

---

### 3b. Construct Expert Prompt (non-peer domains)

Build the prompt for the expert agent:

```
You are being consulted via /afc:consult.

## Question
{question or "No specific question — enter exploratory diagnostic mode. Ask the user probing questions to uncover what they need help with."}

## Depth
{brief|deep|auto}

## Instructions
1. Follow your Session Start Protocol (read project profile, domain adapter, memory, pipeline state)
2. Follow the Communication Rules from expert-protocol.md
3. Provide your consultation following the Progressive Disclosure format
4. Update your MEMORY.md with any confirmed decisions or new project insights
```

### 4. Delegate to Expert Agent

Invoke the expert agent via Task(). Map the detected domain to the corresponding agent:

| Domain | subagent_type |
|--------|---------------|
| backend | `afc:afc-backend-expert` |
| infra | `afc:afc-infra-expert` |
| pm | `afc:afc-pm-expert` |
| design | `afc:afc-design-expert` |
| marketing | `afc:afc-marketing-expert` |
| legal | `afc:afc-legal-expert` |
| security | `afc:afc-appsec-expert` |
| advisor | `afc:afc-tech-advisor` |

Example for each domain:
```
Task("backend consultation", subagent_type: "afc:afc-backend-expert", prompt: "...")
Task("infra consultation", subagent_type: "afc:afc-infra-expert", prompt: "...")
Task("pm consultation", subagent_type: "afc:afc-pm-expert", prompt: "...")
Task("design consultation", subagent_type: "afc:afc-design-expert", prompt: "...")
Task("marketing consultation", subagent_type: "afc:afc-marketing-expert", prompt: "...")
Task("legal consultation", subagent_type: "afc:afc-legal-expert", prompt: "...")
Task("security consultation", subagent_type: "afc:afc-appsec-expert", prompt: "...")
Task("advisor consultation", subagent_type: "afc:afc-tech-advisor", prompt: "...")
```

The agent runs in foreground (never `run_in_background`).

### 5. Relay Response

Return the agent's response to the user as-is. Do not summarize or filter the expert's output.

### 6. Follow-up Prompt

After relaying the response, suggest:

```
Follow-up options:
- Ask a deeper question on this topic
- Consult another expert: /afc:consult {other-domain}
- If a recommendation involves code changes: /afc:auto or /afc:implement
```

## Examples

```bash
# Specific domain + question
/afc:consult backend "Should I use JWT or session cookies for auth?"

# Auto-detect domain from question
/afc:consult "My API is slow when loading the dashboard"

# Exploratory mode (Socratic diagnostic)
/afc:consult backend

# With depth hint
/afc:consult infra "How should I set up CI/CD?" deep

# Peer mode — think together (explicit)
/afc:consult peer "Should we split this into a monorepo or keep it separate?"

# Peer mode — auto-detected from keywords
/afc:consult "Let's think through the onboarding flow together"

# No arguments (domain selection prompt)
/afc:consult
```

## Notes

- **Limited write scope**: Expert agents MUST only write to pipeline and memory paths (`.claude/afc/` and `.claude/agent-memory/`). Writing to application source code is prohibited. If an expert recommends code changes, they return the recommendation as text — the user or orchestrator applies it.
- **Persistent memory**: Each expert remembers your project's decisions across sessions (stored in `.claude/agent-memory/afc-{domain}-expert/MEMORY.md`).
- **Project profile**: Shared context at `.claude/afc/project-profile.md` — auto-created on first consultation, review and adjust as needed.
- **Domain adapters**: Industry-specific guardrails (fintech, ecommerce, healthcare) auto-loaded based on project profile.
- **Pipeline-independent**: Works anytime, no active pipeline required. If a pipeline is active, experts consider the current phase context.
- **Cross-referral**: Experts may suggest consulting another domain expert when a question crosses boundaries.
- **Peer mode**: Unlike other domains, `peer` runs directly in the main context (no subagent). It produces `.claude/afc/discuss.md` on wrap-up. Overwritten on each new peer session — rename to preserve.
