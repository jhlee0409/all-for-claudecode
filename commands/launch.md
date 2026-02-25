---
name: afc:launch
description: "Generate release artifacts"
argument-hint: "[version tag or 'auto']"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
model: sonnet
---

# /afc:launch — Generate Release Artifacts

> Generates release artifacts (CHANGELOG entry, README updates, GitHub Release notes) from git history and optional spec context.
> This is a **standalone utility** — not part of the auto pipeline.
> Works with or without a prior afc pipeline run.

## Arguments

- `$ARGUMENTS` — (optional) One of:
  - Version tag: `"v2.2.0"` — uses this as the release version
  - `"auto"` — auto-detects version from package.json/Cargo.toml/pyproject.toml
  - Not specified: prompts for version

## Execution Steps

### 1. Detect Project Context

1. **Version detection**:
   - If `$ARGUMENTS` is a version string (matches `v?\d+\.\d+\.\d+`): use it
   - If `$ARGUMENTS` = `"auto"`: read version from package.json → Cargo.toml → pyproject.toml → setup.py (first found)
   - If not specified: check package.json etc. for current version, present to user, confirm or override

2. **Previous version detection**:
   ```bash
   git describe --tags --abbrev=0 2>/dev/null || echo "none"
   ```
   - If a previous tag exists: diff range = `{previous_tag}..HEAD`
   - If no tags: diff range = all commits (warn user: "No previous release tag found. Including all history.")

3. **Changelog detection**:
   - Check for existing: `CHANGELOG.md` → `CHANGES.md` → `HISTORY.md`
   - If found: will prepend new entry
   - If not found: will create `CHANGELOG.md`

### 2. Gather Change Context

Collect all available context for high-quality release notes:

1. **Git history** (required):
   ```bash
   git log {previous_tag}..HEAD --pretty=format:"%h %s" --no-merges
   ```

2. **Changed files summary** (required):
   ```bash
   git diff --stat {previous_tag}..HEAD
   ```

3. **Spec context** (optional — enhances quality):
   - Glob `.claude/afc/specs/*/spec.md` — if any exist, read Overview and User Stories sections
   - This provides **intent context** that raw commit messages lack
   - If no specs found: rely on git history only (still produces good output)

4. **Review context** (optional):
   - Glob `.claude/afc/memory/reviews/*` — if any exist from this version cycle, note key findings
   - Skip if not found

5. **Breaking change detection**:
   - Grep commit messages for: `BREAKING`, `breaking change`, `!:` (conventional commits)
   - Grep diffs for: deleted public exports, renamed public APIs, changed function signatures
   - Flag any findings as breaking changes in the output

### 3. Generate CHANGELOG Entry

Prepend a new entry to the changelog file:

1. **Duplicate check**: Grep the changelog for `## [{version}]`. If an entry for this version already exists:
   - Ask user: "CHANGELOG already has an entry for {version}. (1) Overwrite (2) Abort"
   - If overwrite: replace the existing entry (from `## [{version}]` to the next `## [` line)
   - If abort: skip CHANGELOG generation

2. Follow the existing format if one exists; otherwise use [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
## [{version}] - {YYYY-MM-DD}

### Added
- {new features, described from user perspective}

### Changed
- {modifications to existing functionality}

### Fixed
- {bug fixes}

### Removed
- {removed features or deprecated items}

### Breaking Changes
- {if any — empty section omitted}
```

**Quality rules**:
- Write from **user perspective**, not developer perspective ("Add dark mode support" not "Add ThemeProvider component")
- Group related changes into single entries (don't list every file)
- If spec context is available: use feature names from specs, not commit message fragments
- Omit empty sections (if no fixes, don't include "### Fixed")

### 4. Update README (conditional)

Only update README if meaningful changes warrant it:

1. **Check triggers**:
   - New CLI commands or API endpoints added?
   - Installation process changed?
   - New dependencies or requirements?
   - Feature that users need to know about?

2. **If no triggers match**: skip README update entirely (print: "README: no updates needed")

3. **If triggers match**: read current README, identify the relevant section, apply minimal targeted edit
   - Do NOT rewrite the entire README
   - Do NOT add badges, shields, or decorative elements
   - Only update sections directly affected by changes

### 5. Generate GitHub Release Notes

Create `.claude/afc/release-notes.md` (draft for `gh release create`):

```markdown
# {version}

{2-3 sentence summary of this release — what's the headline?}

## Highlights

- {top 1-3 user-facing changes, expanded with context}

## What's Changed

{CHANGELOG entry content, reformatted for GitHub}

## Breaking Changes

{if any — clear migration instructions}

**Full Changelog**: {previous_tag}...{version}
```

### 6. Present Summary and Next Steps

```
Release artifacts generated: {version}
├─ CHANGELOG.md: entry prepended ({N} items across {M} categories)
├─ README.md: {updated section / no updates needed}
├─ .claude/afc/release-notes.md: draft created
├─ Breaking changes: {count or "none"}
├─ Commits included: {N} (since {previous_tag})
└─ Specs referenced: {N or "none (git-only mode)"}

Next steps:
  git add CHANGELOG.md README.md
  git commit -m "docs: prepare release {version}"
  git tag {version}
  gh release create {version} --notes-file .claude/afc/release-notes.md
```

**Do NOT execute these commands automatically.** Present them for the user to review and run.

## Notes

- **Not part of the auto pipeline**. Launch is a standalone utility invoked when you're ready to release, not after every feature.
- **Non-destructive**: only creates/edits CHANGELOG and README (conditionally). Does not push, tag, or create releases automatically.
- **Git history is the source of truth**. Spec context enhances quality but is never required.
- **Conventional Commits awareness**: if the project uses conventional commits (`feat:`, `fix:`, `chore:`), the generated CHANGELOG respects those categories.
- **Idempotent**: running launch twice with the same version overwrites the release-notes.md draft and re-generates the CHANGELOG entry (warns before overwriting).
- **No scope for `clean`**: release-notes.md in `.claude/afc/` is a draft file. The user decides whether to keep or delete it after the release.
