#!/bin/bash
# shellcheck shell=bash


Describe "afc-blast-radius.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when no argument provided"
    It "exits 1 with usage message"
      When run script scripts/afc-blast-radius.sh
      The status should eq 1
      The stderr should include "Usage"
    End
  End

  Context "when given a non-existent file"
    It "exits 1 with error message"
      When run script scripts/afc-blast-radius.sh /nonexistent/plan.md
      The status should eq 1
      The stderr should include "not found"
    End
  End

  Context "when plan file has no file change entries"
    setup() {
      setup_tmpdir TEST_DIR
      cat > "$TEST_DIR/plan.md" << 'EOF'
# Plan

## Overview

This plan has no file change map table at all.
Just some descriptive text about what we want to do.
EOF
    }

    It "exits 0 with zero planned changes"
      When run script scripts/afc-blast-radius.sh "$TEST_DIR/plan.md" "$TEST_DIR"
      The status should eq 0
      The output should include "Planned changes: 0"
    End
  End

  Context "when plan file has .sh files with high fan-out"
    setup() {
      setup_tmpdir TEST_DIR
      mkdir -p "$TEST_DIR/scripts"

      # Create the common script that will be sourced by many others
      cat > "$TEST_DIR/scripts/common.sh" << 'SCRIPT'
#!/bin/bash
set -euo pipefail
common_func() { :; }
SCRIPT

      # Create 6 scripts that source common.sh (>5 = high fan-out)
      for i in 1 2 3 4 5 6; do
        cat > "$TEST_DIR/scripts/worker${i}.sh" << SCRIPT
#!/bin/bash
set -euo pipefail
source "\$(dirname "\$0")/common.sh"
echo "worker${i}"
SCRIPT
      done

      # Plan referencing common.sh
      cat > "$TEST_DIR/plan.md" << 'EOF'
# Plan

## File Change Map

| File | Action | Description | Lines |
|------|--------|-------------|-------|
| `scripts/common.sh` | Modify | update shared lib | ~20 |
EOF
    }

    It "reports high fan-out for common.sh"
      When run script scripts/afc-blast-radius.sh "$TEST_DIR/plan.md" "$TEST_DIR"
      The status should eq 0
      The output should include "High fan-out"
      The output should include "common.sh"
    End
  End

  Context "when circular dependency exists"
    setup() {
      setup_tmpdir TEST_DIR
      mkdir -p "$TEST_DIR/scripts"

      # a.sh sources b.sh
      cat > "$TEST_DIR/scripts/a.sh" << 'SCRIPT'
#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/b.sh"
SCRIPT

      # b.sh sources a.sh
      cat > "$TEST_DIR/scripts/b.sh" << 'SCRIPT'
#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/a.sh"
SCRIPT

      # Plan referencing a.sh
      cat > "$TEST_DIR/plan.md" << 'EOF'
# Plan

## File Change Map

| File | Action | Description | Lines |
|------|--------|-------------|-------|
| `scripts/a.sh` | Modify | update a | ~10 |
EOF
    }

    It "exits 1 and reports CYCLE"
      When run script scripts/afc-blast-radius.sh "$TEST_DIR/plan.md" "$TEST_DIR"
      The status should eq 1
      The output should include "CYCLE"
    End
  End

  Context "when hooks.json references a planned script"
    setup() {
      setup_tmpdir TEST_DIR
      mkdir -p "$TEST_DIR/scripts"
      mkdir -p "$TEST_DIR/hooks"

      # Create the planned script
      cat > "$TEST_DIR/scripts/my-hook.sh" << 'SCRIPT'
#!/bin/bash
set -euo pipefail
echo "hook"
SCRIPT

      # Create hooks.json that references the script
      cat > "$TEST_DIR/hooks/hooks.json" << 'EOF'
{
  "hooks": [
    {
      "event": "PostToolUse",
      "command": "scripts/my-hook.sh"
    }
  ]
}
EOF

      # Plan referencing the script
      cat > "$TEST_DIR/plan.md" << 'EOF'
# Plan

## File Change Map

| File | Action | Description | Lines |
|------|--------|-------------|-------|
| `scripts/my-hook.sh` | Modify | update hook | ~10 |
EOF
    }

    It "reports cross-references from hooks.json"
      When run script scripts/afc-blast-radius.sh "$TEST_DIR/plan.md" "$TEST_DIR"
      The status should eq 0
      The output should include "Cross-references"
      The output should include "my-hook.sh"
    End
  End

  Context "when given a directory instead of a file"
    setup() {
      setup_tmpdir TEST_DIR
      mkdir -p "$TEST_DIR/target_dir"

      # Create .sh files in the target directory
      cat > "$TEST_DIR/target_dir/alpha.sh" << 'SCRIPT'
#!/bin/bash
set -euo pipefail
echo "alpha"
SCRIPT

      cat > "$TEST_DIR/target_dir/beta.sh" << 'SCRIPT'
#!/bin/bash
set -euo pipefail
echo "beta"
SCRIPT
    }

    It "scans .sh files in the directory"
      When run script scripts/afc-blast-radius.sh "$TEST_DIR/target_dir" "$TEST_DIR"
      The status should eq 0
      The output should include "Planned changes: 2"
    End
  End
End
