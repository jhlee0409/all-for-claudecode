# Migration Guide: install.sh → Plugin

> 기존 `git clone` + `install.sh` 방식에서 Claude Code 플러그인 방식으로 마이그레이션하는 가이드입니다.

## 변경 요약

| 항목 | 이전 | 이후 |
|------|------|------|
| 설치 | `git clone` + `./install.sh` | `/plugin install <url>` |
| 커맨드 구분자 | `.` (`/selfish.spec`) | `:` (`/selfish:spec`) |
| 커맨드 위치 | `~/.claude/commands/selfish.*.md` | 플러그인 내 `commands/*.md` |
| Hook 스크립트 | `<project>/.claude/hooks/*.sh` | 플러그인 내 `scripts/*.sh` |
| Hook 설정 | `<project>/.claude/settings.json` | 플러그인 내 `hooks/hooks.json` |
| 설정 파일 | `.claude/selfish.config.md` (변경 없음) | `.claude/selfish.config.md` (변경 없음) |

## 마이그레이션 절차

### 1. 기존 파일 정리

```bash
# 기존 커맨드 파일 삭제 (유저 레벨)
rm -f ~/.claude/commands/selfish.*.md

# 기존 hook 스크립트 삭제 (프로젝트 레벨)
rm -f .claude/hooks/session-start-context.sh
rm -f .claude/hooks/pre-compact-checkpoint.sh
rm -f .claude/hooks/track-selfish-changes.sh
rm -f .claude/hooks/selfish-stop-gate.sh
rm -f .claude/hooks/selfish-pipeline-manage.sh
```

### 2. settings.json에서 selfish hook 제거

`.claude/settings.json`에서 selfish 관련 hook 항목을 제거합니다.
플러그인이 자체 `hooks.json`으로 hook을 등록하므로 settings.json에서의 수동 설정이 불필요합니다.

제거 대상 (settings.json 내):
- `SessionStart` → `session-start-context.sh`
- `PreCompact` → `pre-compact-checkpoint.sh`
- `PostToolUse` → `track-selfish-changes.sh`
- `Stop` → `selfish-stop-gate.sh`

> 다른 프로젝트 고유 hook이 settings.json에 있다면 그것은 유지하세요.

### 3. 플러그인 설치

```bash
npx selfish-pipeline
```

인터랙티브 프롬프트에서 설치 범위를 선택합니다. 기존 `install.sh`의 `--commands-only`에 해당하는 것은 **User** 스코프, 팀 공유는 **Project** 스코프입니다.

### 4. 커맨드명 변경

모든 커맨드의 구분자가 `.`에서 `:`로 변경되었습니다:

```text
# 이전
/selfish.auto "기능 설명"
/selfish.spec "기능 설명"
/selfish.plan

# 이후
/selfish:auto "기능 설명"
/selfish:spec "기능 설명"
/selfish:plan
```

### 5. 설정 파일 확인

`.claude/selfish.config.md`는 **변경 없이 그대로 사용 가능**합니다.

신규 프로젝트라면 `/selfish:init`으로 자동 생성할 수 있습니다.

## 변경되지 않는 것

- `.claude/selfish.config.md` 파일 형식 및 경로
- `specs/{feature}/` 아티팩트 경로
- `memory/` 참조 (checkpoint, principles, research, decisions)
- `.selfish-*` 상태 파일 경로
- `git tag selfish/pre-*` 안전 태그
- hook 스크립트 내부 로직

## FAQ

**Q: 기존 프로젝트의 `.claude/selfish.config.md`를 다시 만들어야 하나요?**
A: 아니요. 설정 파일 형식은 동일합니다. 그대로 사용하세요.

**Q: 여러 프로젝트에서 사용 중인데, 각 프로젝트마다 마이그레이션해야 하나요?**
A: 플러그인은 한 번만 설치하면 됩니다. 각 프로젝트에서는 기존 `.claude/hooks/*.sh`와 settings.json의 selfish hook 항목만 정리하면 됩니다.

**Q: 이전 버전과 플러그인을 동시에 사용할 수 있나요?**
A: 권장하지 않습니다. 커맨드명이 다르므로 (`/selfish.spec` vs `/selfish:spec`) 충돌은 없지만, hook이 중복 등록될 수 있습니다.
