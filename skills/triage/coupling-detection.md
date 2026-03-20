# Cross-PR Coupling Detection

After Phase 1 (and Phase 2 if applicable) results are collected, detect file-level coupling between PRs:

1. Extract changed file lists from each PR's diff (available from Phase 1 agent outputs)
2. For each file, check if it appears in multiple PRs' changed file lists
3. If shared files are found, annotate affected PRs:
   ```
   COUPLING: PR #{A} and PR #{B} both modify {path/to/file}
   ```
4. Include coupling annotations in the Priority Actions table and per-PR details

This identifies merge-order dependencies and potential conflict risks that no single-PR agent can detect.
