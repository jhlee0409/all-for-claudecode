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
test: "npx jest --runInBand"                         # 테스트
```

## Architecture

```yaml
style: "Layered"                        # 계층형 아키텍처
layers:                                 # 상위 → 하위 순서
  - src/routes
  - src/controllers
  - src/services
  - src/repositories
  - src/models
  - src/middleware
  - src/lib
  - src/types
  - src/config
import_rule: "상위 계층(routes)은 하위(controllers→services→repositories) 순으로만 의존"
segments: []
path_alias: "@/* → ./src/*"
```

## Framework

```yaml
name: "Express.js"
runtime: "Node.js (CommonJS 또는 ESM)"
client_directive: ""                    # 서버 전용 — 해당 없음
server_client_boundary: false           # 서버 전용 애플리케이션
```

## Code Style

```yaml
language: "TypeScript"
strict_mode: true
type_keyword: "type"                    # interface 대신 type 사용
import_type: true                       # import type { ... } 사용
component_style: ""                     # UI 컴포넌트 없음
props_position: ""                      # UI 컴포넌트 없음
handler_naming: "camelCase"
boolean_naming: "is/has/can[State]"
constant_naming: "UPPER_SNAKE_CASE"
any_policy: "금지 (strict mode + unknown 사용)"
```

## State Management

```yaml
global_state: ""                        # 서버 — stateless
server_state: ""
local_state: ""
store_location: ""
query_location: ""
```

## Styling

```yaml
framework: ""                           # 해당 없음
```

## Testing

```yaml
framework: "Jest + Supertest"
```

## Project-Specific Risks

> Plan의 RISK Critic에서 반드시 점검할 프로젝트 고유 위험 패턴

1. Prisma 마이그레이션과 스키마 불일치
2. Express 미들웨어 순서 오류 (인증 → 검증 → 핸들러)
3. async/await 에러 핸들링 누락 (try-catch 또는 wrapper)
4. 환경 변수(.env) 미설정 시 런타임 에러
5. SQL injection (Prisma 사용 시 raw query 주의)

## Mini-Review Checklist

> Implement Phase 게이트의 Mini-Review에서 각 파일에 대해 점검할 항목

1. TypeScript strict mode 위반
2. 에러 핸들링 (async 라우트에 try-catch 또는 asyncHandler)
3. 입력 검증 (req.body/params/query 타입 체크)
4. 미사용 import / dead code
