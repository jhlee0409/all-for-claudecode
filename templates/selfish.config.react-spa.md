# Selfish Configuration

> 이 파일은 selfish 커맨드 시스템의 프로젝트별 설정을 정의한다.
> 모든 selfish 커맨드는 이 파일을 참조하여 프로젝트별 동작을 결정한다.

## CI Commands

```yaml
ci: "npm run build && npm run lint && npm run test"  # 전체 CI (build + lint + test)
typecheck: "npx tsc --noEmit"                        # 타입 체크만
lint: "npx eslint src/"                              # 린트만
lint_fix: "npx eslint src/ --fix"                    # 린트 자동 수정
gate: "npx tsc --noEmit && npx eslint src/"          # Phase 게이트 (implement 중 반복 실행)
test: "npx vitest run"                               # 테스트
```

## Architecture

```yaml
style: "Modular"
layers:                                 # 역할별 분리 구조
  - src/components
  - src/features
  - src/hooks
  - src/lib
  - src/stores
  - src/types
  - src/api
import_rule: "features/ 간 직접 import 불가 (shared 경유)"
segments: []
path_alias: "@/* → ./src/*"
```

## Framework

```yaml
name: "Vite + React 18"
runtime: "SPA (Client-Side)"
client_directive: ""                    # SPA이므로 불필요
server_client_boundary: false           # 서버/클라이언트 경계 없음
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
local_state: "useState / useReducer"
store_location: "src/stores/"
query_location: "src/api/"
```

## Styling

```yaml
framework: "Tailwind CSS v3"
```

## Testing

```yaml
framework: "Vitest + React Testing Library"
```

## Project-Specific Risks

> Plan의 RISK Critic에서 반드시 점검할 프로젝트 고유 위험 패턴

1. Vite HMR이 꺼진 채로 빌드 시 환경 변수 누락
2. React Query 캐시 무효화 누락으로 stale 데이터 표시
3. Zustand store에서 selector 미사용 시 불필요한 리렌더링
4. path alias와 Vite resolve.alias 불일치

## Mini-Review Checklist

> Implement Phase 게이트의 Mini-Review에서 각 파일에 대해 점검할 항목

1. TypeScript strict mode 위반 (any, as unknown)
2. import 경로가 path alias(@/) 사용하는지
3. React hooks 규칙 (조건부 hook 호출 금지)
4. 미사용 import / dead code
