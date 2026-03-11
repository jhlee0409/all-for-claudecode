Describe "afc-tdd-guard.sh"
  setup_script() {
    TDD_GUARD="$SHELLSPEC_PROJECT_ROOT/scripts/afc-tdd-guard.sh"
  }
  BeforeEach 'setup_script'

  Describe "when pipeline is inactive"
    setup_inactive() {
      setup_tmpdir TMPDIR
    }
    BeforeEach 'setup_inactive'

    It "allows any file write"
      Data '{"tool_input":{"file_path":"src/main.ts"}}'
      When run bash "$TDD_GUARD"
      The status should eq 0
      The stdout should include "allow"
    End
  End

  Describe "when pipeline is active but phase is not implement"
    setup_spec_phase() {
      setup_tmpdir TMPDIR
      mkdir -p "$TMPDIR/.claude"
      printf '{"feature":"test","phase":"spec","startedAt":1234567890}\n' > "$TMPDIR/.claude/.afc-state.json"
    }
    BeforeEach 'setup_spec_phase'

    It "allows any file write in spec phase"
      Data '{"tool_input":{"file_path":"src/main.ts"}}'
      When run bash "$TDD_GUARD"
      The status should eq 0
      The stdout should include "allow"
    End
  End

  Describe "when implement phase active with tdd: off"
    setup_tdd_off() {
      setup_tmpdir TMPDIR
      mkdir -p "$TMPDIR/.claude"
      printf '{"feature":"test","phase":"implement","startedAt":1234567890}\n' > "$TMPDIR/.claude/.afc-state.json"
      # Create config with tdd: off
      cat > "$TMPDIR/.claude/afc.config.md" << 'CONF'
## CI Commands
```yaml
ci: "npm run lint"
gate: "npm run lint"
test: "npm test"
tdd: "off"
```
CONF
    }
    BeforeEach 'setup_tdd_off'

    It "allows impl file write when tdd is off"
      Data '{"tool_input":{"file_path":"src/main.ts"}}'
      When run bash "$TDD_GUARD"
      The status should eq 0
      The stdout should include "allow"
    End
  End

  Describe "when implement phase active with no tdd setting"
    setup_tdd_missing() {
      setup_tmpdir TMPDIR
      mkdir -p "$TMPDIR/.claude"
      printf '{"feature":"test","phase":"implement","startedAt":1234567890}\n' > "$TMPDIR/.claude/.afc-state.json"
      # Config without tdd key
      cat > "$TMPDIR/.claude/afc.config.md" << 'CONF'
## CI Commands
```yaml
ci: "npm run lint"
gate: "npm run lint"
test: "npm test"
```
CONF
    }
    BeforeEach 'setup_tdd_missing'

    It "allows impl file write when tdd key is absent"
      Data '{"tool_input":{"file_path":"src/service.ts"}}'
      When run bash "$TDD_GUARD"
      The status should eq 0
      The stdout should include "allow"
    End
  End

  Describe "when implement phase active with tdd: strict"
    setup_tdd_strict() {
      setup_tmpdir TMPDIR
      mkdir -p "$TMPDIR/.claude"
      printf '{"feature":"test","phase":"implement","startedAt":1234567890}\n' > "$TMPDIR/.claude/.afc-state.json"
      cat > "$TMPDIR/.claude/afc.config.md" << 'CONF'
## CI Commands
```yaml
ci: "npm run lint"
gate: "npm run lint"
test: "npm test"
tdd: "strict"
```
CONF
    }
    BeforeEach 'setup_tdd_strict'

    It "denies non-test file write in strict mode"
      Data '{"tool_input":{"file_path":"src/service.ts"}}'
      When run bash "$TDD_GUARD"
      The status should eq 0
      The stdout should include "deny"
      The stdout should include "tdd-guard"
      The stdout should include "write test file first"
    End

    It "allows test file with .test. pattern"
      Data '{"tool_input":{"file_path":"src/service.test.ts"}}'
      When run bash "$TDD_GUARD"
      The status should eq 0
      The stdout should include "allow"
    End

    It "allows test file with .spec. pattern"
      Data '{"tool_input":{"file_path":"src/service.spec.ts"}}'
      When run bash "$TDD_GUARD"
      The status should eq 0
      The stdout should include "allow"
    End

    It "allows test file with _spec. pattern"
      Data '{"tool_input":{"file_path":"spec/afc-guard_spec.sh"}}'
      When run bash "$TDD_GUARD"
      The status should eq 0
      The stdout should include "allow"
    End

    It "allows test file in spec/ directory"
      Data '{"tool_input":{"file_path":"spec/some-test.sh"}}'
      When run bash "$TDD_GUARD"
      The status should eq 0
      The stdout should include "allow"
    End

    It "allows test file in __tests__/ directory"
      Data '{"tool_input":{"file_path":"src/__tests__/service.ts"}}'
      When run bash "$TDD_GUARD"
      The status should eq 0
      The stdout should include "allow"
    End

    It "allows markdown file"
      Data '{"tool_input":{"file_path":"skills/spec/SKILL.md"}}'
      When run bash "$TDD_GUARD"
      The status should eq 0
      The stdout should include "allow"
    End

    It "allows json file"
      Data '{"tool_input":{"file_path":"hooks/hooks.json"}}'
      When run bash "$TDD_GUARD"
      The status should eq 0
      The stdout should include "allow"
    End

    It "allows yaml file"
      Data '{"tool_input":{"file_path":"config/settings.yaml"}}'
      When run bash "$TDD_GUARD"
      The status should eq 0
      The stdout should include "allow"
    End

    It "allows on empty stdin"
      Data ''
      When run bash "$TDD_GUARD"
      The status should eq 0
      The stdout should include "allow"
    End
  End

  Describe "when implement phase active with tdd: guide"
    setup_tdd_guide() {
      setup_tmpdir TMPDIR
      mkdir -p "$TMPDIR/.claude"
      printf '{"feature":"test","phase":"implement","startedAt":1234567890}\n' > "$TMPDIR/.claude/.afc-state.json"
      cat > "$TMPDIR/.claude/afc.config.md" << 'CONF'
## CI Commands
```yaml
ci: "npm run lint"
gate: "npm run lint"
test: "npm test"
tdd: "guide"
```
CONF
    }
    BeforeEach 'setup_tdd_guide'

    It "allows but warns for non-test file"
      Data '{"tool_input":{"file_path":"src/service.ts"}}'
      When run bash "$TDD_GUARD"
      The status should eq 0
      The stdout should include "allow"
      The stdout should include "tdd-guard"
      The stdout should include "consider writing tests first"
    End

    It "allows test file without warning"
      Data '{"tool_input":{"file_path":"src/service.test.ts"}}'
      When run bash "$TDD_GUARD"
      The status should eq 0
      The stdout should include "allow"
      The stdout should not include "tdd-guard"
    End
  End
End
