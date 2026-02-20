---
name: selfish:spec
description: "기능 명세서 생성"
argument-hint: "[기능 설명 자연어 텍스트]"
model: sonnet
---
# /selfish:spec — 기능 명세서 생성

> 자연어 기능 설명을 구조화된 명세서(spec.md)로 변환한다.
> 외부 스크립트 없이 순수 프롬프트로 동작한다.

## 인자

- `$ARGUMENTS` — (필수) 기능 설명 자연어 텍스트

## 프로젝트 설정 (자동 로드)

!`cat .claude/selfish.config.md 2>/dev/null || echo "[CONFIG NOT FOUND] .claude/selfish.config.md가 없습니다. /selfish:init으로 생성하세요."`

## 설정 로드

**반드시** `.claude/selfish.config.md`를 먼저 읽는다 (위에 자동 로드되지 않았다면 수동으로 읽는다). 설정 파일이 없으면 중단.

## 실행 절차

### 1. Feature 디렉토리 설정

1. **현재 브랜치** 확인 → `BRANCH_NAME`
2. **Feature 이름** 결정:
   - `$ARGUMENTS`에서 핵심 키워드 2-3개 추출
   - kebab-case로 변환 (예: "사용자 인증 추가" → `user-auth`)
3. **디렉토리 생성**: `specs/{feature-name}/`
4. 이미 존재하면 사용자에게 확인: "기존 spec을 덮어쓰시겠습니까?"

### 2. 코드베이스 탐색

spec 작성 전 현재 프로젝트 구조를 파악한다:

1. `{config.architecture}` 계층별 주요 디렉토리 확인
2. 기능 설명과 관련된 기존 코드 탐색 (Grep/Glob)
3. 관련 타입 정의, API, 컴포넌트 파악

### 3. Spec 작성

`specs/{feature-name}/spec.md`를 생성한다:

```markdown
# Feature Spec: {기능명}

> 생성일: {YYYY-MM-DD}
> 브랜치: {BRANCH_NAME}
> 상태: Draft

## 개요
{기능의 목적과 배경을 2-3문장으로}

## User Stories

### US1: {스토리 제목} [P1]
**설명**: {사용자 관점의 기능 설명}
**우선순위 근거**: {왜 이 순서인지}
**독립 테스트**: {이 스토리만으로 테스트 가능한지}

#### 수용 시나리오
- [ ] Given {전제}, When {행동}, Then {결과}
- [ ] Given {전제}, When {행동}, Then {결과}

### US2: {스토리 제목} [P2]
{같은 형식}

## 요구사항

### 기능 요구사항
- **FR-001**: {요구사항}
- **FR-002**: {요구사항}

### 비기능 요구사항
- **NFR-001**: {성능/보안/접근성 등}

### 핵심 엔티티
| 엔티티 | 설명 | 관련 기존 코드 |
|--------|------|----------------|
| {이름} | {설명} | {경로 또는 "신규"} |

## 성공 기준
- **SC-001**: {측정 가능한 성공 지표}
- **SC-002**: {측정 가능한 성공 지표}

## Edge Cases
- {엣지 케이스 1}
- {엣지 케이스 2}

## 제약사항
- {기술적/비즈니스 제약}

## [NEEDS CLARIFICATION]
- {불확실한 항목 — 있으면 기록, 없으면 섹션 제거}
```

### 4. Critic Loop (1회)

작성 후 **자기비판 루프**를 1회 수행한다:

```
=== CRITIC PASS 1/1 ===
[COMPLETENESS] 모든 User Story에 수용 시나리오가 있는가? 누락된 요구사항은?
[MEASURABILITY] 성공 기준이 주관적이지 않고 측정 가능한가?
[INDEPENDENCE] 구현 세부사항(코드, 라이브러리명)이 섞이지 않았는가?
[EDGE_CASES]   최소 2개 이상 식별했는가? 빠진 경계 조건은?
```

- **FAIL 항목 발견 시**: spec.md 자동 수정 → 수정 사항 사용자에게 고지
  - 예: `⚠ COMPLETENESS: US3에 수용 시나리오 누락. 추가 중...`
- **ALL PASS**: `✓ Critic 통과` 한 줄 표시
- FAIL → 수정 → 재검증까지 완료한 후 다음 단계로 진행

### 5. 최종 출력

```
📝 Spec 생성 완료
├─ specs/{feature-name}/spec.md
├─ User Stories: {개수}개
├─ 요구사항: FR {개수}개, NFR {개수}개
├─ 미해결: {[NEEDS CLARIFICATION] 개수}개
└─ 다음 단계: /selfish:clarify (미해결 시) 또는 /selfish:plan
```

## 주의사항

- spec에는 **구현 방법을 쓰지 않는다**. "Zustand로 관리" 같은 표현은 plan.md의 몫.
- 기존 코드와 관련된 엔티티는 **실제 경로**를 명시.
- `$ARGUMENTS`가 비어있으면 사용자에게 기능 설명 요청.
- 한 spec에 너무 많은 기능을 담지 않는다. User Story 5개 초과 시 분리 제안.
