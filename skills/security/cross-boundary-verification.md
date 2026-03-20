# Cross-Boundary Verification

After parallel agent results are collected, the **orchestrator** performs cross-boundary verification on injection/vulnerability findings:

1. **Filter**: From all findings, select those involving:
   - Injection vulnerabilities (SQL, command, XSS) where input origin is in another agent's scan scope
   - Authentication/authorization checks where the guard is in a different directory slice
   - Sensitive data exposure where the data source and the exposure point are in different slices

2. **Verify**: For each Critical or High finding:
   - Read the **upstream code** (where input enters or is sanitized)
   - Check: is the input actually sanitized before reaching the flagged consumption point?
   - If sanitized → downgrade: Critical → Low, High → Low (append "verified: input sanitized at {location}")
   - If NOT sanitized → keep severity, enrich with full data flow path

3. **Output**: Append verification summary before Output Results:
   ```
   Cross-Boundary Check: {N} injection/vulnerability findings verified
   ├─ Confirmed: {M} (severity kept — no upstream sanitization)
   ├─ Downgraded: {K} (false positive — sanitized upstream)
   └─ Skipped: {J} (single-file scope, no cross-boundary flow)
   ```
