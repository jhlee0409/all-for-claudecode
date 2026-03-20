# PR Analysis Prompt Template

Use this prompt for each Phase 1 parallel batch agent:

```
Analyze this PR without checking out the branch.

PR #{number}: {title}
Author: {author}
Branch: {headRefName}
Changed files: {changedFiles}, +{additions}/-{deletions}
Labels: {labels}
Review status: {reviewDecision}
Draft: {isDraft}

Steps:
1. Run: gh pr diff {number}
2. Run: gh pr view {number} --comments
3. Analyze the diff for:
   - What the PR does (1-2 sentence summary)
   - Risk level (see rubric below)
   - Complexity (see rubric below)
   - Whether build/test verification is needed (yes/no + reason)
   - Potential issues or concerns (max 3)
   - Suggested reviewers or labels if obvious

Risk rubric:
- Critical: changes trust boundaries, auth, data integrity, or core business logic with outage/breach potential
- High: significant blast radius — broad API changes, DB schema, cross-service contracts
- Medium: localized impact — single service/module, recoverable if broken
- Low: isolated, low blast radius — docs, tests, UI copy, config flags

Complexity rubric:
- High: multiple distinct concerns, crosses architectural boundaries, understanding one change requires another
- Medium: moderate cross-cutting, single domain with some interdependencies
- Low: single-concern, self-contained, easy to review independently

Output as structured text:
SUMMARY: ...
RISK: Critical|High|Medium|Low
COMPLEXITY: High|Medium|Low
NEEDS_DEEP: yes|no
DEEP_REASON: ... (if yes)
CONCERNS: ...
SUGGESTION: ...
```
