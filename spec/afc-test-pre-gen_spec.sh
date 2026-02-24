#!/bin/bash
# shellcheck shell=bash


Describe "afc-test-pre-gen.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when no argument provided"
    It "exits 1 and prints usage"
      When run script scripts/afc-test-pre-gen.sh
      The status should eq 1
      The stderr should include "Usage"
    End
  End

  Context "when file does not exist"
    It "exits 1 and prints error"
      When run script scripts/afc-test-pre-gen.sh /nonexistent/tasks.md
      The status should eq 1
      The stderr should include "not found"
    End
  End

  Context "when tasks file has only non-.sh targets"
    setup() {
      setup_tmpdir TEST_DIR
      cat > "$TEST_DIR/tasks.md" << 'EOF'
## Phase 1: Docs
- [ ] T001 [P] [US1] Update readme `docs/README.md`
- [ ] T002 [US1] Update config `schemas/config.json`
EOF
    }

    It "exits 0 with zero testable count"
      When run script scripts/afc-test-pre-gen.sh "$TEST_DIR/tasks.md" "$TEST_DIR/spec"
      The status should eq 0
      The output should include "Testable (.sh): 0"
      The output should include "Skipped (non-.sh): 2"
    End
  End

  Context "when tasks file has .sh targets"
    setup() {
      setup_tmpdir TEST_DIR
      cat > "$TEST_DIR/tasks.md" << 'EOF'
## Phase 1: Scripts
- [ ] T001 [P] [US1] Create blast radius script `scripts/new-script.sh`
EOF
    }

    It "exits 0 and generates spec skeleton"
      When run script scripts/afc-test-pre-gen.sh "$TEST_DIR/tasks.md" "$TEST_DIR/spec"
      The status should eq 0
      The output should include "Generated: 1"
      The stderr should include "Generated: new-script_spec.sh"
    End

    It "creates a spec file in output dir"
      When run script scripts/afc-test-pre-gen.sh "$TEST_DIR/tasks.md" "$TEST_DIR/spec"
      The status should eq 0
      The output should include "Testable (.sh): 1"
      The stderr should include "Generated: new-script_spec.sh"
      The path "$TEST_DIR/spec/new-script_spec.sh" should be exist
    End
  End

  Context "when spec file already exists"
    setup() {
      setup_tmpdir TEST_DIR
      mkdir -p "$TEST_DIR/spec"
      printf '# existing spec\n' > "$TEST_DIR/spec/existing_spec.sh"
      cat > "$TEST_DIR/tasks.md" << 'EOF'
## Phase 1: Scripts
- [ ] T001 [P] [US1] Update existing `scripts/existing.sh`
EOF
    }

    It "skips existing and reports count"
      When run script scripts/afc-test-pre-gen.sh "$TEST_DIR/tasks.md" "$TEST_DIR/spec"
      The status should eq 0
      The output should include "Already exists: 1"
      The stderr should include "Skip (exists): existing_spec.sh"
    End
  End

  Context "when tasks file is empty"
    setup() {
      setup_tmpdir TEST_DIR
      printf '' > "$TEST_DIR/tasks.md"
    }

    It "exits 0 with zero tasks analyzed"
      When run script scripts/afc-test-pre-gen.sh "$TEST_DIR/tasks.md" "$TEST_DIR/spec"
      The status should eq 0
      The output should include "Tasks analyzed: 0"
    End
  End

  Context "when tasks file has mixed targets"
    setup() {
      setup_tmpdir TEST_DIR
      cat > "$TEST_DIR/tasks.md" << 'EOF'
## Phase 1: Mixed
- [ ] T001 [P] [US1] Create script `scripts/alpha.sh`
- [ ] T002 [US1] Update docs `docs/guide.md`
- [ ] T003 [P] [US2] Create another `scripts/beta.sh`
EOF
    }

    It "reports correct testable and non-sh counts"
      When run script scripts/afc-test-pre-gen.sh "$TEST_DIR/tasks.md" "$TEST_DIR/spec"
      The status should eq 0
      The output should include "Testable (.sh): 2"
      The output should include "Skipped (non-.sh): 1"
      The output should include "Generated: 2"
      The stderr should include "Generated: alpha_spec.sh"
      The stderr should include "Generated: beta_spec.sh"
    End
  End

  Context "when generated skeleton content is verified"
    setup() {
      setup_tmpdir TEST_DIR
      cat > "$TEST_DIR/tasks.md" << 'EOF'
## Phase 1: Scripts
- [ ] T001 [P] [US1] Create blast radius script `scripts/afc-blast-radius.sh`
EOF
    }

    It "contains Describe and Pending in generated file"
      When run script scripts/afc-test-pre-gen.sh "$TEST_DIR/tasks.md" "$TEST_DIR/spec"
      The status should eq 0
      The output should include "Generated: 1"
      The stderr should include "Generated: afc-blast-radius_spec.sh"
      The contents of file "$TEST_DIR/spec/afc-blast-radius_spec.sh" should include "Describe"
      The contents of file "$TEST_DIR/spec/afc-blast-radius_spec.sh" should include "Pending"
    End
  End
End
