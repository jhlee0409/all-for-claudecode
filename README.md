# Selfish Pipeline

**Claude Code 전용 자동화 파이프라인 플러그인**

## 설치

```bash
claude plugin add selfish-pipeline
```

## 주요 기능

- **Full Auto 파이프라인**: spec → plan → tasks → implement → review → clean 전 과정 자동화
- **16개 슬래시 커맨드**: 7개 사용자 호출 커맨드 + 9개 내부 커맨드
- **13개 Hook 이벤트 통합**: 세션 복원, 위험 명령 차단, 자동 포맷팅 등
- **5개 프로젝트 프리셋**: Next.js, React SPA, Express API, Monorepo 등
- **Critic Loop 자동 품질 검증**: 구현 후 자동 리뷰 및 보안 스캔

## 커맨드 목록

### 사용자 호출 커맨드

| 커맨드 | 설명 |
|---|---|
| `/selfish:auto` | Full Auto 파이프라인 |
| `/selfish:spec` | 기능 명세서 생성 |
| `/selfish:plan` | 구현 설계 |
| `/selfish:implement` | 코드 구현 실행 |
| `/selfish:review` | 코드 리뷰 |
| `/selfish:research` | 기술 리서치 |
| `/selfish:init` | 프로젝트 초기 설정 |

### 내부 커맨드 (모델 자동 호출)

| 커맨드 | 설명 |
|---|---|
| `/selfish:tasks` | 태스크 분해 |
| `/selfish:analyze` | 아티팩트 정합성 검증 |
| `/selfish:architect` | 아키텍처 분석 |
| `/selfish:security` | 보안 스캔 |
| `/selfish:clarify` | 명세 모호성 해소 |
| `/selfish:debug` | 버그 진단 및 수정 |
| `/selfish:principles` | 프로젝트 원칙 관리 |
| `/selfish:checkpoint` | 세션 상태 저장 |
| `/selfish:resume` | 세션 복원 |

## Hook 이벤트

| Hook | 동작 |
|---|---|
| `SessionStart` | 파이프라인 상태 복원 |
| `PreCompact` | 컨텍스트 압축 전 자동 체크포인트 |
| `PreToolUse (Bash)` | 위험 명령 차단 (`push --force` 등) |
| `PostToolUse (Edit/Write)` | 변경 파일 추적 + 자동 포맷팅 |
| `SubagentStart` | 서브에이전트 컨텍스트 주입 |
| `Stop` | CI 게이트 (미통과 시 응답 차단) |
| `SessionEnd` | 파이프라인 미완료 경고 |
| `PostToolUseFailure` | 실패 진단 힌트 |
| `Notification` | 데스크탑 알림 |
| `TaskCompleted` | 태스크 완료 CI 게이트 |
| `SubagentStop` | 서브에이전트 완료 추적 |
| `UserPromptSubmit` | 매 프롬프트에 파이프라인 Phase/Feature 컨텍스트 주입 |
| `PermissionRequest` | implement/review Phase에서 CI 관련 Bash 자동 허용 |

## 프리셋

| 프리셋 | 기술 스택 |
|---|---|
| `template` | 범용 (수동 설정) |
| `nextjs-fsd` | Next.js + FSD + Zustand + React Query |
| `react-spa` | Vite + React 18 + Zustand + Tailwind |
| `express-api` | Express + TypeScript + Prisma + Jest |
| `monorepo` | Turborepo + pnpm workspace |

## 설정

프로젝트 초기화:

```bash
/selfish:init
```

프로젝트별 설정은 `.claude/selfish.config.md`에 저장됩니다.

## 라이선스

MIT
