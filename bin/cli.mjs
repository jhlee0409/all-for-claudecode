#!/usr/bin/env node

import { createInterface } from "node:readline/promises";
import { execSync } from "node:child_process";
import { stdin, stdout, exit } from "node:process";

const GITHUB_REPO = "jhlee0409/all-for-claudecode";
const MARKETPLACE_NAME = "all-for-claudecode";
const PLUGIN_NAME = "afc";

const SCOPES = [
  {
    key: "1",
    name: "user",
    label: "User (all projects for this user)",
    desc: "~/.claude/settings.json",
  },
  {
    key: "2",
    name: "project",
    label: "Project (shared with team, committable)",
    desc: ".claude/settings.json",
  },
  {
    key: "3",
    name: "local",
    label: "Local (this project only, gitignored)",
    desc: ".claude/settings.local.json",
  },
];

function run(cmd) {
  try {
    execSync(cmd, { stdio: "inherit" });
    return true;
  } catch {
    return false;
  }
}

async function main() {
  console.log();
  console.log("  all-for-claudecode — Claude Code Plugin Installer");
  console.log("  ===================================================");
  console.log();

  // Check claude CLI exists
  try {
    execSync("claude --version", { stdio: "pipe" });
  } catch {
    console.error("  ✗ Claude Code CLI is not installed.");
    console.error("    Install it from https://claude.ai/code");
    exit(1);
  }

  const rl = createInterface({ input: stdin, output: stdout });

  try {
    console.log("  Select install scope:\n");
    for (const s of SCOPES) {
      console.log(`    ${s.key}) ${s.label}`);
      console.log(`       → ${s.desc}`);
    }
    console.log();

    const answer = await rl.question("  Choose [1/2/3] (default: 1): ");
    const choice = answer.trim() || "1";
    const scope = SCOPES.find((s) => s.key === choice);

    if (!scope) {
      console.error("\n  ✗ Invalid selection.");
      exit(1);
    }

    console.log(`\n  → Installing with ${scope.label} scope...\n`);

    // Step 1: Register marketplace
    console.log("  [1/2] Registering marketplace...");
    run(`claude plugin marketplace add ${GITHUB_REPO}`);

    // Step 2: Install plugin
    console.log(`  [2/2] Installing plugin (--scope ${scope.name})...`);
    const installed = run(
      `claude plugin install ${PLUGIN_NAME}@${MARKETPLACE_NAME} --scope ${scope.name}`
    );

    if (!installed) {
      console.error("\n  ✗ Installation failed. Try manually:");
      console.error(`    claude plugin marketplace add ${GITHUB_REPO}`);
      console.error(
        `    claude plugin install ${PLUGIN_NAME}@${MARKETPLACE_NAME} --scope ${scope.name}`
      );
      exit(1);
    }

    console.log();
    console.log("  ✓ Installation complete!");
    console.log();
    console.log("  Next steps:");
    console.log("    /afc:init                    Create project config");
    console.log('    /afc:auto "feature desc"      Run the pipeline');
    console.log();
  } finally {
    rl.close();
  }
}

main().catch((err) => {
  console.error(`\n  ✗ Installation failed: ${err.message}`);
  exit(1);
});
