#!/bin/bash
# shellcheck shell=bash


Describe "afc-qa-audit.sh"
  SCRIPT="$SHELLSPEC_PROJECT_ROOT/scripts/afc-qa-audit.sh"

  # Build a minimal project fixture that passes all QA checks
  setup_qa_fixture() {
    local dir="$1"
    mkdir -p "$dir/scripts" "$dir/spec" "$dir/hooks"

    # hooks.json referencing two scripts
    cat > "$dir/hooks/hooks.json" << 'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/afc-good-hook.sh\"" }
        ]
      }
    ],
    "PostToolUseFailure": [
      {
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/afc-failure-hint.sh\"" }
        ]
      }
    ]
  }
}
JSON

    # Good hook: consumes stdin, uses permissionDecision (PreToolUse format)
    printf '%s\n' '#!/bin/bash' 'set -euo pipefail' 'cleanup() { :; }' 'trap cleanup EXIT' 'INPUT=$(cat)' \
      "printf '{\"hookSpecificOutput\":{\"permissionDecision\":\"allow\"}}\\n'" 'exit 0' \
      > "$dir/scripts/afc-good-hook.sh"
    chmod +x "$dir/scripts/afc-good-hook.sh"

    # Copy real failure-hint for A3 testing (has case patterns + additionalContext format)
    cp "$SHELLSPEC_PROJECT_ROOT/scripts/afc-failure-hint.sh" "$dir/scripts/afc-failure-hint.sh"
    cp "$SHELLSPEC_PROJECT_ROOT/scripts/afc-state.sh" "$dir/scripts/afc-state.sh"
    chmod +x "$dir/scripts/afc-failure-hint.sh"

    # Spec for failure-hint with enough contexts and empty stdin
    cp "$SHELLSPEC_PROJECT_ROOT/spec/afc-failure-hint_spec.sh" "$dir/spec/afc-failure-hint_spec.sh"

    # Spec for good-hook: 2 assertions per It (density >= 1.5), includes empty stdin
    printf '%s\n' \
      'Describe "good-hook"' \
      '  It "works"' \
      '    The status should eq 0' \
      '    The output should include "hook"' \
      '  End' \
      '  Context "empty stdin"' \
      '    It "handles empty"' \
      '      Data '"''"'' \
      '      The status should eq 0' \
      '      The output should eq ""' \
      '    End' \
      '  End' \
      'End' \
      > "$dir/spec/afc-good-hook_spec.sh"

    # package.json (non-dev name to skip cache check)
    printf '{"name": "test-project", "version": "1.0.0"}\n' > "$dir/package.json"
  }

  Describe "when all checks pass"
    setup_tmpdir DIR
    BeforeAll "setup_qa_fixture $DIR"
    AfterAll "cleanup_tmpdir $DIR"

    It "exits 0 with no errors"
      When run bash "$SCRIPT" "$DIR"
      The status should eq 0
      The output should include "[afc:qa] Done:"
      The output should include "0 errors"
    End
  End

  Describe "A1: stdin not consumed"
    setup_tmpdir DIR2
    BeforeAll "setup_qa_fixture $DIR2"
    AfterAll "cleanup_tmpdir $DIR2"

    It "fails when hook script does not consume stdin"
      printf '%s\n' '#!/bin/bash' 'set -euo pipefail' 'cleanup() { :; }' 'trap cleanup EXIT' \
        "printf '{\"hookSpecificOutput\":{\"permissionDecision\":\"allow\"}}\\n'" 'exit 0' \
        > "$DIR2/scripts/afc-good-hook.sh"
      chmod +x "$DIR2/scripts/afc-good-hook.sh"
      When run bash "$SCRIPT" "$DIR2"
      The status should eq 1
      The output should include "[afc:qa] Done:"
      The stderr should include "stdin not consumed"
    End
  End

  Describe "A2: invalid JSON template"
    setup_tmpdir DIR3
    BeforeAll "setup_qa_fixture $DIR3"
    AfterAll "cleanup_tmpdir $DIR3"

    It "fails on broken JSON template"
      printf '%s\n' '#!/bin/bash' 'set -euo pipefail' 'cleanup() { :; }' 'trap cleanup EXIT' 'INPUT=$(cat)' \
        "printf '{\"hookSpecificOutput\":{\"additionalContext\":%s}}\\n' \"\$INPUT\"" \
        > "$DIR3/scripts/afc-broken-json.sh"
      chmod +x "$DIR3/scripts/afc-broken-json.sh"
      When run bash "$SCRIPT" "$DIR3"
      The status should eq 1
      The output should include "[afc:qa] Done:"
      The stderr should include "invalid JSON template"
    End
  End

  Describe "D3: zombie state detection"
    setup_tmpdir DIR4
    BeforeAll "setup_qa_fixture $DIR4"
    AfterAll "cleanup_tmpdir $DIR4"

    It "fails on zombie state with empty feature"
      mkdir -p "$DIR4/.claude"
      printf '{"feature": "", "phase": "implement"}\n' > "$DIR4/.claude/.afc-state.json"
      When run bash "$SCRIPT" "$DIR4"
      The status should eq 1
      The output should include "[afc:qa] Done:"
      The stderr should include "zombie state"
    End
  End

  Describe "D3: active state is OK"
    setup_tmpdir DIR5
    BeforeAll "setup_qa_fixture $DIR5"
    AfterAll "cleanup_tmpdir $DIR5"

    It "passes when state has valid feature"
      mkdir -p "$DIR5/.claude"
      printf '{"feature": "my-feature", "phase": "implement"}\n' > "$DIR5/.claude/.afc-state.json"
      When run bash "$SCRIPT" "$DIR5"
      The status should eq 0
      The output should include "active state"
      The output should include "0 errors"
    End
  End

  Describe "B1: assertion density"
    setup_tmpdir DIR6
    BeforeAll "setup_qa_fixture $DIR6"
    AfterAll "cleanup_tmpdir $DIR6"

    It "detects low assertion density"
      printf '%s\n' \
        'Describe "weak"' \
        '  It "test 1"' \
        '    The status should eq 0' \
        '  End' \
        '  It "test 2"' \
        '  End' \
        '  It "test 3"' \
        '  End' \
        'End' \
        > "$DIR6/spec/afc-weak_spec.sh"
      When run bash "$SCRIPT" "$DIR6"
      The status should eq 1
      The output should include "[afc:qa] Done:"
      The stderr should include "low assertion density"
      The stderr should include "afc-weak_spec.sh"
    End
  End
End
