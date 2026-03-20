# Agent Authoring Guide

> Based on [Claude Code subagents docs](https://code.claude.com/docs/en/sub-agents) and [community best practices](https://www.pubnub.com/blog/best-practices-for-claude-code-sub-agents/). All afc agents MUST follow these rules.

## 1. Single Responsibility

Each agent excels at **one** specific task. If an agent does two unrelated things, split it.

## 2. Description (Delegation Trigger)

Claude uses the description to decide when to delegate. Be specific:

```yaml
# Good — when을 명시
description: "Architecture analysis agent — invoked during plan/review phases for ADR recording and design compliance checks."

# Bad — 모호
description: "Architecture analysis agent."
```

- Include "use proactively" if the agent should be invoked automatically
- Include the pipeline phase context (when in the workflow this runs)

## 3. Tool Restrictions (Minimal Access)

**`tools` 생략 = 전체 접근 — 안티패턴.** 필요한 도구만 명시.

```yaml
# Read-only agent
tools: [Read, Grep, Glob]

# Code-changing agent
tools: [Read, Write, Edit, Bash, Glob, Grep]
```

**Write 사용 시** 사용 범위를 프롬프트에 명시:

```markdown
## Write Usage Policy
Write is restricted to memory files only:
- .claude/agent-memory/{agent-name}/MEMORY.md
Do NOT write project code, documentation, or configuration.
```

## 4. No Nested Agent Spawning

Subagent는 다른 subagent를 생성할 수 없다. **tools에 Agent 포함 금지.**

## 5. maxTurns (런어웨이 방지)

| 에이전트 유형 | 권장 maxTurns |
|-------------|--------------|
| Expert 상담 | 10 |
| 코드 스캔/리뷰 | 15-20 |
| 구현 워커 | 50 |
| PR 분석 | 15 |

## 6. Model Selection

| 모델 | 사용 시기 |
|------|---------|
| `haiku` | 빠른 조회, 분류 |
| `sonnet` | 대부분의 작업 (기본값) |
| `opus` | 복잡한 아키텍처 분석 |
| `inherit` | 오케스트레이터 (부모 모델 상속) |

## 7. Memory Configuration

| 스코프 | 위치 | 사용 시기 |
|--------|------|---------|
| `project` | `.claude/agent-memory/` | 팀 공유 지식 (기본 권장) |
| `user` | `~/.claude/agent-memory/` | 개인 전체 프로젝트 |
| `local` | `.claude/agent-memory-local/` | 비공개 |
| 미설정 | — | 임시 워커 (impl-worker, pr-analyst) |

## 8. System Prompt Structure

```markdown
You are a {role} for {context}.

## When to STOP and Ask
- {condition 1}
- {condition 2}

## Workflow
1. {step}
2. {step}

## Output Format
{template}

## Rules
- {constraint}

## Memory Usage
{read/write protocol}
```

**필수 섹션:**
- **역할 정의** (1문장)
- **HITL 규칙** — 언제 멈추고 물어볼지
- **워크플로우** — 단계별 절차
- **출력 포맷** — 구조화된 결과
- **완료 정의** — "끝"의 기준

## 9. Prompt Conciseness

Claude는 이미 OWASP, 디자인 패턴, 일반적인 red flags를 안다. **프로젝트 고유 지식만 제공.**

```markdown
# Bad (18줄) — Claude가 이미 아는 OWASP 테이블
| # | Category | Common Mistake |
| A01 | Broken Access Control | ... |
...

# Good (1줄)
Apply OWASP Top 10 2025 checklist, focusing on project-specific attack surface.
```

**Red Flags 목록**: 모델이 범용적으로 아는 것(N+1, XSS, SQL injection 등)은 삭제. 프로젝트/도메인 특화 항목만 유지.

## 10. Shared References

인라인 복제 금지. 공유 문서 참조만:

- `docs/expert-protocol.md` — Expert 에이전트 공통 프로토콜
- `docs/critic-loop-rules.md` — Critic Loop 규칙
- `docs/phase-gate-protocol.md` — Phase gate 프로토콜

## Checklist

에이전트 작성/수정 시 확인:

- [ ] 단일 책임 — 하나의 구체적 작업
- [ ] Description에 delegation trigger 명시
- [ ] tools 명시적 나열 (생략 금지)
- [ ] Agent 도구 미포함 (중첩 금지)
- [ ] maxTurns 설정
- [ ] HITL 규칙 포함 (언제 멈추고 물어볼지)
- [ ] 출력 포맷 정의
- [ ] 완료 기준 명시
- [ ] Claude가 이미 아는 것 설명하지 않음
- [ ] Write 사용 시 범위 문서화
- [ ] Memory 100줄 제한 명시 (해당 시)
