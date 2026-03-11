# Feature Spec: {feature name}

> Created: {YYYY-MM-DD}
> Branch: {BRANCH_NAME}
> Status: Draft

## Overview
{2-3 sentences on the purpose and background of the feature}

## User Stories

### US1: {story title} [P1]
**Description**: {feature description from user perspective}
**Priority rationale**: {why this order}
**Independent testability**: {whether this story can be tested on its own}

#### Acceptance Scenarios (GWT for user scenarios)
- [ ] Given {precondition}, When {action}, Then {result}
- [ ] Given {precondition}, When {action}, Then {result}

#### System Requirements (EARS notation)

> Use one of the 5 EARS patterns for each requirement. Each requirement must map to at least one expected test case (TC).

| Pattern | Template | Use When |
|---------|----------|----------|
| Ubiquitous | `THE System SHALL {behavior}` | Always-on property (no trigger needed) |
| Event-driven | `WHEN {trigger}, THE System SHALL {response}` | Specific event triggers a response |
| State-driven | `WHILE {state}, THE System SHALL {behavior}` | Behavior depends on system state |
| Unwanted | `IF {condition}, THE System SHALL {handling}` | Error/failure handling |
| Optional | `WHERE {feature/config active}, THE System SHALL {behavior}` | Feature flag or conditional capability |

- [ ] WHEN {trigger}, THE System SHALL {behavior} → TC: `should_{behavior}_when_{trigger}`
- [ ] WHILE {state}, THE System SHALL {behavior} → TC: `should_{behavior}_while_{state}`

### US2: {story title} [P2]
{same format}

## Requirements

### Functional Requirements
- **FR-001**: {requirement}
- **FR-002**: {requirement}

### Non-Functional Requirements
- **NFR-001**: {performance/security/accessibility etc.}

### Auto-Suggested NFRs
{Load `${CLAUDE_SKILL_DIR}/nfr-templates.md` and select 3-5 relevant NFRs based on the project type detected from afc.config.md}
- **NFR-A01** [AUTO-SUGGESTED]: {suggestion from matching project type template}
- **NFR-A02** [AUTO-SUGGESTED]: {suggestion}
- **NFR-A03** [AUTO-SUGGESTED]: {suggestion}
{Tag each with [AUTO-SUGGESTED]. Users may accept, modify, or remove.}

### Key Entities
| Entity | Description | Related Existing Code |
|--------|-------------|-----------------------|
| {name} | {description} | {path or "new"} |

## Success Criteria
- **SC-001**: {measurable success indicator}
- **SC-002**: {measurable success indicator}

## Edge Cases
- {edge case 1}
- {edge case 2}

## Constraints
- {technical/business constraints}

## [NEEDS CLARIFICATION]
- {uncertain items — record if any, remove section if none}
