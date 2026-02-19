# Selfish

> Claude Code 전용 자동화 파이프라인 시스템

기능 설명 하나로 **spec → plan → tasks → implement → review → clean** 전체 개발 파이프라인을 자동 실행합니다.

## 특징

- **외부 의존성 제로**: 순수 마크다운 프롬프트 + bash hook
- **프로젝트 독립적**: `selfish.config.md`로 어떤 프로젝트에도 적용 가능
- **물리적 CI 게이트**: Stop hook으로 CI 미통과 시 응답 종료 자체를 차단
- **Critic Loop**: 각 단계에서 자기비판을 통한 산출물 품질 보장
- **Agent Teams**: 독립 태스크를 병렬 서브에이전트로 동시 실행
- **세션 연속성**: 컨텍스트 압축/세션 중단 시에도 체크포인트로 복원

## 요구사항

- [Claude Code](https://claude.ai/code) CLI (플러그인 시스템 지원 버전)
- Git
- `jq` (PostToolUse hook에서 사용)

## 설치

```bash
npx selfish-pipeline
```

마켓플레이스 등록 + 플러그인 설치를 자동 수행하며, 설치 범위(user / project / local)를 인터랙티브하게 선택합니다.

### 수동 설치

```bash
# 1. 마켓플레이스 등록
claude plugin marketplace add jhlee0409/selfish-pipeline

# 2. 플러그인 설치 (스코프 선택)
claude plugin install selfish@selfish-pipeline --scope user      # 개인 전체
claude plugin install selfish@selfish-pipeline --scope project   # 팀 공유
claude plugin install selfish@selfish-pipeline --scope local     # 이 프로젝트만
```

### 설치 후 프로젝트 초기 설정

```text
/selfish:init                  # 프로젝트 구조 자동 분석
/selfish:init nextjs-fsd       # Next.js + FSD 프리셋 사용
```

> 기존 `git clone` + `install.sh` 방식에서 마이그레이션하는 경우 [MIGRATION.md](./MIGRATION.md)를 참고하세요.

## 설정

`/selfish:init` 실행 후 `.claude/selfish.config.md`를 프로젝트에 맞게 수정합니다:

```yaml
# CI 명령어
ci: "yarn ci"
gate: "yarn typecheck && yarn lint"

# 아키텍처
style: "FSD"
layers: [app, views, widgets, features, entities, shared, core]
import_rule: "상위 계층은 하위 계층만 import 가능"

# 프레임워크
name: "Next.js 14"
client_directive: "'use client'"
```

## 커맨드

### Full Auto (권장)

```text
/selfish:auto "사용자 인증 기능 추가"
```

spec → plan → tasks → implement → review → clean 전체를 자동 실행합니다.

### 개별 실행

| 커맨드 | 역할 | Critic |
|--------|------|--------|
| `/selfish:spec` | 기능 명세서 생성 | 1회 |
| `/selfish:clarify` | 명세 모호성 해소 | - |
| `/selfish:plan` | 구현 설계 | 3회 |
| `/selfish:tasks` | 태스크 분해 | 1회 |
| `/selfish:analyze` | 아티팩트 정합성 검증 | - |
| `/selfish:implement` | 코드 구현 실행 | - |
| `/selfish:review` | 코드 리뷰 | 1회 |
| `/selfish:debug` | 버그 진단/수정 | 2회 |
| `/selfish:architect` | 아키텍처 분석 | 3회 |
| `/selfish:security` | 보안 스캔 | - |
| `/selfish:research` | 기술 리서치 | - |
| `/selfish:principles` | 프로젝트 원칙 관리 | - |
| `/selfish:checkpoint` | 세션 상태 저장 | - |
| `/selfish:resume` | 세션 복원 | - |
| `/selfish:init` | 프로젝트 초기 설정 | - |

### 파이프라인 흐름

```text
/selfish:spec "기능 설명"  →  specs/{feature}/spec.md
          ↓
/selfish:clarify (선택)    →  spec.md 인라인 업데이트
          ↓
/selfish:plan              →  plan.md + research.md
          ↓
/selfish:tasks             →  tasks.md
          ↓
/selfish:analyze (선택)    →  정합성 보고서
          ↓
/selfish:implement         →  코드 구현 (Phase별 CI 게이트)
          ↓
/selfish:review (선택)     →  리뷰 보고서
```

## 핵심 메커니즘

### Critic Loop

각 단계에서 산출물을 자기비판합니다. 형식적 "PASS"를 방지하는 4가지 필수 원칙:

1. **최소 발견 수**: 기준당 최소 1개의 우려/검증 근거
2. **체크리스트 응답**: "PASS" 한 단어 금지, 구체적 답변 필수
3. **Adversarial Pass**: 매 회차 "실패 시나리오 1가지" 필수
4. **정량적 근거**: "N개 중 M개 확인" 형태의 데이터 제시

### 3단계 Phase 게이트

Implement 중 각 Phase 완료 시:

1. **CI 게이트**: `{config.gate}` 실행 (3회 실패 → 중단)
2. **Mini-Review**: 변경 파일별 정량적 품질 점검
3. **Auto-Checkpoint**: 세션 상태 저장 (중단 시 복원용)

### Stop Gate Hook

파이프라인 활성 중 CI 미통과 시 `exit 2`로 Claude의 응답 종료를 물리적으로 차단합니다.

## Hook 설명

| Hook | 이벤트 | 역할 |
|------|--------|------|
| `session-start-context.sh` | SessionStart | 파이프라인 상태 복원 |
| `pre-compact-checkpoint.sh` | PreCompact | 컨텍스트 압축 전 체크포인트 |
| `track-selfish-changes.sh` | PostToolUse | 파일 변경 추적, CI 무효화 |
| `selfish-stop-gate.sh` | Stop | CI 게이트 강제 |
| `selfish-pipeline-manage.sh` | (내부 호출) | 파이프라인 상태 플래그 관리 |

## 디렉토리 구조

```text
selfish-pipeline/
├── .claude-plugin/
│   └── plugin.json              # 플러그인 매니페스트
├── bin/
│   └── cli.mjs                  # npx 인터랙티브 인스톨러
├── commands/                    # 16개 커맨드
│   ├── auto.md                  # Full Auto 파이프라인
│   ├── spec.md                  # 기능 명세서
│   ├── plan.md                  # 구현 설계
│   ├── tasks.md                 # 태스크 분해
│   ├── implement.md             # 코드 구현
│   ├── review.md                # 코드 리뷰
│   ├── debug.md                 # 버그 진단
│   ├── architect.md             # 아키텍처 분석
│   ├── security.md              # 보안 스캔
│   ├── analyze.md               # 정합성 검증
│   ├── clarify.md               # 명세 모호성 해소
│   ├── research.md              # 기술 리서치
│   ├── principles.md            # 원칙 관리
│   ├── checkpoint.md            # 세션 저장
│   ├── resume.md                # 세션 복원
│   └── init.md                  # 프로젝트 초기 설정
├── hooks/
│   └── hooks.json               # hook 이벤트 등록
├── scripts/                     # 5개 bash hook 스크립트
│   ├── session-start-context.sh
│   ├── pre-compact-checkpoint.sh
│   ├── track-selfish-changes.sh
│   ├── selfish-stop-gate.sh
│   └── selfish-pipeline-manage.sh
├── templates/
│   ├── selfish.config.template.md   # 프로젝트 설정 템플릿
│   └── selfish.config.nextjs-fsd.md # Next.js + FSD 예시
├── package.json                 # npx 실행용
├── README.md
├── MIGRATION.md                 # 기존 사용자 마이그레이션 가이드
└── LICENSE
```

## 라이선스

MIT
