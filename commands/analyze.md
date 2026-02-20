---
name: selfish:analyze
description: "아티팩트 정합성 검증 (읽기 전용)"
argument-hint: "[검증 범위: spec-plan, tasks-only]"
user-invocable: false
context: fork
agent: Explore
allowed-tools:
  - Read
  - Grep
  - Glob
---

# /selfish:analyze — 아티팩트 정합성 검증

> spec.md, plan.md, tasks.md 간의 일관성과 품질을 검증한다.
> **읽기 전용** — 파일을 수정하지 않는다.

## 인자

- `$ARGUMENTS` — (선택) 검증 범위 한정 (예: "spec-plan", "tasks-only")

## 설정 로드

프로젝트 루트의 `CLAUDE.md` 또는 `.claude/CLAUDE.md`에서 다음 설정을 읽어 `config` 변수에 할당:

```
config.architecture = 프로젝트에서 사용하는 아키텍처 패턴
                      (예: "FSD", "Clean Architecture", "Layered", "Modular Monolith")
                      → CLAUDE.md에 명시된 아키텍처 기준. 없으면 "레이어드 아키텍처"로 가정.
```

## 실행 절차

### 1. 아티팩트 로드

`specs/{feature}/`에서:
- **spec.md** (필수)
- **plan.md** (필수)
- **tasks.md** (있으면)
- **research.md** (있으면)

누락 파일이 있으면 경고하되 있는 것으로 진행.

### 2. 검증 수행

6가지 카테고리를 검증:

#### A. 중복 감지 (DUPLICATION)
- spec.md 내 유사한 요구사항
- tasks.md 내 겹치는 태스크

#### B. 모호성 감지 (AMBIGUITY)
- 측정 불가능한 형용사 ("적절한", "빠른", "좋은")
- TODO/TBD/FIXME 잔류
- 불완전한 문장

#### C. 커버리지 갭 (COVERAGE)
- spec → plan: 모든 FR-*/NFR-*가 plan에 반영되었는가?
- plan → tasks: plan의 File Change Map 모든 항목이 tasks에 있는가?
- spec → tasks: 모든 요구사항이 태스크에 매핑되는가?

#### D. 불일치 (INCONSISTENCY)
- 용어 드리프트 (같은 개념에 다른 이름)
- 충돌하는 요구사항
- plan의 기술 결정과 tasks의 실행이 불일치

#### E. 원칙 준수 (PRINCIPLES)
- memory/principles.md가 있으면 MUST 원칙 대비 검증
- {config.architecture} 규칙 위반 가능성

#### F. 리스크 미식별 (RISK)
- plan.md에 식별되지 않은 리스크가 있는가?
- 외부 의존성 리스크
- 성능 병목 가능성

### 3. 심각도 분류

| 심각도 | 기준 |
|--------|------|
| **CRITICAL** | 원칙 위반, 핵심 기능 차단, 보안 문제 |
| **HIGH** | 중복/충돌, 테스트 불가능, 커버리지 갭 |
| **MEDIUM** | 용어 드리프트, 모호한 요구사항 |
| **LOW** | 스타일 개선, 사소한 중복 |

### 4. 결과 출력 (콘솔)

```markdown
## 정합성 분석 결과: {기능명}

### 발견사항
| ID | 카테고리 | 심각도 | 위치 | 요약 | 권장 조치 |
|----|----------|--------|------|------|-----------|
| A-001 | COVERAGE | HIGH | spec FR-003 | tasks에 매핑 없음 | 태스크 추가 |
| A-002 | AMBIGUITY | MEDIUM | spec NFR-001 | "빠르게" 측정 불가 | 수치 기준 추가 |

### 커버리지 요약
| 매핑 | 비율 |
|------|------|
| spec → plan | {N}% |
| plan → tasks | {N}% |
| spec → tasks | {N}% |

### 메트릭스
- 총 요구사항: {N}개
- 총 태스크: {N}개
- 이슈: CRITICAL {N} / HIGH {N} / MEDIUM {N} / LOW {N}

### 다음 단계
{CRITICAL/HIGH 이슈에 대한 구체적 조치 제안}
```

### 5. 최종 출력

```
🔎 분석 완료
├─ 발견: CRITICAL {N} / HIGH {N} / MEDIUM {N} / LOW {N}
├─ 커버리지: spec→plan {N}%, plan→tasks {N}%, spec→tasks {N}%
└─ 권장: {다음 액션}
```

## 주의사항

- **읽기 전용**: 어떤 파일도 수정하지 않는다. 보고만 한다.
- **오탐 주의**: 모호성 감지가 과도하지 않도록. 컨텍스트를 고려.
- **선택적**: 파이프라인에서 필수가 아님. plan → tasks → implement 직행 가능.
