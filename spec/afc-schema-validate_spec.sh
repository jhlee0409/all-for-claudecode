Describe "afc-schema-validate.sh"
  setup_schema_fixture() {
    local dir="$1"
    mkdir -p "$dir/schemas" "$dir/hooks" "$dir/.claude-plugin"
    export CLAUDE_PLUGIN_ROOT="$dir"
    # Minimal valid hooks.json
    cat > "$dir/hooks/hooks.json" << 'HOOKS'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "echo hello" }
        ]
      }
    ]
  }
}
HOOKS
    # Minimal valid plugin.json
    cat > "$dir/.claude-plugin/plugin.json" << 'PLUGIN'
{
  "name": "test-plugin",
  "version": "1.0.0",
  "description": "A test plugin"
}
PLUGIN
    # Minimal valid marketplace.json
    cat > "$dir/.claude-plugin/marketplace.json" << 'MARKET'
{
  "name": "test-plugin",
  "owner": { "name": "tester", "email": "test@test.com" },
  "metadata": { "description": "Test", "version": "1.0.0" },
  "plugins": [
    { "name": "test", "source": "./", "version": "1.0.0" }
  ]
}
MARKET
    # Copy schemas from project
    cp "$SHELLSPEC_PROJECT_ROOT/schemas/"*.schema.json "$dir/schemas/"
  }

  Describe "--all mode"
    It "validates all 3 files when valid"
      setup_tmpdir TEST_DIR
      setup_schema_fixture "$TEST_DIR"
      When run script scripts/afc-schema-validate.sh --all
      The status should eq 0
      The output should include "All 3 files valid"
    End

    It "fails when hooks.json has invalid structure"
      setup_tmpdir TEST_DIR
      setup_schema_fixture "$TEST_DIR"
      printf '%s\n' '{"hooks": {}, "extra": true}' > "$TEST_DIR/hooks/hooks.json"
      When run script scripts/afc-schema-validate.sh --all
      The status should eq 1
      The output should include "valid"
      The stderr should include "unexpected property"
    End

    It "fails when plugin.json missing required field"
      setup_tmpdir TEST_DIR
      setup_schema_fixture "$TEST_DIR"
      printf '%s\n' '{"name": "x"}' > "$TEST_DIR/.claude-plugin/plugin.json"
      When run script scripts/afc-schema-validate.sh --all
      The status should eq 1
      The output should include "valid"
      The stderr should include "required field missing"
    End

    It "fails when marketplace.json missing plugins array"
      setup_tmpdir TEST_DIR
      setup_schema_fixture "$TEST_DIR"
      printf '%s\n' '{"name":"x","owner":{"name":"a","email":"a@b.c"},"metadata":{"description":"d","version":"1.0.0"}}' > "$TEST_DIR/.claude-plugin/marketplace.json"
      When run script scripts/afc-schema-validate.sh --all
      The status should eq 1
      The output should include "valid"
      The stderr should include "required field missing"
    End
  End

  Describe "--json-file mode"
    It "validates a single file against a schema"
      setup_tmpdir TEST_DIR
      setup_schema_fixture "$TEST_DIR"
      When run script scripts/afc-schema-validate.sh --json-file "$TEST_DIR/.claude-plugin/plugin.json" --schema "$TEST_DIR/schemas/plugin.schema.json"
      The status should eq 0
      The output should include "valid"
    End

    It "fails for malformed JSON"
      setup_tmpdir TEST_DIR
      setup_schema_fixture "$TEST_DIR"
      printf '%s\n' '{bad json' > "$TEST_DIR/test.json"
      When run script scripts/afc-schema-validate.sh --json-file "$TEST_DIR/test.json" --schema "$TEST_DIR/schemas/plugin.schema.json"
      The status should eq 1
      The stderr should include "parse error"
    End

    It "fails for nonexistent file"
      setup_tmpdir TEST_DIR
      setup_schema_fixture "$TEST_DIR"
      When run script scripts/afc-schema-validate.sh --json-file "$TEST_DIR/nope.json" --schema "$TEST_DIR/schemas/plugin.schema.json"
      The status should eq 1
      The stderr should include "File not found"
    End
  End

  Describe "hooks.json specific validation"
    It "rejects invalid hook type enum"
      setup_tmpdir TEST_DIR
      setup_schema_fixture "$TEST_DIR"
      cat > "$TEST_DIR/hooks/hooks.json" << 'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "invalid_type", "command": "echo" }
        ]
      }
    ]
  }
}
EOF
      When run script scripts/afc-schema-validate.sh --json-file "$TEST_DIR/hooks/hooks.json" --schema "$TEST_DIR/schemas/hooks.schema.json"
      The status should eq 1
      The stderr should include "not in enum"
    End

    It "rejects unknown hook event name"
      setup_tmpdir TEST_DIR
      setup_schema_fixture "$TEST_DIR"
      cat > "$TEST_DIR/hooks/hooks.json" << 'EOF'
{
  "hooks": {
    "FakeEvent": [
      {
        "hooks": [
          { "type": "command", "command": "echo" }
        ]
      }
    ]
  }
}
EOF
      When run script scripts/afc-schema-validate.sh --json-file "$TEST_DIR/hooks/hooks.json" --schema "$TEST_DIR/schemas/hooks.schema.json"
      The status should eq 1
      The stderr should include "unexpected property"
    End
  End

  Describe "plugin.json specific validation"
    It "rejects agents field (SC3 edge case)"
      setup_tmpdir TEST_DIR
      setup_schema_fixture "$TEST_DIR"
      cat > "$TEST_DIR/.claude-plugin/plugin.json" << 'EOF'
{
  "name": "test",
  "version": "1.0.0",
  "description": "Test",
  "agents": []
}
EOF
      When run script scripts/afc-schema-validate.sh --json-file "$TEST_DIR/.claude-plugin/plugin.json" --schema "$TEST_DIR/schemas/plugin.schema.json"
      The status should eq 1
      The stderr should include "unexpected property"
    End
  End

  Describe "usage error"
    It "shows usage on unknown argument"
      When run script scripts/afc-schema-validate.sh --bad-arg
      The status should eq 1
      The stderr should include "Usage:"
    End
  End
End
