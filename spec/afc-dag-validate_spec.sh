#!/bin/bash
# shellcheck shell=bash


Describe "afc-dag-validate.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when no argument provided"
    It "exits 1 and prints usage"
      When run script scripts/afc-dag-validate.sh
      The status should eq 1
      The stderr should include "Usage"
    End
  End

  Context "when file not found"
    It "exits 1 and prints error"
      When run script scripts/afc-dag-validate.sh /nonexistent/tasks.md
      The status should eq 1
      The stderr should include "not found"
    End
  End

  Context "when tasks file has no tasks"
    setup() {
      setup_tmpdir TEST_DIR
      printf '# Tasks\n\n## Phase 1: Setup\n' > "$TEST_DIR/tasks.md"
    }

    It "exits 0 with no-tasks message"
      When run script scripts/afc-dag-validate.sh "$TEST_DIR/tasks.md"
      The status should eq 0
      The output should include "no tasks"
    End
  End

  Context "when tasks file has valid DAG"
    setup() {
      setup_tmpdir TEST_DIR
      cat > "$TEST_DIR/tasks.md" << 'EOF'
## Phase 1: Setup
- [ ] T001 Create base `src/base.js`
- [ ] T002 Create service `src/service.js` depends: [T001]
- [ ] T003 Create test `src/test.js` depends: [T001, T002]
EOF
    }

    It "exits 0 and reports valid"
      When run script scripts/afc-dag-validate.sh "$TEST_DIR/tasks.md"
      The status should eq 0
      The output should include "Valid"
    End
  End

  Context "when tasks file has circular dependency"
    setup() {
      setup_tmpdir TEST_DIR
      cat > "$TEST_DIR/tasks.md" << 'EOF'
## Phase 1: Setup
- [ ] T001 Create A `src/a.js` depends: [T002]
- [ ] T002 Create B `src/b.js` depends: [T001]
EOF
    }

    It "exits 1 and reports cycle"
      When run script scripts/afc-dag-validate.sh "$TEST_DIR/tasks.md"
      The status should eq 1
      The output should include "CYCLE"
    End
  End
End
