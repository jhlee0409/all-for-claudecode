# Learner Signal Classification

> Reference for the keyword pre-filter used by `scripts/afc-learner-collect.sh`.
> Only high-confidence anchors are used to minimize false positives.

## Signal Types

| Signal Type | Category | Pattern Examples | Confidence |
|-------------|----------|-----------------|------------|
| `explicit-preference` | workflow | "from now on", "remember that", "remember this" | Highest |
| `explicit-preference` | workflow | "앞으로는", "앞으로 항상", "기억해" (Korean) | Highest |
| `universal-preference` | style | "always {X}", "never {X}" (sentence-start only) | High |
| `universal-preference` | style | "항상 {X}", "절대 {X}" (Korean, sentence-start) | High |
| `permanent-correction` | style | "don't ever", "do not ever", "stop using/doing" | High |
| `permanent-correction` | style | "금지", "쓰지마", "하지마" (Korean) | High |
| `convention-preference` | naming | "use X instead of Y", "prefer X over Y" | Medium |
| `convention-preference` | naming | "대신 X 써", "말고 X 써" (Korean) | Medium |

## Design Decisions

### Why keyword pre-filter (not LLM)?

1. **Latency**: UserPromptSubmit is on the critical path. Bash grep is <5ms; LLM round-trip is 500ms+.
2. **Cost**: Running haiku on every prompt is expensive. Keywords pre-filter to ~5% of prompts, and LLM classification happens in batch when `/afc:learner` is run.
3. **Precision over recall**: Missing a valid correction is acceptable (user can run `/afc:learner` manually). A false positive that annoys the user is not.

### What is NOT detected (by design)

These patterns look like corrections but are task-specific redirections:
- "No, I meant the other file" — task navigation, not preference
- "아니 그거 말고" — redirection, not behavioral correction
- "Use absolute paths here" — one-time instruction (no "always"/"from now on")

The batch LLM classifier in `/afc:learner` further filters false positives that pass the keyword gate.

## Queue Format (JSONL)

Each line in `.claude/.afc-learner-queue.jsonl`:
```json
{
  "signal_type": "explicit-preference",
  "category": "workflow",
  "excerpt": "from now on always run tests before committing",
  "timestamp": "2026-03-07T12:00:00Z",
  "source": "standalone"
}
```

- `excerpt`: Max 80 chars, redacted (secrets masked as `***REDACTED***`)
- `source`: `"standalone"` or `"pipeline:{feature}:{phase}"`
- Queue cap: 50 entries. TTL: 7 days (pruned at session start).

## Category Blocklist

The `/afc:learner` command MUST NOT generate rules about:
- File permissions or access control
- Security policies or authentication
- Approval workflows or hook behavior
- Tool access or Claude Code configuration

These categories require manual `CLAUDE.md` editing, not automated promotion.
