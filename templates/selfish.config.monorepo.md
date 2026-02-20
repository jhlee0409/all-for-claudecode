# Selfish Configuration

> 이 파일은 selfish 커맨드 시스템의 프로젝트별 설정을 정의한다.
> 모든 selfish 커맨드는 이 파일을 참조하여 프로젝트별 동작을 결정한다.

## CI Commands

```yaml
ci: "pnpm turbo build lint test"        # 전체 CI (lint + typecheck + build)
typecheck: "pnpm turbo typecheck"       # 타입 체크만
lint: "pnpm turbo lint"                 # 린트만
lint_fix: "pnpm turbo lint -- --fix"   # 린트 자동 수정
gate: "pnpm turbo typecheck lint"       # Phase 게이트 (implement 중 반복 실행)
test: "pnpm turbo test"                 # 테스트
```

## Architecture

```yaml
style: "Monorepo"
layers:                                 # 최상위 → 패키지 순서
  - apps/
  - packages/
import_rule: "apps/는 packages/만 import 가능. packages/ 간 명시적 의존성 선언 (package.json)"
segments:
  - apps/web       # 웹 앱
  - apps/api       # API 서버
  - packages/ui    # 공유 UI 컴포넌트
  - packages/config   # 공유 설정 (ESLint, Prettier 등)
  - packages/tsconfig # 공유 TypeScript 설정
  - packages/utils    # 공유 유틸리티
path_alias: "@repo/* → packages/*"
```

## Framework

```yaml
name: "Turborepo + pnpm workspace"
runtime: "다중 (앱별 상이)"
client_directive: "앱별 상이"
server_client_boundary: "앱별 상이"    # 각 앱의 프레임워크에 따라 결정
```

## Code Style

```yaml
language: "TypeScript"
strict_mode: true
type_keyword: "type"                    # interface 대신 type 사용
import_type: true                       # import type { ... } 사용
component_style: "PascalCase"
props_position: "above component"       # Props 타입은 컴포넌트 위에 정의
handler_naming: "handle[Event]"
boolean_naming: "is/has/can[State]"
constant_naming: "UPPER_SNAKE_CASE"
any_policy: "최소화 (공유 패키지는 특히 엄격)"
```

## State Management

```yaml
global_state: "앱별 상이"
server_state: "앱별 상이"
local_state: "앱별 상이"
store_location: "각 앱 내부"
query_location: "각 앱 내부"
```

## Styling

```yaml
framework: "앱별 상이 (공유 UI 패키지는 Tailwind CSS)"
```

## Testing

```yaml
framework: "앱별 상이 (Vitest 또는 Jest)"
```

## Project-Specific Risks

> Plan의 RISK Critic에서 반드시 점검할 프로젝트 고유 위험 패턴

1. 패키지 간 순환 의존성 (turborepo가 감지하지만 런타임 에러 가능)
2. 공유 패키지 변경 시 의존 앱 빌드 실패
3. pnpm workspace 프로토콜(workspace:*) 누락 시 npm publish 에러
4. tsconfig 상속 체인 불일치 (extends 경로 오류)
5. turbo.json의 pipeline 캐시 설정 오류로 stale 빌드

## Mini-Review Checklist

> Implement Phase 게이트의 Mini-Review에서 각 파일에 대해 점검할 항목

1. 패키지 간 의존성 방향 (apps → packages만 허용)
2. 공유 패키지 export 경로 (package.json exports 필드)
3. TypeScript strict mode + path alias 일치
4. turbo.json pipeline 설정과 실제 스크립트 일치
