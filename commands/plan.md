---
name: selfish:plan
description: "구현 설계"
argument-hint: "[추가 컨텍스트 또는 제약 조건]"
model: sonnet
---
# /selfish:plan — 구현 설계

> 기능 명세(spec.md)를 기반으로 구현 계획(plan.md)을 생성한다.
> Critic Loop 3회로 품질을 보장하고, 필요 시 리서치를 병렬 수행한다.

## 인자

- `$ARGUMENTS` — (선택) 추가 컨텍스트 또는 제약 조건

## 프로젝트 설정 (자동 로드)

!`cat .claude/selfish.config.md 2>/dev/null || echo "[CONFIG NOT FOUND] .claude/selfish.config.md가 없습니다. /selfish:init으로 생성하세요."`

## 설정 로드

**반드시** `.claude/selfish.config.md`를 먼저 읽는다 (위에 자동 로드되지 않았다면 수동으로 읽는다). 설정 파일이 없으면 중단.

## 실행 절차

### 1. 컨텍스트 로드

1. **현재 브랜치** 확인 → `BRANCH_NAME`
2. **specs/{feature}/spec.md** 탐색:
   - `specs/` 하위에서 현재 브랜치명 또는 `$ARGUMENTS`와 매칭되는 디렉토리 찾기
   - 없으면: "spec.md가 없습니다. `/selfish:spec`을 먼저 실행하세요." 출력 후 **중단**
3. **spec.md** 전체 읽기
4. **memory/principles.md** 읽기 (있으면)
5. **CLAUDE.md** 프로젝트 컨텍스트 읽기

### 2. 명확화 확인

- spec.md에 `[NEEDS CLARIFICATION]` 태그가 있으면:
  - 사용자에게 경고: "미해결 명확화 항목이 있습니다. 계속하시겠습니까?"
  - 사용자가 중단 선택 시 → `/selfish:clarify` 안내 후 **중단**

### 3. Phase 0 — 리서치 (필요 시)

spec.md에서 기술적 불확실성을 추출한다:

1. 사용하지 않은 라이브러리/API가 있는가?
2. 성능 요구사항이 검증되지 않았는가?
3. 기존 코드베이스와의 통합 방식이 불확실한가?

불확실 항목이 **있으면**:
- 각 항목을 WebSearch/코드베이스 탐색으로 해결
- 결과를 `specs/{feature}/research.md`에 기록:
  ```markdown
  ## {주제}
  **결정**: {선택한 방식}
  **근거**: {이유}
  **대안**: {검토한 다른 방식}
  **출처**: {URL 또는 파일 경로}
  ```

불확실 항목이 **없으면**: Phase 0 스킵.

### 4. Phase 1 — 설계 작성

`specs/{feature}/plan.md`를 생성한다. 아래 구조를 **반드시** 따른다:

```markdown
# Implementation Plan: {기능명}

## Summary
{spec의 핵심 요구사항 + 기술적 접근 요약, 3-5문장}

## Technical Context
{selfish.config.md에서 로드한 프로젝트 설정 요약}
- **Language**: {config.code_style.language}
- **Framework**: {config.framework.name}
- **State**: {config.state_management 요약}
- **Architecture**: {config.architecture.style}
- **Styling**: {config.styling.framework}
- **Testing**: {config.testing.framework}
- **Constraints**: {spec에서 추출한 제약사항}

## Principles Check
{memory/principles.md가 있으면 MUST 원칙 대비 검증 결과}
{위반 가능성 있으면 명시 + 정당화}

## Architecture Decision
### 접근 방식
{선택한 설계의 핵심 아이디어}

### 아키텍처 배치
| 계층 | 경로 | 역할 |
|------|------|------|
| {entities/features/widgets/shared} | {경로} | {설명} |

### 상태 관리 전략
{Zustand store / React Query / Context 등 어떤 조합을 어디에 쓸지}

### API 설계
{새로운 API 엔드포인트 또는 기존 API 사용 계획}

## File Change Map
{변경/생성할 파일 목록. 각 파일에 대해:}
| 파일 | 작업 | 설명 |
|------|------|------|
| {경로} | 생성/수정/삭제 | {변경 내용 요약} |

## Risk & Mitigation
| 리스크 | 영향 | 완화 방안 |
|--------|------|-----------|
| {리스크} | {H/M/L} | {방안} |

## Phase 구분
### Phase 1: Setup
{프로젝트 구조, 타입 정의, 설정}

### Phase 2: Core Implementation
{핵심 비즈니스 로직, 상태 관리}

### Phase 3: UI & Integration
{UI 컴포넌트, API 연동}

### Phase 4: Polish
{에러 처리, 성능 최적화, 테스트}
```

### 5. Critic Loop (3회)

plan.md 초안 작성 후, **최대 3회** 자가 비판을 수행한다.

각 회차마다 아래 5가지 기준을 검증:

| 기준 | 검증 내용 |
|------|-----------|
| **COMPLETENESS** | spec.md의 모든 요구사항(FR-*)이 plan에 반영되었는가? |
| **FEASIBILITY** | 기존 코드베이스와 호환 가능한가? 의존성이 사용 가능한가? |
| **ARCHITECTURE** | {config.architecture} 규칙을 준수하는가? |
| **RISK** | 식별되지 않은 리스크가 있는가? |
| **PRINCIPLES** | principles.md의 MUST 원칙을 위반하지 않는가? |

**사용자 출력 규칙**:
- **FAIL 항목이 있으면**: `⚠ {기준}: {문제 요약}. 수정 중...` 표시 → plan.md 수정 → 다음 회차
- **FAIL 항목이 없으면**: `✓ Critic {N}/3 통과` 한 줄
- **최종**: `Critic Loop 완료 ({N}회). 주요 수정: {변경 요약}` 또는 `Critic Loop 완료 (1회). 수정 없음.`

### 6. Agent Teams (필요 시)

리서치 항목이 3개 이상이면, Task 도구로 병렬 리서치 에이전트를 위임:

```
TaskCreate("Research: {주제1}", subagent_type: Explore)
TaskCreate("Research: {주제2}", subagent_type: Explore)
→ 결과 수집 → research.md에 통합
```

### 7. 최종 출력

```
📋 Plan 생성 완료
├─ specs/{feature}/plan.md
├─ specs/{feature}/research.md (리서치 있었으면)
├─ Critic: {N}회, 주요 수정: {요약}
└─ 다음 단계: /selfish:tasks
```

## 주의사항

- plan.md는 **실행 가능한 수준**으로 작성. 모호한 "적절히 처리" 같은 표현 금지.
- File Change Map의 파일 경로는 **실제 프로젝트 구조**에 기반해야 함 (추측 금지).
- {config.architecture} 규칙에 따라 배치하며, 기존 코드베이스 패턴을 확인하고 따름.
- CLAUDE.md의 프로젝트 설정과 충돌하면 CLAUDE.md가 우선.
