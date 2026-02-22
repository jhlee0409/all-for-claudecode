# Critic Loop Rules

> The purpose of the Critic Loop is to **find defects in the output without fail**. Listing only "PASS" results is equivalent to not running the Critic at all.

## Required Principles

1. **Minimum findings**: In each Critic round, **at least 1 concern, improvement point, or verification rationale per criterion** must be stated. If there are no issues, explain specifically "why there are no issues."
2. **Checklist responses**: For each criterion, output takes the form of answering specific questions. Single-word "PASS" is prohibited.
3. **Adversarial Pass**: At the end of every round, **"1 scenario in which this output fails"** must be stated. If the scenario is realistic, convert to FAIL and fix.
4. **Quantitative rationale**: Instead of qualitative judgments like "none" or "compliant," present quantitative data such as "M of N confirmed," "Y of X lines applicable."

## Verdict System (4 types)

Each criterion receives one of these verdicts:

| Verdict | Meaning | Action |
|---------|---------|--------|
| `PASS` | No defect found (quantitative evidence required) | Criterion clean |
| `FAIL` | Clear defect, auto-fixable | Fix it, continue to next pass |
| `ESCALATE` | Ambiguous or requires user judgment | Pause loop, present options to user, resume after response |
| `DEFER` | Cannot be resolved in current phase, acknowledged only | Record reason, criterion clean |

## Convergence Termination

The critic loop terminates when **all four** conditions are met:

1. **All criteria PASS or DEFER** — zero FAIL items remaining
2. **Adversarial scenario unrealistic** — with quantitative evidence
3. **No new findings** — zero concerns not found in previous passes
4. **Stability** — if 2+ passes ran, zero fixes applied in the last pass

**Fast path**: If Pass 1 achieves all PASS + unrealistic adversarial, terminate in 1 pass (preserves current behavior for simple outputs).

**Safety cap**: Each command defines a maximum pass count. If the cap is reached without convergence, terminate with a warning.

## ESCALATE Triggers

Classify a finding as ESCALATE when:
- **Multiple valid approaches**: 2+ solutions with non-trivial tradeoffs
- **Subjective judgment**: Decision depends on user/business context
- **Scope boundary**: In-scope vs out-of-scope depends on user intent
- **Principle conflict**: Two valid constraints in the config conflict with each other
- **Missing information**: Spec/plan lacks information only the user can provide

Do **not** ESCALATE when:
- Clear defect + single solution exists → FAIL + auto-fix
- Data is computable (line counts, coverage percentages) → compute it directly
- Project rules clearly dictate the answer (style violations) → FAIL + auto-fix

## Escalation Format

```
=== CRITIC ESCALATION ({N}) ===
[{CRITERION}] {question about the discovered issue}

Issue: {1-2 sentence description}
Why escalation: {why the model cannot resolve this autonomously}

Options:
  1. {Option A} — {description}
     Pro: {advantage}  Con: {disadvantage}
  2. {Option B} — {description}
     Pro: {advantage}  Con: {disadvantage}
  3. Skip — keep current state, mark as [DEFERRED]
```

- **Interactive mode**: use AskUserQuestion, wait for response, apply choice, resume loop
- **Auto mode**: same escalation behavior (auto = "automate clear decisions, ask about ambiguous ones")
- **Batching**: if multiple ESCALATEs occur in one pass, batch up to 3 per question

## Output Format

```
=== CRITIC {N} ===
[Criterion1] {question} → {answer + quantitative rationale}
  Verdict: PASS | FAIL ({fix description}) | ESCALATE | DEFER ({reason})
[Criterion2] ...
[ADVERSARIAL] Failure scenario: {specific scenario}
  → Realistic? {Y → FAIL + fix / N → state rationale}
=== Result: {CONVERGED ({N} passes, {M} fixes, {E} escalations) | CONTINUE ({N} fixed) | ESCALATE ({N} items) | SAFETY CAP} ===
```

## Result Keywords

| Keyword | Meaning |
|---------|---------|
| `CONVERGED` | All termination conditions met, loop ends |
| `CONTINUE (N fixed)` | FAIL items were fixed, next pass required |
| `ESCALATE (N items)` | Loop paused, awaiting user input on N items |
| `SAFETY CAP` | Maximum passes reached without convergence |

## Completion Summary

On convergence or safety cap, output:

- Converged: `✓ Critic converged ({N} passes, {M} fixes, {E} escalations)`
- Safety cap: `⚠ Critic safety cap ({N} passes). Review recommended.`
