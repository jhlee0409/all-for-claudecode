# Context Management Harness

> afc 파이프라인의 정확성, 신뢰성, 토큰 효율을 위한 공식 기능 활용 가이드.
> 모든 내용은 [Claude Code 공식 문서](https://code.claude.com/docs/en/) 기반.

## 설계 철학

**1M 컨텍스트 ≠ "더 많이 담기". 1M = "auto-compact 전에 제어할 여유를 얻은 것".**

200k 시절에는 auto-compact가 갑자기 발생하여 제어 불가. 1M에서는 5배의 여유가 생겨 **내가 원하는 시점에, 원하는 내용을 보존하면서** compact할 수 있다.

```
┌────────────────────── 1M Context Window ──────────────────────┐
│ [고정] CLAUDE.md + rules + 스킬 메타데이터 (~5%)                │
│ [고정] auto-memory MEMORY.md 첫 200줄 (~1%)                    │
│ [누적] 대화 기록 + 도구 결과 (Phase 진행에 따라 증가)              │
│ ....                                                          │
│ ├── Phase 1 (Spec): ~50-100 prompts                           │
│ ├── Phase 2 (Plan): ~50-100 prompts                           │
│ ├── Phase 3 (Implement): ~100-300 prompts (서브에이전트 격리)    │
│ └── Phase 4 (Review): ~50-100 prompts (서브에이전트 격리)        │
│ ....                                                          │
│ [여유] ← 이 공간이 "선제적 제어 여유"                             │
│ [경계] auto-compact 95% (CLAUDE_AUTOCOMPACT_PCT_OVERRIDE로 조절) │
└───────────────────────────────────────────────────────────────┘
```

---

## 1. 선제적 Compact 제어 (Phase-Boundary Protocol)

### 1.1 원리

Auto-compact는 95% 도달 시 Claude가 임의로 요약 — 무엇을 보존할지 제어 불가.
**Phase 경계에서 선제적으로 compact하면**: 보존 대상을 지정하고, 다음 phase를 깨끗한 컨텍스트로 시작.

### 1.2 Phase-Boundary Compact Protocol

```
Phase 1 완료 → compact "spec.md ACs, edge cases, NFRs 보존"
Phase 2 완료 → compact "File Change Map, Implementation Context, ADR 보존"
Phase 3 완료 → compact "changed files list, CI results, 미해결 이슈 보존"
Phase 4 완료 → compact "review findings, fix status 보존"
```

### 1.3 구현 방법

`afc-user-prompt-submit.sh`의 Pipeline ACTIVE 분기에서, **phase 전환 직후** 첫 프롬프트에 compact 권고 주입:

```
[afc:context] Phase 전환 감지 ({prev} → {current}).
이전 phase 컨텍스트를 정리하세요: /compact {phase별 보존 지시}
```

**트리거**: `afc-pipeline-manage.sh phase {new}` 실행 시 state에 `phaseTransition: true` 플래그 기록 → 다음 UserPromptSubmit에서 감지 후 주입 + 플래그 해제.

### 1.4 Context Budget Monitor

`promptCount`로 컨텍스트 사용량 추정:

| promptCount 구간 | 추정 사용량 | 조치 |
|-----------------|-----------|------|
| 0-100 | ~30-50% | 정상 |
| 100-150 | ~50-70% | `[afc:context] 50%+ 추정. 불필요한 탐색 결과는 서브에이전트에 위임 권장.` |
| 150-200 | ~70-90% | `[afc:context] 70%+ 추정. /compact {현재 phase 보존 지시} 강력 권장.` |
| 200+ | ~90%+ | auto-compact 임박 (safety net) |

**구현**: UserPromptSubmit의 drift checkpoint 로직 확장. `totalPromptCount` 기준으로 budget 힌트 주입.

---

## 2. Compaction 품질 보장

### 2.1 Compact Instructions (CLAUDE.md)

`/afc:init`에서 프로젝트 CLAUDE.md에 자동 추가:

```markdown
# Compact instructions
When compacting, always preserve:
- Active pipeline feature name and current phase
- File Change Map from plan.md (file paths + task assignments)
- All unresolved ESCALATE items with their options
- context.md contents (spec summary + plan decisions + advisor results)
- Changed files list and CI/test pass/fail status
- Current task progress (completed/total)
```

### 2.2 PreCompact Hook 강화

현재 `pre-compact-checkpoint.sh`가 저장하는 것: git status, tasks 진행률.

**추가**: context.md 내용도 checkpoint에 포함 → compaction 후 `/afc:resume`으로 풍부한 복구.

```
# checkpoint.md에 추가될 섹션
## Feature Context (from context.md)
{context.md 전문 또는 요약}

## Advisor Insights
{Skill Advisor가 수집한 expert 권고}
```

---

## 3. Phase 간 컨텍스트 브릿지

### 3.1 context.md 누적 패턴

현재 갭: Skill Advisor가 expert를 호출하지만 결과가 context.md에 기록되지 않음.

```
Phase 1 → context.md 생성 (spec 요약, 핵심 AC)
Advisor A → context.md 갱신 (security 권고 추가)
Phase 2 → context.md 갱신 (plan 결정사항, ADR 요약)
Advisor B → context.md 갱신 (architect 권고 추가)
Advisor C → context.md 갱신 (consult 결과 추가)
Phase 3 → impl-worker에 context.md 주입 (skills preload 또는 프롬프트)
Phase 4 → reviewer에 context.md 주입
```

### 3.2 구현 방법

auto.md의 각 Skill Advisor Checkpoint에 지시 추가:

```markdown
After advisor skill completes, append a 3-line summary to context.md:
## Advisor: {skill_name} ({checkpoint})
- Key insight: {1-line}
- Action required: {1-line}
```

---

## 4. Subagent 컨텍스트 최적화

### 4.1 SendMessage Resume (의존 태스크)

```
현재: Task A → worker-1 생성 → 완료 → Task B(A 의존) → worker-2 생성 (A의 컨텍스트 없음)
개선: Task A → worker-1 생성 → 완료 → Task B(A 의존) → worker-1 resume (A의 전체 컨텍스트 유지)
```

**구현**: implement.md의 Sequential/Batch 모드에서 의존 관계 태스크를 동일 worker에 SendMessage로 전달.

### 4.2 Skills Preload

```yaml
# agents/afc-impl-worker.md
---
skills:
  - docs/orchestration-modes.md  # 실행 모드 참조
---
```

**주의**: skills preload는 서브에이전트 시작 시 전체 내용이 컨텍스트에 주입됨. 큰 스킬은 오히려 토큰 낭비 → **작고 핵심적인 참조만**.

### 4.3 Effort Level

```yaml
# agents/afc-backend-expert.md (상담은 deep thinking 불필요)
effort: medium

# agents/afc-architect.md (아키텍처 분석은 기본)
# effort 미설정 → inherit
```

---

## 5. 토큰 효율 전략

### 5.1 !`command` 프리페치

스킬에서 `!`command``로 데이터 프리페치 → 모델의 별도 Bash 턴 절약 (1-2턴/스킬).

**현재 적용**: 15개 스킬. **추가 대상**: 없음 (완료).

### 5.2 Hook 기반 전처리

테스트 출력, 로그 등 대량 데이터는 hook으로 필터링 후 전달.

### 5.3 스킬 vs CLAUDE.md vs rules

| 내용 | 위치 | 로드 시점 | 컨텍스트 비용 |
|------|------|----------|-------------|
| 항상 필요한 규칙 | CLAUDE.md (200줄 이하) | 매 세션 시작 | 항상 |
| 특정 워크플로우 | Skills | 호출 시만 | on-demand |
| 특정 파일 패턴 | .claude/rules/ (paths) | 해당 파일 작업 시 | conditional |
| 서브에이전트 전용 | skills preload | 에이전트 시작 시 | 에이전트별 |

### 5.4 MCP 도구 오버헤드

각 MCP 서버가 매 요청마다 도구 정의를 컨텍스트에 추가. 미사용 서버 비활성화. CLI 도구 선호.

---

## 6. 신뢰성 패턴

### 6.1 검증 루프

Claude는 **자체 검증 가능 시 극적으로 성능 향상**. 테스트, 예상 출력을 제공.

### 6.2 /clear 패턴

2번 이상 같은 문제 수정 → `/clear` → 배운 것 반영한 더 나은 프롬프트로 새 시작.

### 6.3 Checkpoint + Rewind

모든 편집 전 스냅샷. `Esc+Esc`로 복원. PreCompact hook이 자동 체크포인트.

---

## 7. Agent Teams (실험적, 보류)

비용 ~7x. 현재 subagent 패턴이 충분. cross-module 대규모 구현에서 향후 검토.

---

## 구현 계획

### P1: 선제적 Context 제어 (높은 효과)

| # | 작업 | 대상 파일 | 효과 |
|---|------|----------|------|
| 1.1 | Phase-Boundary Compact 권고 주입 | `afc-user-prompt-submit.sh` + `afc-pipeline-manage.sh` | phase 전환 시 보존 지시 포함 compact 권고 |
| 1.2 | Context Budget Monitor | `afc-user-prompt-submit.sh` | totalPromptCount 기반 사용량 추정 + 단계별 힌트 |
| 1.3 | Compact Instructions 자동 삽입 | `skills/init/SKILL.md` | CLAUDE.md에 compact 보존 지시 추가 |
| 1.4 | PreCompact checkpoint 강화 | `pre-compact-checkpoint.sh` | context.md 내용을 checkpoint에 포함 |

### P2: Phase 간 브릿지 (높은 효과)

| # | 작업 | 대상 파일 | 효과 |
|---|------|----------|------|
| 2.1 | Advisor 결과 context.md 누적 지시 | `skills/auto/SKILL.md` (Checkpoint A-E) | expert 권고가 다음 phase에 전달 |
| 2.2 | impl-worker에 SendMessage resume 패턴 | `skills/implement/SKILL.md` | 의존 태스크 간 컨텍스트 100% 보존 |

### P3: Subagent 효율 (중간 효과)

| # | 작업 | 대상 파일 | 효과 |
|---|------|----------|------|
| 3.1 | Expert 에이전트에 effort: medium | 8개 expert agent .md | thinking 토큰 30-50% 절약 |
| 3.2 | impl-worker에 skills preload 검토 | `agents/afc-impl-worker.md` | Read 턴 절약 (프로젝트별 동적이므로 제한적) |

---

## Sources

- [Best practices](https://code.claude.com/docs/en/best-practices)
- [How Claude Code works](https://code.claude.com/docs/en/how-claude-code-works)
- [Create custom subagents](https://code.claude.com/docs/en/sub-agents)
- [How Claude remembers your project](https://code.claude.com/docs/en/memory)
- [Common workflows](https://code.claude.com/docs/en/common-workflows)
- [Manage costs effectively](https://code.claude.com/docs/en/costs)
- [Orchestrate teams](https://code.claude.com/docs/en/agent-teams)
- [Subagents in the SDK](https://platform.claude.com/docs/en/agent-sdk/subagents)
- [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [Best practices for sub-agents](https://www.pubnub.com/blog/best-practices-for-claude-code-sub-agents/)
