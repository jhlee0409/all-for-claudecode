Describe "afc-spec-guard.sh"
  setup_script() {
    GUARD_SCRIPT="$SHELLSPEC_PROJECT_ROOT/scripts/afc-spec-guard.sh"
  }
  BeforeEach 'setup_script'

  Describe "when pipeline is inactive"
    setup_inactive() {
      setup_tmpdir TMPDIR
    }
    BeforeEach 'setup_inactive'

    It "exits 0 and allows"
      Data '{"tool_input":{"file_path":".claude/afc/specs/feat/spec.md"}}'
      When run bash "$GUARD_SCRIPT"
      The status should eq 0
      The stdout should include "allow"
    End
  End

  Describe "when pipeline is active in implement phase"
    setup_implement() {
      setup_tmpdir TMPDIR
      mkdir -p "$TMPDIR/.claude"
      printf '{"feature":"test","phase":"implement","startedAt":1234567890}\n' > "$TMPDIR/.claude/.afc-state.json"
    }
    BeforeEach 'setup_implement'

    It "denies spec.md write"
      Data '{"tool_input":{"file_path":"/path/.claude/afc/specs/my-feature/spec.md"}}'
      When run bash "$GUARD_SCRIPT"
      The status should eq 0
      The stdout should include "deny"
      The stdout should include "immutable during implement"
    End

    It "allows non-spec file write"
      Data '{"tool_input":{"file_path":"src/main.ts"}}'
      When run bash "$GUARD_SCRIPT"
      The status should eq 0
      The stdout should include "allow"
    End

    It "allows plan.md write"
      Data '{"tool_input":{"file_path":".claude/afc/specs/feat/plan.md"}}'
      When run bash "$GUARD_SCRIPT"
      The status should eq 0
      The stdout should include "allow"
    End

    It "exits 0 and allows on empty stdin"
      Data ''
      When run bash "$GUARD_SCRIPT"
      The status should eq 0
      The stdout should include "allow"
    End
  End

  Describe "when pipeline is active in review phase"
    setup_review() {
      setup_tmpdir TMPDIR
      mkdir -p "$TMPDIR/.claude"
      printf '{"feature":"test","phase":"review","startedAt":1234567890}\n' > "$TMPDIR/.claude/.afc-state.json"
    }
    BeforeEach 'setup_review'

    It "denies spec.md write"
      Data '{"tool_input":{"file_path":"/abs/path/.claude/afc/specs/feature-x/spec.md"}}'
      When run bash "$GUARD_SCRIPT"
      The status should eq 0
      The stdout should include "deny"
      The stdout should include "immutable during review"
    End
  End

  Describe "when pipeline is active in spec phase"
    setup_spec() {
      setup_tmpdir TMPDIR
      mkdir -p "$TMPDIR/.claude"
      printf '{"feature":"test","phase":"spec","startedAt":1234567890}\n' > "$TMPDIR/.claude/.afc-state.json"
    }
    BeforeEach 'setup_spec'

    It "allows spec.md write during spec phase"
      Data '{"tool_input":{"file_path":".claude/afc/specs/feat/spec.md"}}'
      When run bash "$GUARD_SCRIPT"
      The status should eq 0
      The stdout should include "allow"
    End
  End

  Describe "when pipeline is active in clean phase"
    setup_clean() {
      setup_tmpdir TMPDIR
      mkdir -p "$TMPDIR/.claude"
      printf '{"feature":"test","phase":"clean","startedAt":1234567890}\n' > "$TMPDIR/.claude/.afc-state.json"
    }
    BeforeEach 'setup_clean'

    It "denies spec.md write during clean phase"
      Data '{"tool_input":{"file_path":"/path/.claude/afc/specs/feat/spec.md"}}'
      When run bash "$GUARD_SCRIPT"
      The status should eq 0
      The stdout should include "deny"
      The stdout should include "immutable during clean"
    End
  End

  Describe "when stdin has no file_path field"
    setup_no_fp() {
      setup_tmpdir TMPDIR
      mkdir -p "$TMPDIR/.claude"
      printf '{"feature":"test","phase":"implement","startedAt":1234567890}\n' > "$TMPDIR/.claude/.afc-state.json"
    }
    BeforeEach 'setup_no_fp'

    It "allows when tool_input has no file_path"
      Data '{"tool_input":{"content":"hello"}}'
      When run bash "$GUARD_SCRIPT"
      The status should eq 0
      The stdout should include "allow"
    End
  End

  Describe "when pipeline is active in plan phase"
    setup_plan() {
      setup_tmpdir TMPDIR
      mkdir -p "$TMPDIR/.claude"
      printf '{"feature":"test","phase":"plan","startedAt":1234567890}\n' > "$TMPDIR/.claude/.afc-state.json"
    }
    BeforeEach 'setup_plan'

    It "allows spec.md write during plan phase"
      Data '{"tool_input":{"file_path":".claude/afc/specs/feat/spec.md"}}'
      When run bash "$GUARD_SCRIPT"
      The status should eq 0
      The stdout should include "allow"
    End
  End
End
