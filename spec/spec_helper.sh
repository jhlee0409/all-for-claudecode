#!/bin/bash
# ShellSpec shared test helper
# Loaded automatically via --require spec_helper in .shellspec

# Project root (one level up from spec/)
SHELLSPEC_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Create an isolated tmpdir with .claude/ subdirectory.
# Exports CLAUDE_PROJECT_DIR and HOME to the tmpdir (prevents real HOME pollution).
# Usage: setup_tmpdir VAR_NAME  (sets VAR_NAME to the created path)
setup_tmpdir() {
  local _dir
  _dir=$(mktemp -d)
  mkdir -p "$_dir/.claude"
  export CLAUDE_PROJECT_DIR="$_dir"
  export HOME="$_dir"
  eval "$1=\$_dir"
}

# Create an isolated tmpdir with a bare git repo initialised.
# Usage: setup_tmpdir_with_git VAR_NAME
setup_tmpdir_with_git() {
  setup_tmpdir "$1"
  local _dir
  eval "_dir=\$$1"
  (
    cd "$_dir"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    git commit --allow-empty -m "init" -q 2>/dev/null
  )
}

# Remove a tmpdir created by setup_tmpdir or setup_tmpdir_with_git.
cleanup_tmpdir() {
  [ -n "${1:-}" ] && rm -rf "$1"
}

# Write a minimal afc.config.md fixture into <dir>/.claude/afc.config.md.
# Usage: setup_config_fixture <dir> [ci_command]
setup_config_fixture() {
  local dir="$1"
  local ci_cmd="${2:-npm run lint}"
  mkdir -p "$dir/.claude"
  cat > "$dir/.claude/afc.config.md" << EOF
## CI Commands

\`\`\`yaml
ci: "$ci_cmd"
gate: "$ci_cmd"
test: "npm test"
\`\`\`
EOF
}
