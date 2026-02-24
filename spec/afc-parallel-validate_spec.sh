#!/bin/bash
# shellcheck shell=bash


Describe "afc-parallel-validate.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when no argument provided"
    It "exits 1 and prints usage"
      When run script scripts/afc-parallel-validate.sh
      The status should eq 1
      The stderr should include "Usage"
    End
  End

  Context "when file not found"
    It "exits 1 and prints error"
      When run script scripts/afc-parallel-validate.sh /nonexistent/tasks.md
      The status should eq 1
      The stderr should include "not found"
    End
  End

  Context "when no [P] tasks exist"
    setup() {
      setup_tmpdir TEST_DIR
      cat > "$TEST_DIR/tasks.md" << 'EOF'
## Phase 1: Setup
- [ ] T001 Create base `src/base.js`
- [ ] T002 Create service `src/service.js`
EOF
    }

    It "exits 0 with no-P-tasks message"
      When run script scripts/afc-parallel-validate.sh "$TEST_DIR/tasks.md"
      The status should eq 0
      The output should include "no [P] tasks"
    End
  End

  Context "when [P] tasks have no file conflicts"
    setup() {
      setup_tmpdir TEST_DIR
      cat > "$TEST_DIR/tasks.md" << 'EOF'
## Phase 1: Setup
- [ ] T001 [P] Create A `src/a.js`
- [ ] T002 [P] Create B `src/b.js`
EOF
    }

    It "exits 0 and reports valid"
      When run script scripts/afc-parallel-validate.sh "$TEST_DIR/tasks.md"
      The status should eq 0
      The output should include "Valid"
    End
  End

  Context "when [P] tasks share a file in the same phase"
    setup() {
      setup_tmpdir TEST_DIR
      cat > "$TEST_DIR/tasks.md" << 'EOF'
## Phase 1: Setup
- [ ] T001 [P] Create A `src/shared.js`
- [ ] T002 [P] Modify A `src/shared.js`
EOF
    }

    It "exits 1 and reports conflict"
      When run script scripts/afc-parallel-validate.sh "$TEST_DIR/tasks.md"
      The status should eq 1
      The output should include "CONFLICT"
    End
  End

  Context "when same file appears in different phases"
    setup() {
      setup_tmpdir TEST_DIR
      cat > "$TEST_DIR/tasks.md" << 'EOF'
## Phase 1: Setup
- [ ] T001 [P] Create A `src/shared.js`

## Phase 2: Core
- [ ] T002 [P] Modify A `src/shared.js`
EOF
    }

    It "exits 0 as cross-phase conflicts are allowed"
      When run script scripts/afc-parallel-validate.sh "$TEST_DIR/tasks.md"
      The status should eq 0
      The output should include "Valid"
    End
  End
End
