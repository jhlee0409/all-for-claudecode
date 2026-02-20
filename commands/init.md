---
name: selfish:init
description: "프로젝트 초기 설정"
argument-hint: "[프리셋 이름: nextjs-fsd]"
disable-model-invocation: true
---

# /selfish:init — 프로젝트 초기 설정

> 현재 프로젝트에 `.claude/selfish.config.md` 설정 파일을 생성한다.
> package.json, 디렉토리 구조, 설정 파일 등을 분석하여 프로젝트에 맞는 설정을 자동 추론한다.

## 인자

- `$ARGUMENTS` — (선택) 템플릿 프리셋 이름 (예: `nextjs-fsd`)
  - 미지정 시: 프로젝트 구조를 분석하여 자동 추론
  - 프리셋 지정 시: `${CLAUDE_PLUGIN_ROOT}/templates/selfish.config.{preset}.md` 사용

## 실행 절차

### 1. 기존 설정 확인

`.claude/selfish.config.md`가 이미 존재하면:
- 사용자에게 확인: "설정 파일이 이미 존재합니다. 덮어쓰시겠습니까?"
- 거부 시 **중단**

### 2. 프리셋 분기

#### A. 프리셋 지정 (`$ARGUMENTS`가 있는 경우)

1. `${CLAUDE_PLUGIN_ROOT}/templates/selfish.config.{$ARGUMENTS}.md` 존재 확인
2. 있으면: 해당 파일을 `.claude/selfish.config.md`로 복사
3. 없으면: "프리셋 `{$ARGUMENTS}`을 찾을 수 없습니다. 사용 가능: {목록}" 출력 후 **중단**

#### B. 자동 추론 (`$ARGUMENTS` 없는 경우)

프로젝트 구조를 분석하여 설정을 자동 추론:

**Step 1. 패키지 매니저 / 스크립트 감지**
- `package.json` 읽기 → `scripts` 필드에서 CI 관련 커맨드 추출
- lockfile로 패키지 매니저 판별 (yarn.lock / pnpm-lock.yaml / package-lock.json)
- 감지된 스크립트를 `CI Commands` 섹션에 반영

**Step 2. 프레임워크 감지**
- `package.json`의 dependencies/devDependencies에서 판별:
  - `next` → Next.js (App Router/Pages Router는 `app/` 디렉토리 존재 여부로 판별)
  - `nuxt` → Nuxt
  - `@sveltejs/kit` → SvelteKit
  - `vite` → Vite
  - 등
- `tsconfig.json` 유무 → TypeScript 여부

**Step 3. 아키텍처 감지**
- 디렉토리 구조 분석:
  - `src/app/`, `src/features/`, `src/entities/`, `src/shared/` → FSD
  - `src/domain/`, `src/application/`, `src/infrastructure/` → Clean Architecture
  - `src/modules/` → Modular
  - 기타 → Layered
- `tsconfig.json`의 `paths` → path_alias 추출

**Step 4. 상태 관리 감지**
- dependencies에서:
  - `zustand` → Zustand
  - `@reduxjs/toolkit` → Redux Toolkit
  - `@tanstack/react-query` → React Query
  - `swr` → SWR
  - `pinia` → Pinia

**Step 5. 스타일링 / 테스팅 감지**
- `tailwindcss` → Tailwind CSS
- `styled-components` → styled-components
- `jest` / `vitest` / `playwright` → 각각 매핑

**Step 6. 코드 스타일 감지**
- `.eslintrc*` / `eslint.config.*` 확인 → 린트 규칙 파악
- `tsconfig.json`의 `strict` → strict_mode
- 기존 코드 샘플 2-3개 읽어 네이밍 패턴 확인

### 3. 설정 파일 생성

1. `${CLAUDE_PLUGIN_ROOT}/templates/selfish.config.template.md`를 기반으로 설정 생성
2. 자동 추론된 값으로 빈칸 채우기
3. 추론 불가 항목은 템플릿 기본값 유지 + 주석으로 `# TODO: 프로젝트에 맞게 수정` 표시
4. `.claude/selfish.config.md`에 저장

### 4. 최종 출력

```
⚙️ 프로젝트 설정 완료
├─ 파일: .claude/selfish.config.md
├─ 프레임워크: {감지된 프레임워크}
├─ 아키텍처: {감지된 스타일}
├─ 패키지 매니저: {감지된 매니저}
├─ 자동 추론: {추론된 항목 수}개
├─ TODO: {수동 확인 필요 항목 수}개
└─ 다음 단계: 설정 파일 확인 후 /selfish:spec 또는 /selfish:auto
```

## 주의사항

- **덮어쓰기 주의**: 기존 설정 파일이 있으면 반드시 사용자 확인.
- **추론 한계**: 자동 추론은 최선의 추정. 사용자가 검토 후 수정해야 할 수 있음.
- **프리셋 경로**: 프리셋은 플러그인 내 `templates/` 디렉토리에서 로드.
- **`.claude/` 디렉토리**: 없으면 자동 생성.
