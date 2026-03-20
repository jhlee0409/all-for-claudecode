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

**B. No domain, but question provided** → intent-based evaluation:

| Domain | When to route |
|--------|---------------|
| backend | Server-side logic, data modeling, API design, authentication flows, database decisions |
| infra | Deployment, CI/CD pipelines, cloud services, scaling, reliability, monitoring |
| pm | What to build, for whom, when, how to measure success, prioritization, scope |
| design | Visual hierarchy, interaction patterns, accessibility, component design, user flow |
| marketing | SEO, content strategy, acquisition funnels, analytics tracking, growth tactics |
| legal | Regulatory obligations, license compatibility, privacy requirements |
| security | Threats, vulnerabilities, attack surfaces, threat modeling, compliance |
| advisor | Choosing between technologies, frameworks, libraries, or architectural approaches |
| peer | Think through a problem collaboratively, explore directions, weigh trade-offs |

Identify the PRIMARY expertise gap — what specialized knowledge does the user need most?

**C. No domain, no question** → ask user:

```
"Which expert would you like to consult?"
1. Backend — API design, database, authentication, server architecture
2. Infra — deployment, CI/CD, cloud, monitoring, scaling
3. PM — product strategy, prioritization, user stories, metrics
4. Design — UI/UX, accessibility, components, user flows
5. Marketing — SEO, analytics, growth, content strategy
6. Legal — GDPR, privacy, licenses, compliance, terms of service
7. Security — application security, OWASP, threat modeling, secure coding
8. Advisor — technology/library/framework selection, stack decisions
9. Peer — think together, brainstorm, explore directions as equals
```

### 3. Peer Mode (if domain is `peer`)

Do not delegate to a subagent. Run dialogue directly in the main context.

See [peer-mode.md](peer-mode.md) for full behavior, coaching techniques, and wrap-up protocol.

**Skip Steps 3b–6 and end here.**

---

### 3b. Construct Expert Prompt (non-peer domains)

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

```
Task("{domain} consultation", subagent_type: "afc:afc-{domain}-expert", prompt: "...")
```

The agent runs in foreground (never `run_in_background`).

### 5. Relay Response

Return the agent's response to the user as-is. Do not summarize or filter.

### 6. Follow-up Prompt

```
Follow-up options:
- Ask a deeper question on this topic
- Consult another expert: /afc:consult {other-domain}
- If a recommendation involves code changes: /afc:auto or /afc:implement
```

## Examples

```bash
/afc:consult backend "Should I use JWT or session cookies for auth?"
/afc:consult "My API is slow when loading the dashboard"   # auto-detect
/afc:consult backend                                        # exploratory mode
/afc:consult infra "How should I set up CI/CD?" deep
/afc:consult peer "Should we split this into a monorepo?"
/afc:consult "Let's think through the onboarding flow together"
/afc:consult                                                # domain selection prompt
```

## Notes

- **Limited write scope**: Expert agents MUST only write to `.claude/afc/` and `.claude/agent-memory/`. Writing to application source code is prohibited.
- **Persistent memory**: Stored in `.claude/agent-memory/afc-{domain}-expert/MEMORY.md`.
- **Project profile**: Shared context at `.claude/afc/project-profile.md` — auto-created on first consultation.
- **Domain adapters**: Industry-specific guardrails (fintech, ecommerce, healthcare) auto-loaded based on project profile.
- **Cross-referral**: Experts may suggest consulting another domain when a question crosses boundaries.
- **Peer mode**: Runs in main context, not subagent. Produces `.claude/afc/discuss.md` on wrap-up. See [peer-mode.md](peer-mode.md).
