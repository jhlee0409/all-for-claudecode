# Review Perspectives (A–H)

Detailed criteria for each review perspective used by `/afc:review`.

## A. Code Quality

- `{config.code_style}` compliance (any usage, missing types)
- Naming conventions (handleX, isX, UPPER_SNAKE)
- Duplicate code
- Unnecessary complexity

## B. Architecture (agent-enhanced when available)

- Layer dependency direction violations (lower→upper imports)
- Segment rules (api/, model/, ui/, lib/)
- Appropriate layer placement
- **Agent bonus**: ADR conflict detection, cross-session pattern recognition

## C. Security (agent-enhanced when available)

- XSS vulnerabilities (dangerouslySetInnerHTML, unvalidated user input)
- Sensitive data exposure
- SQL/Command injection
- **Agent bonus**: false positive filtering, known vulnerability pattern matching

## D. Performance

- Startup/response latency concerns
- Unnecessary computation or redundant operations
- Resource management (memory, file handles, connections, subprocesses)
- Framework-specific performance patterns (from Project Context)

## E. Project Pattern Compliance

- `{config.code_style}` naming and structure conventions
- `{config.architecture}` layer rules and boundaries
- Framework-specific idioms and best practices (from Project Context)

## F. Reusability

- Duplicate or near-duplicate logic across files
- Opportunities to extract shared utilities or helpers
- DRY principle adherence (same logic repeated in multiple places)
- Appropriate abstraction level (not premature, not missing)

## G. Maintainability

- Function/file size — can a developer or LLM understand each unit in isolation?
- Naming clarity — do names reveal intent without requiring surrounding context?
- Self-contained files — minimal cross-file dependencies for comprehension
- Comments where logic is non-obvious (present where needed, absent where redundant)

## H. Extensibility

- Can new variants or features be added without modifying existing code?
- Are there clear extension points (configuration, plugin hooks, strategy patterns)?
- Open/Closed principle adherence where applicable
- Future modification cost — would a reasonable feature request require rewriting or only extending?

---

## Reverse Impact Analysis

Before reviewing, identify **files affected by the changes** (not just the changed files themselves):

1. **For each changed file**, find files that depend on it:
   - **LSP (preferred)**: `LSP(findReferences)` on exported symbols — tracks type references, function calls, re-exports
   - **Grep (fallback)**: `Grep` for `import.*{filename}`, `require.*{filename}`, `source.*{filename}` patterns across the codebase
   - Use both when LSP is available (LSP catches type-level references Grep misses; Grep catches dynamic patterns LSP misses)

2. **Build impact map**:
   ```
   Impact Map:
   ├─ src/auth/login.ts (changed)
   │  └─ affected: src/pages/LoginPage.tsx, src/middleware/auth.ts
   ├─ scripts/afc-state.sh (changed)
   │  └─ affected: scripts/afc-stop-gate.sh, scripts/afc-drift.sh (grep: source.*afc-state)
   └─ Total: {N} changed files → {M} affected files
   ```

3. **Scope decision**: Affected files are NOT full review targets. Include them as cross-reference context during review and Cross-Boundary Verification.

4. **Limitations** (include in review output):
   > ⚠ Dynamic dependencies not covered: runtime dispatch (`obj[method]()`), reflection, cross-language calls, config/env-driven branching. Manual verification recommended for these patterns.

---

## Cross-Boundary Verification (MANDATORY)

After individual/parallel reviews complete, the **orchestrator** MUST perform a cross-boundary check. Skipping it is a review defect.

**Especially critical for swarm reviews**: individual agents cannot see cross-file interactions.

0. **Impact Map integration**: Use the Impact Map to prioritize verification. Affected files with significant coupling to changed symbols (behavioral call references, not just type imports, especially in critical code paths) should be read and checked for breakage.

1. **Filter**: From all collected findings, select those involving:
   - Call order changes (function A now calls B before C)
   - Error handling modifications (try/catch scope changes, error propagation changes)
   - State mutation changes (new writes to shared state, removed cleanup)

2. **Verify**: For each behavioral finding rated Critical or Warning:
   - **Read the callee's implementation** (mandatory, not optional)
   - **Skip external dependencies**: If callee is in `node_modules/`, `vendor/`, or other third-party directories, verify against type definitions or documented API contract. Note: "verified against types/docs, not source"
   - Check: does the callee's internal behavior (side effects, state changes, return values) conflict with the change?
   - If no conflict → downgrade: Critical → Info, Warning → Info (append "verified: no cross-boundary impact")
   - If confirmed conflict → keep severity, enrich description with callee behavior details

3. **False positive reference** (security findings only): Check `afc-security` agent's MEMORY.md (at `.claude/agent-memory/afc-security/MEMORY.md`) `## False Positives` section if the file exists.

4. **Output**: Append verification summary before Review Output:
   ```
   Cross-Boundary Check: {N} behavioral findings verified
   ├─ Confirmed: {M} (severity kept)
   ├─ Downgraded: {K} (false positive — callee compatible)
   └─ Skipped: {J} (no behavioral change)
   ```

This step runs in the orchestrator context (not delegated), as it requires reading code across file boundaries that individual review agents cannot see.
