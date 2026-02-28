#!/bin/bash
# shellcheck shell=bash


Describe "afc-triage.sh"
  setup() {
    setup_tmpdir TEST_DIR
  }
  cleanup() { cleanup_tmpdir "$TEST_DIR"; }
  Before "setup"
  After "cleanup"

  Context "when gh CLI is not available"
    mock_no_gh() {
      # Override PATH to exclude gh
      PATH="/usr/bin:/bin"
      export PATH
    }

    It "exits 1 with error message"
      BeforeRun "mock_no_gh"
      When run script scripts/afc-triage.sh
      The status should eq 1
      The stderr should include "gh CLI not found"
    End
  End

  Context "argument parsing"
    # We can't test actual gh calls without a repo, but we can verify
    # the script structure by testing with mock gh

    Context "when --pr flag is provided"
      mock_gh_pr_only() {
        # Create a mock gh that only responds to pr list
        mkdir -p "$TEST_DIR/bin"
        cat > "$TEST_DIR/bin/gh" << 'MOCK'
#!/bin/bash
if [ "$1" = "auth" ] && [ "$2" = "status" ]; then
  exit 0
fi
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
  printf '[{"number":1,"title":"Test PR","headRefName":"feature","author":{"login":"user"},"labels":[],"additions":10,"deletions":5,"changedFiles":2,"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z","reviewDecision":"","isDraft":false}]'
  exit 0
fi
if [ "$1" = "issue" ] && [ "$2" = "list" ]; then
  printf '[]'
  exit 0
fi
exit 1
MOCK
        chmod +x "$TEST_DIR/bin/gh"
        PATH="$TEST_DIR/bin:$PATH"
        export PATH
      }

      It "collects PRs only"
        BeforeRun "mock_gh_pr_only"
        When run script scripts/afc-triage.sh --pr
        The status should eq 0
        The output should include '"prs"'
        The output should include '"Test PR"'
      End
    End

    Context "when --issue flag is provided"
      mock_gh_issue_only() {
        mkdir -p "$TEST_DIR/bin"
        cat > "$TEST_DIR/bin/gh" << 'MOCK'
#!/bin/bash
if [ "$1" = "auth" ] && [ "$2" = "status" ]; then
  exit 0
fi
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
  printf '[]'
  exit 0
fi
if [ "$1" = "issue" ] && [ "$2" = "list" ]; then
  printf '[{"number":10,"title":"Bug report","labels":[{"name":"bug"}],"author":{"login":"reporter"},"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-03T00:00:00Z","comments":[]}]'
  exit 0
fi
exit 1
MOCK
        chmod +x "$TEST_DIR/bin/gh"
        PATH="$TEST_DIR/bin:$PATH"
        export PATH
      }

      It "collects issues only"
        BeforeRun "mock_gh_issue_only"
        When run script scripts/afc-triage.sh --issue
        The status should eq 0
        The output should include '"issues"'
        The output should include '"Bug report"'
      End
    End

    Context "when --all flag is provided (default)"
      mock_gh_all() {
        mkdir -p "$TEST_DIR/bin"
        cat > "$TEST_DIR/bin/gh" << 'MOCK'
#!/bin/bash
if [ "$1" = "auth" ] && [ "$2" = "status" ]; then
  exit 0
fi
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
  printf '[{"number":1,"title":"PR One","headRefName":"feat","author":{"login":"dev"},"labels":[],"additions":5,"deletions":2,"changedFiles":1,"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z","reviewDecision":"","isDraft":false}]'
  exit 0
fi
if [ "$1" = "issue" ] && [ "$2" = "list" ]; then
  printf '[{"number":10,"title":"Issue One","labels":[],"author":{"login":"user"},"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z","comments":[]}]'
  exit 0
fi
exit 1
MOCK
        chmod +x "$TEST_DIR/bin/gh"
        PATH="$TEST_DIR/bin:$PATH"
        export PATH
      }

      It "collects both PRs and issues"
        BeforeRun "mock_gh_all"
        When run script scripts/afc-triage.sh --all
        The status should eq 0
        The output should include '"PR One"'
        The output should include '"Issue One"'
      End
    End

    Context "when specific numbers are provided"
      mock_gh_specific() {
        mkdir -p "$TEST_DIR/bin"
        cat > "$TEST_DIR/bin/gh" << 'MOCK'
#!/bin/bash
if [ "$1" = "auth" ] && [ "$2" = "status" ]; then
  exit 0
fi
if [ "$1" = "pr" ] && [ "$2" = "view" ] && [ "$3" = "42" ]; then
  printf '{"number":42,"title":"Specific PR","headRefName":"fix-42","author":{"login":"dev"},"labels":[],"additions":20,"deletions":10,"changedFiles":3,"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z","reviewDecision":"APPROVED","isDraft":false}'
  exit 0
fi
if [ "$1" = "pr" ] && [ "$2" = "view" ]; then
  exit 1
fi
if [ "$1" = "issue" ] && [ "$2" = "view" ] && [ "$3" = "99" ]; then
  printf '{"number":99,"title":"Specific Issue","labels":[{"name":"enhancement"}],"author":{"login":"user"},"createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-05T00:00:00Z","comments":[]}'
  exit 0
fi
exit 1
MOCK
        chmod +x "$TEST_DIR/bin/gh"
        PATH="$TEST_DIR/bin:$PATH"
        export PATH
      }

      It "fetches specific items by number"
        BeforeRun "mock_gh_specific"
        When run script scripts/afc-triage.sh 42 99
        The status should eq 0
        The output should include '"Specific PR"'
        The output should include '"Specific Issue"'
      End
    End
  End

  Context "when --deep flag is provided"
    mock_gh_deep() {
      mkdir -p "$TEST_DIR/bin"
      cat > "$TEST_DIR/bin/gh" << 'MOCK'
#!/bin/bash
if [ "$1" = "auth" ] && [ "$2" = "status" ]; then
  exit 0
fi
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
  printf '[]'
  exit 0
fi
if [ "$1" = "issue" ] && [ "$2" = "list" ]; then
  printf '[]'
  exit 0
fi
exit 1
MOCK
      chmod +x "$TEST_DIR/bin/gh"
      PATH="$TEST_DIR/bin:$PATH"
      export PATH
    }

    It "sets deep flag in output"
      BeforeRun "mock_gh_deep"
      When run script scripts/afc-triage.sh --deep
      The status should eq 0
      The output should include '"deep": true'
    End
  End

  Context "when gh auth is not authenticated"
    mock_gh_no_auth() {
      mkdir -p "$TEST_DIR/bin"
      cat > "$TEST_DIR/bin/gh" << 'MOCK'
#!/bin/bash
if [ "$1" = "auth" ] && [ "$2" = "status" ]; then
  exit 1
fi
exit 0
MOCK
      chmod +x "$TEST_DIR/bin/gh"
      PATH="$TEST_DIR/bin:$PATH"
      export PATH
    }

    It "exits 1 with auth error"
      BeforeRun "mock_gh_no_auth"
      When run script scripts/afc-triage.sh
      The status should eq 1
      The stderr should include "not authenticated"
    End
  End

  Context "when unknown item number is provided"
    mock_gh_not_found() {
      mkdir -p "$TEST_DIR/bin"
      cat > "$TEST_DIR/bin/gh" << 'MOCK'
#!/bin/bash
if [ "$1" = "auth" ] && [ "$2" = "status" ]; then
  exit 0
fi
exit 1
MOCK
      chmod +x "$TEST_DIR/bin/gh"
      PATH="$TEST_DIR/bin:$PATH"
      export PATH
    }

    It "warns on stderr but exits 0"
      BeforeRun "mock_gh_not_found"
      When run script scripts/afc-triage.sh 999
      The status should eq 0
      The output should be present
      The stderr should include "not found"
    End
  End
End
