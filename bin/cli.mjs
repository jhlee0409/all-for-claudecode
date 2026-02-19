#!/usr/bin/env node

import { createInterface } from "node:readline/promises";
import { execSync } from "node:child_process";
import { stdin, stdout, exit } from "node:process";

const PLUGIN_URL = "https://github.com/jhlee0409/selfish-pipeline";

const SCOPES = [
  {
    key: "1",
    name: "user",
    label: "User (개인 전체 프로젝트)",
    desc: "~/.claude/settings.json",
  },
  {
    key: "2",
    name: "project",
    label: "Project (팀 공유, git 커밋 가능)",
    desc: ".claude/settings.json",
  },
  {
    key: "3",
    name: "local",
    label: "Local (이 프로젝트만, gitignore)",
    desc: ".claude/settings.local.json",
  },
];

async function main() {
  console.log();
  console.log("  Selfish Pipeline — Claude Code Plugin Installer");
  console.log("  ================================================");
  console.log();

  const rl = createInterface({ input: stdin, output: stdout });

  try {
    console.log("  설치 범위를 선택하세요:\n");
    for (const s of SCOPES) {
      console.log(`    ${s.key}) ${s.label}`);
      console.log(`       → ${s.desc}`);
    }
    console.log();

    const answer = await rl.question("  선택 [1/2/3] (기본: 1): ");
    const choice = answer.trim() || "1";
    const scope = SCOPES.find((s) => s.key === choice);

    if (!scope) {
      console.error("\n  ✗ 잘못된 선택입니다.");
      exit(1);
    }

    console.log(`\n  → ${scope.label} 스코프로 설치합니다...\n`);

    const cmd = `claude plugin install ${PLUGIN_URL} --scope ${scope.name}`;
    console.log(`  $ ${cmd}\n`);

    execSync(cmd, { stdio: "inherit" });

    console.log();
    console.log("  ✓ 설치 완료!");
    console.log();
    console.log("  다음 단계:");
    console.log("    /selfish:init              프로젝트 설정 생성");
    console.log('    /selfish:auto "기능 설명"   파이프라인 실행');
    console.log();
  } finally {
    rl.close();
  }
}

main().catch((err) => {
  console.error(`\n  ✗ 설치 실패: ${err.message}`);
  exit(1);
});
