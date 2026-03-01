#!/bin/bash
# shellcheck shell=bash


Describe "afc-preflight-check.sh"
  setup() {
    setup_tmpdir_with_git TEST_DIR
    setup_config_fixture "$TEST_DIR"
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when no active pipeline"
    It "exits 0 and outputs Preflight Check"
      When run script scripts/afc-preflight-check.sh
      The status should eq 0
      The output should include "Preflight Check"
      The output should include "No active pipeline"
    End
  End

  Context "when pipeline is already active"
    setup() {
      setup_tmpdir_with_git TEST_DIR
      setup_config_fixture "$TEST_DIR"
      setup_state_fixture "$TEST_DIR" "existing-feature"
    }

    It "exits 1 and reports pipeline already running"
      When run script scripts/afc-preflight-check.sh
      The status should eq 1
      The output should include "pipeline already running"
    End
  End

  Context "when CI command is found in afc.config.md"
    It "exits 0 and reports CI command"
      When run script scripts/afc-preflight-check.sh
      The status should eq 0
      The output should include "CI command"
    End

    It "reports config as CI source"
      When run script scripts/afc-preflight-check.sh
      The status should eq 0
      The output should include "afc.config.md"
    End
  End

  Context "PM detection"
    Context "when pnpm-lock.yaml exists"
      setup() {
        setup_tmpdir_with_git TEST_DIR
        setup_config_fixture "$TEST_DIR"
        touch "$TEST_DIR/pnpm-lock.yaml"
      }

      It "detects pnpm as package manager"
        When run script scripts/afc-preflight-check.sh
        The status should eq 0
        The output should include "Preflight Check"
      End
    End

    Context "when yarn.lock exists"
      setup() {
        setup_tmpdir_with_git TEST_DIR
        setup_config_fixture "$TEST_DIR"
        touch "$TEST_DIR/yarn.lock"
      }

      It "detects yarn as package manager"
        When run script scripts/afc-preflight-check.sh
        The status should eq 0
        The output should include "Preflight Check"
      End
    End

    Context "when bun.lock exists"
      setup() {
        setup_tmpdir_with_git TEST_DIR
        setup_config_fixture "$TEST_DIR"
        touch "$TEST_DIR/bun.lock"
      }

      It "detects bun as package manager"
        When run script scripts/afc-preflight-check.sh
        The status should eq 0
        The output should include "Preflight Check"
      End
    End
  End

  Context "CI cascade"
    Context "when turbo.json exists without config"
      setup() {
        setup_tmpdir_with_git TEST_DIR
        # No afc.config.md — force cascade
        echo '{}' > "$TEST_DIR/package.json"
        echo '{}' > "$TEST_DIR/turbo.json"
      }

      It "uses turbo test as CI command"
        When run script scripts/afc-preflight-check.sh
        The status should eq 0
        The output should include "turbo test"
        The output should include "turbo.json"
      End
    End

    Context "when nx.json exists without config"
      setup() {
        setup_tmpdir_with_git TEST_DIR
        echo '{}' > "$TEST_DIR/package.json"
        echo '{}' > "$TEST_DIR/nx.json"
      }

      It "uses nx run-many as CI command"
        When run script scripts/afc-preflight-check.sh
        The status should eq 0
        The output should include "nx run-many"
        The output should include "nx.json"
      End
    End

    Context "when Makefile has test target without config"
      setup() {
        setup_tmpdir_with_git TEST_DIR
        cat > "$TEST_DIR/Makefile" << 'EOF'
test:
	echo "running tests"
EOF
      }

      It "uses make test as CI command"
        When run script scripts/afc-preflight-check.sh
        The status should eq 0
        The output should include "make test"
        The output should include "Makefile"
      End
    End

    Context "when package.json has test:all script without config"
      setup() {
        setup_tmpdir_with_git TEST_DIR
        cat > "$TEST_DIR/package.json" << 'EOF'
{"scripts":{"test:all":"jest --all"}}
EOF
        mkdir -p "$TEST_DIR/node_modules"
      }

      It "prefers test:all over test"
        When run script scripts/afc-preflight-check.sh
        The status should eq 0
        The output should include "test:all"
        The output should include "package.json"
      End
    End

    Context "when package.json has only test script without config"
      setup() {
        setup_tmpdir_with_git TEST_DIR
        cat > "$TEST_DIR/package.json" << 'EOF'
{"scripts":{"test":"jest"}}
EOF
        mkdir -p "$TEST_DIR/node_modules"
      }

      It "uses pm test as CI command"
        When run script scripts/afc-preflight-check.sh
        The status should eq 0
        The output should include "CI command"
        The output should include "package.json"
      End
    End

    Context "when afc.config.md takes priority over turbo.json"
      setup() {
        setup_tmpdir_with_git TEST_DIR
        setup_config_fixture "$TEST_DIR"
        echo '{}' > "$TEST_DIR/turbo.json"
      }

      It "uses config CI command over turbo"
        When run script scripts/afc-preflight-check.sh
        The status should eq 0
        The output should include "afc.config.md"
      End
    End
  End

  Context "dependencies check"
    Context "when node_modules exists"
      setup() {
        setup_tmpdir_with_git TEST_DIR
        setup_config_fixture "$TEST_DIR"
        echo '{}' > "$TEST_DIR/package.json"
        mkdir -p "$TEST_DIR/node_modules"
      }

      It "reports dependencies present"
        When run script scripts/afc-preflight-check.sh
        The status should eq 0
        The output should include "Dependencies: node_modules present"
      End
    End

    Context "when node_modules is missing"
      setup() {
        setup_tmpdir_with_git TEST_DIR
        setup_config_fixture "$TEST_DIR"
        echo '{}' > "$TEST_DIR/package.json"
      }

      It "warns about missing node_modules"
        When run script scripts/afc-preflight-check.sh
        The status should eq 0
        The output should include "node_modules not found"
      End
    End

    Context "when no package.json exists"
      setup() {
        setup_tmpdir_with_git TEST_DIR
        setup_config_fixture "$TEST_DIR"
      }

      It "skips dependency check for non-npm project"
        When run script scripts/afc-preflight-check.sh
        The status should eq 0
        The output should include "non-npm project"
      End
    End
  End

  Context "git state check"
    Context "when working tree is clean"
      setup() {
        setup_tmpdir_with_git TEST_DIR
        setup_config_fixture "$TEST_DIR"
        # Commit the config so working tree is clean
        (cd "$TEST_DIR" && git add -A && git commit -q -m "add config")
      }

      It "reports clean git state"
        When run script scripts/afc-preflight-check.sh
        The status should eq 0
        The output should include "Git state: clean"
      End
    End

    Context "when working tree has uncommitted changes"
      setup() {
        setup_tmpdir_with_git TEST_DIR
        setup_config_fixture "$TEST_DIR"
        echo "dirty" > "$TEST_DIR/dirty-file.txt"
      }

      It "warns about uncommitted changes"
        When run script scripts/afc-preflight-check.sh
        The status should eq 0
        The output should include "uncommitted change"
      End
    End
  End

  Context "result summary"
    It "reports PASS when all checks pass"
      When run script scripts/afc-preflight-check.sh
      The status should eq 0
      The output should include "PASS"
    End

    Context "when pipeline is active (causes failure)"
      setup() {
        setup_tmpdir_with_git TEST_DIR
        setup_config_fixture "$TEST_DIR"
        setup_state_fixture "$TEST_DIR" "blocker-feature"
      }

      It "reports FAIL in result"
        When run script scripts/afc-preflight-check.sh
        The status should eq 1
        The output should include "FAIL"
      End
    End
  End

  Context "no CI command detected"
    Context "when package.json exists but has no scripts"
      setup() {
        setup_tmpdir_with_git TEST_DIR
        echo '{}' > "$TEST_DIR/package.json"
        mkdir -p "$TEST_DIR/node_modules"
      }

      It "fails with no test script found"
        When run script scripts/afc-preflight-check.sh
        The status should eq 1
        The output should include "no test script found"
      End
    End

    Context "when no package.json and no config"
      setup() {
        setup_tmpdir_with_git TEST_DIR
      }

      It "warns about undetected CI command"
        When run script scripts/afc-preflight-check.sh
        The status should eq 0
        The output should include "not detected"
      End
    End
  End
End
