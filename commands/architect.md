---
name: selfish:architect
description: "아키텍처 분석 및 설계 조언 (읽기 전용)"
argument-hint: "[분석 대상 또는 설계 질문]"
disable-model-invocation: true
context: fork
agent: Plan
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Task
  - WebSearch
model: sonnet
---

# /selfish:architect — 아키텍처 분석 및 설계 조언

> 코드베이스의 아키텍처를 분석하고 설계 결정을 기록한다.
> Critic Loop 3회로 설계 품질을 보장한다. **읽기 전용** — 코드를 수정하지 않는다.

## 인자

- `$ARGUMENTS` — (필수) 분석 대상 또는 설계 질문 (예: "상태 관리 전략 리뷰", "새 entity 추가 위치")

## 설정 로드

프로젝트 루트의 `CLAUDE.md` 또는 `.claude/CLAUDE.md`에서 다음 설정을 읽어 `config` 변수에 할당:

```
config.architecture = 프로젝트에서 사용하는 아키텍처 패턴
                      (예: "FSD", "Clean Architecture", "Layered", "Modular Monolith")
                      → CLAUDE.md에 명시된 아키텍처 기준. 없으면 "레이어드 아키텍처"로 가정.
```

## 실행 절차

### 1. 범위 결정

`$ARGUMENTS`를 분석하여 작업 유형 판별:

| 유형 | 예시 | 출력 |
|------|------|------|
| **구조 분석** | "타임라인 모듈 구조" | 의존성 맵 + 개선 제안 |
| **설계 질문** | "새 feature 어디에?" | 배치 제안 + 근거 |
| **ADR 기록** | "Redis vs In-memory 결정" | Architecture Decision Record |
| **리팩토링 평가** | "store 분리 필요성" | 현재 문제 + 리팩토링 계획 |

### 2. 코드베이스 탐색

1. 관련 디렉토리/파일 탐색 (Glob, Grep, Read)
2. 의존성 흐름 추적 (import 관계)
3. {config.architecture} 구조 확인
4. 기존 패턴 식별

Agent Teams 활용: 분석 범위가 넓으면 (3개+ 모듈) 병렬 탐색:
```
Task("features/timeline 분석", subagent_type: Explore)
Task("widgets/timeline 분석", subagent_type: Explore)
```

### 3. 분석 작성

분석 결과를 구조화하여 **콘솔에 출력**:

```markdown
## 아키텍처 분석: {주제}

### 현재 구조
{의존성 맵, 모듈 관계, 데이터 흐름}

### 발견사항
| # | 영역 | 현재 | 제안 | 영향도 |
|---|------|------|------|--------|
| 1 | {영역} | {현재 방식} | {제안} | H/M/L |

### 설계 결정 (ADR)
**결정**: {선택한 방식}
**상태**: Proposed / Accepted / Deprecated
**컨텍스트**: {배경}
**선택지**:
1. {옵션1} — 장점: / 단점:
2. {옵션2} — 장점: / 단점:
**근거**: {왜 이 선택인지}
**결과**: {예상되는 영향}

### 아키텍처 정합성
{config.architecture} 규칙 위반 여부, import 방향 검증}
```

### 4. Critic Loop (3회)

| 기준 | 검증 내용 |
|------|-----------|
| **FEASIBILITY** | 제안이 현재 코드베이스에서 실현 가능한가? |
| **INCREMENTALITY** | 점진적 적용이 가능한가? (빅뱅 리팩토링 지양) |
| **COMPATIBILITY** | 기존 코드와 호환되는가? Breaking change가 있는가? |
| **ARCHITECTURE** | {config.architecture} 규칙을 준수하는가? |

출력 규칙:
- FAIL 시: `⚠ {기준}: {문제}. 수정 중...`
- PASS 시: `✓ Critic {N}/3 통과`
- 최종: `Critic Loop 완료 ({N}회). 주요 수정: {요약}`

### 5. ADR 저장 (설계 결정인 경우)

ADR 유형이면 `memory/decisions/{YYYY-MM-DD}-{topic}.md`에 저장:

```markdown
# ADR: {제목}
- **날짜**: {YYYY-MM-DD}
- **상태**: Proposed
- **컨텍스트**: {배경}
- **결정**: {선택}
- **근거**: {이유}
- **결과**: {영향}
```

### 6. 최종 출력

```
🏗 아키텍처 분석 완료
├─ 유형: {구조 분석 | 설계 질문 | ADR | 리팩토링 평가}
├─ 발견사항: {개수}개
├─ Critic: {N}회 완료
├─ ADR: {저장됨 | 해당없음}
└─ 제안: {핵심 제안 한 줄}
```

## 주의사항

- **읽기 전용**: 코드를 수정하지 않음. 분석과 제안만 수행.
- **실제 코드 기반**: 추측이 아닌 실제 코드베이스를 탐색하여 분석.
- **아키텍처 우선**: 모든 제안은 {config.architecture} 규칙을 존중.
- **점진적 변경**: 빅뱅 리팩토링보다 점진적 개선을 선호.
