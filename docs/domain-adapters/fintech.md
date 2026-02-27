# Fintech Domain Adapter

> Guardrails for financial technology projects. Auto-loaded when project-profile domain is `fintech`.

## Compliance Requirements

- **PCI-DSS**: If handling card data — never store raw card numbers, use tokenization
- **PSD2/SCA**: Strong Customer Authentication for EU payment flows
- **SOX**: Audit trails for financial transactions (immutable logs)
- **KYC/AML**: Identity verification requirements for onboarding

## Data Handling Rules

- All monetary values: use integer cents (not floating-point)
- Currency must always be stored alongside amounts (never assume a default)
- Financial calculations: use decimal/bigint libraries, never IEEE 754 floats
- Transaction logs: append-only, never delete or modify
- PII encryption at rest: names, SSN, account numbers

## Domain-Specific Guardrails

- Idempotency keys required on all mutation endpoints (prevent duplicate transactions)
- Rate limiting on authentication and transaction endpoints
- Request signing for inter-service communication
- Webhook verification (signature validation) for payment provider callbacks

## Security Heightened Checks

- No sensitive data in URL query parameters (appears in logs)
- No financial data in client-side storage (localStorage, sessionStorage)
- Timeout on financial sessions (15 min max idle)
- Multi-factor authentication for admin/financial operations
- IP allowlisting for admin endpoints

## Testing Requirements

- Edge cases: zero amounts, negative amounts, maximum amounts, currency conversion rounding
- Concurrency: simultaneous transactions on same account (race conditions)
- Failure modes: payment provider timeout, partial failures, rollback scenarios

## Scale Considerations

- Transaction volume: reconciliation batch jobs at scale
- Real-time vs batch processing thresholds
- Read replica strategy for reporting queries
