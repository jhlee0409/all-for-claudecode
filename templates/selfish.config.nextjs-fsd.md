# Selfish Configuration

> 이 파일은 selfish 커맨드 시스템의 프로젝트별 설정을 정의한다.
> 모든 selfish.* 커맨드는 이 파일을 참조하여 프로젝트별 동작을 결정한다.

## CI Commands

```yaml
ci: "yarn ci"                           # 전체 CI (lint + typecheck + build)
typecheck: "yarn typecheck"             # 타입 체크만
lint: "yarn lint"                       # 린트만
lint_fix: "yarn lint:fix"               # 린트 자동 수정
gate: "yarn typecheck && yarn lint"     # Phase 게이트 (implement 중 반복 실행)
test: "yarn test"                       # 테스트
```

## Architecture

```yaml
style: "FSD"                            # Feature-Sliced Design
layers:                                 # 상위 → 하위 순서
  - app
  - views
  - widgets
  - features
  - entities
  - shared
  - core
import_rule: "상위 계층은 하위 계층만 import 가능 (역방향 불가)"
segments:
  - api       # API 관련 로직 (React Query hooks)
  - model     # 상태 관리 및 타입 정의
  - ui        # UI 컴포넌트
  - lib       # 유틸리티 함수
  - config    # 설정 및 상수
  - hooks     # 커스텀 훅
path_alias: "@/* → ./src/*"
```

## Framework

```yaml
name: "Next.js 14"
runtime: "App Router"
client_directive: "'use client'"
client_directive_rule: >
  useState/useEffect/useRef 등 클라이언트 훅을 사용하는 파일은
  반드시 'use client' 선언 필요. barrel export(index.ts)를 통해
  서버 컴포넌트에서 간접 import 되는 경우 특히 주의.
server_client_boundary: true            # 서버/클라이언트 경계가 존재
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
any_policy: "최소화 (strict mode 준수)"
```

## State Management

```yaml
global_state: "Zustand"
server_state: "React Query v5"
local_state: "Context API (use-context-selector)"
store_location: "model/ 세그먼트"
query_location: "api/ 세그먼트"
```

## Styling

```yaml
framework: "Tailwind CSS v3"
```

## Testing

```yaml
framework: "Jest + React Testing Library"
```

## Project-Specific Risks

> Plan의 RISK Critic에서 반드시 점검할 프로젝트 고유 위험 패턴

1. barrel export 체인에서 `'use client'` 누락 → build 실패
2. import 순서 위반 (ESLint FSD import order)
3. 순환 참조 (shared/ui 내부에서 barrel import 사용 시)
4. FSD 계층 역방향 import
5. `as any` 잔류 → typecheck 우회

## Mini-Review Checklist

> Implement Phase 게이트의 Mini-Review에서 각 파일에 대해 점검할 항목

1. `'use client'` 필요 여부 (클라이언트 훅 사용 시 필수)
2. FSD 계층 위반 (import 경로 N개 중 위반 M개)
3. 프로젝트 패턴 (`type` vs `interface`, naming, import order)
4. 미사용 코드 (미사용 import, 빈 export, dead code)
