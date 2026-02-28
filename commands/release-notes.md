---
name: afc:release-notes
description: "Generate user-facing release notes from git history"
argument-hint: "[v1.0.0..v2.0.0 | v2.0.0 | --post]"
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
model: sonnet
---

# /afc:release-notes — Generate Release Notes

> Rewrites commit/PR history into user-facing release notes and optionally publishes to GitHub Releases.
> This is a **standalone utility** — not part of the auto pipeline.
> Does NOT modify local files (CHANGELOG updates are handled by `/afc:launch`).

## Arguments

- `$ARGUMENTS` — (optional) Version range and flags
  - `v2.3.0..v2.4.0` — specific tag range
  - `v2.4.0` — from that tag to HEAD
  - Not specified — auto-detect last tag to HEAD
  - `--post` — publish to GitHub Releases after preview (can combine with any range)

Parse the arguments:
1. Extract `--post` flag if present
2. Parse remaining as version range:
   - If contains `..`: split into `{from_tag}..{to_tag}`
   - If single version: use `{version}..HEAD`
   - If empty: auto-detect with `git describe --tags --abbrev=0`

## Execution Steps

### 1. Determine Range

```bash
# Auto-detect last tag if no range specified
git describe --tags --abbrev=0 2>/dev/null
```

- If a tag is found, set `from_tag` to that tag, `to_tag` to HEAD
- If no tags exist, inform the user: "No tags found. Include all commits? (y/n)"
- If a `to_tag` is specified (not HEAD), verify it exists: `git rev-parse --verify {to_tag} 2>/dev/null`
- Determine the version label for the notes header:
  - If `to_tag` is a version tag: use it (e.g., `v2.4.0`)
  - If `to_tag` is HEAD: use "Unreleased" or the `from_tag` bumped (ask user)

### 2. Collect Raw Data

Run these commands to gather change context:

```bash
# Commit history (no merges)
git log {from_tag}..{to_tag} --pretty=format:"%H %s" --no-merges

# Merged PRs since the from_tag date
from_date=$(git log -1 --format=%aI {from_tag})
gh pr list --state merged --search "merged:>$from_date" --json number,title,author,labels,body --limit 100
```

If `gh` is not available or the repo has no remote, skip PR collection — proceed with git-only data.

### 3. Detect Breaking Changes

Search commit messages and PR titles for breaking change indicators:

- Patterns: `BREAKING`, `BREAKING CHANGE`, `!:` (conventional commits `feat!:`, `fix!:`)
- Also check PR labels for: `breaking`, `breaking-change`, `semver-major`

Flag any matches for the Breaking Changes section.

### 4. Categorize and Rewrite

Categorize each commit/PR into one of:

| Category | Conventional Commit Prefixes | Fallback Heuristics |
|----------|------------------------------|---------------------|
| Breaking Changes | `!:` suffix, `BREAKING` | Label: `breaking` |
| New Features | `feat:` | "add", "new", "implement", "support" |
| Bug Fixes | `fix:` | "fix", "resolve", "correct", "patch" |
| Other Changes | `chore:`, `docs:`, `ci:`, `refactor:`, `perf:`, `test:`, `style:`, `build:` | Everything else |

**Rewriting rules** — transform each entry from developer-speak to user-facing language:

1. Remove conventional commit prefixes (`feat:`, `fix(scope):`, etc.)
2. Rewrite in terms of **what the user experiences**, not what the developer changed
   - Bad: "Refactor ThemeProvider to use context API"
   - Good: "Improved theme switching reliability"
   - Bad: "Fix race condition in afc-state.sh"
   - Good: "Fixed an issue where pipeline state could become corrupted during concurrent execution"
3. Merge related commits into a single entry when they address the same feature/fix
4. Include PR number references where available: `(#42)`
5. For breaking changes, add a brief migration note after the description

### 5. Collect Contributor Info

Build a contributors section:

```bash
# Get commit authors with their commit counts
git log {from_tag}..{to_tag} --format="%aN" | sort | uniq -c | sort -rn

# Resolve repo identity for GitHub username lookup
gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"'

# Map git authors to GitHub usernames via commit SHAs
git log {from_tag}..{to_tag} --format="%H" | head -100 | while read sha; do
  gh api "repos/{owner}/{repo}/commits/$sha" --jq '.author.login // empty' 2>/dev/null
done | sort -u
```

For each contributor:
- Try to resolve GitHub username via the commit SHA lookup above, or from PR author data collected in step 2
- List their PR numbers if available
- Fall back to git author name if no GitHub username found
- If `gh` is not available, skip username resolution entirely — use git author names

### 6. Compose Release Notes

Assemble the final release notes in this format:

```markdown
# {version}

{2-3 sentence summary: what is the most important thing in this release? Written for end users.}

## Breaking Changes

- {description + migration guide}

## New Features

- {user-facing description} (#{pr_number})

## Bug Fixes

- {user-facing description} (#{pr_number})

## Other Changes

- {description} (#{pr_number})

## Contributors

{contributor list with @mentions and PR numbers}
```

**Format rules**:
- Omit empty sections entirely (if no breaking changes, skip that section)
- Breaking Changes section always comes first when present
- Each entry is a single bullet point, max 2 sentences
- Summary paragraph should highlight the top 1-2 changes
- Contributors section: `@username (#42, #45)` format, or `Name (#42)` if no GitHub username

### 7. Preview Output

Display the complete release notes to the user in the console.

Print a summary:
```
Release notes generated
├─ Version: {version}
├─ Range: {from_tag}..{to_tag}
├─ Commits: {N}
├─ PRs referenced: {N}
├─ Breaking changes: {count or "none"}
├─ Contributors: {N}
└─ --post: {will publish / preview only}
```

### 8. Publish to GitHub Releases (if --post)

If `--post` flag is present:

1. Determine the tag name:
   - If `to_tag` is a specific tag: use it
   - If `to_tag` is HEAD: ask the user what tag to create (suggest next version)

2. Ask user to confirm using AskUserQuestion:
   - **Post as-is** — Publish the GitHub Release immediately
   - **Post as draft** — Create as draft release (can review and publish later from GitHub)
   - **Edit first** — Let me modify the notes before posting
   - **Cancel** — Do not post

3. On approval, write to a temp file and publish:
   ```bash
   tmp_file=$(mktemp)
   cat > "$tmp_file" << 'NOTES_EOF'
   {release notes content}
   NOTES_EOF
   # Add --draft if user chose "Post as draft"
   gh release create {tag} --notes-file "$tmp_file" --title "{version}" [--draft]
   rm -f "$tmp_file"
   ```

4. Print result:
   ```
   GitHub Release published
   ├─ Tag: {tag}
   ├─ Title: {version}
   ├─ Status: {published / draft}
   └─ URL: {release URL from gh output}
   ```

If `--post` is not present, print:
```
To publish these notes as a GitHub Release, run again with --post flag.
```

## Notes

- **Read-only by default**: Without `--post`, this command only outputs to console. No files are created or modified.
- **Complements `/afc:launch`**: Use `launch` for local artifact generation (CHANGELOG, README). Use `release-notes` for GitHub Release publishing.
- **Conventional Commits aware**: Projects using conventional commits get better categorization. Projects without them still get reasonable results via heuristic matching.
- **Contributor attribution**: Best effort. GitHub username resolution requires `gh` CLI and repository access.
- **User confirmation required**: `--post` always asks for explicit approval before publishing to GitHub.
- **Idempotent**: Running without `--post` is safe to repeat. With `--post`, GitHub Releases for existing tags will fail (GitHub does not allow duplicate release tags).
